import Foundation

actor LLMClient {
    struct LLMError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    func process(text: String, systemPrompt: String, provider: LLMProvider, apiKey: String, model: String) async throws -> String {
        if provider == .claudeCode {
            return try await processWithClaudeCode(text: text, systemPrompt: systemPrompt, model: model)
        }

        let request = try buildRequest(text: text, systemPrompt: systemPrompt, provider: provider, apiKey: apiKey, model: model)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw LLMError(message: "Invalid response from \(provider.rawValue)")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError(message: "\(provider.rawValue) API error (\(http.statusCode)): \(body)")
        }

        return try extractContent(from: data, provider: provider)
    }

    // MARK: - Claude Code CLI

    private func processWithClaudeCode(text: String, systemPrompt: String, model: String) async throws -> String {
        let claudePath = Self.findClaudeCLI()
        guard let claudePath else {
            throw LLMError(message: "Claude Code CLI not found. Install it with: npm install -g @anthropic-ai/claude-code")
        }

        let fullPrompt = "\(systemPrompt)\n\nText to process:\n\(text)"

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()

            process.executableURL = URL(fileURLWithPath: claudePath)
            process.arguments = ["-p", fullPrompt, "--model", model]
            process.standardOutput = stdout
            process.standardError = stderr

            // claude is a Node.js script — ensure node is in PATH by prepending
            // the directory that contains the claude binary (node lives there too).
            let claudeDir = URL(fileURLWithPath: claudePath).deletingLastPathComponent().path
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = claudeDir + ":/usr/local/bin:/opt/homebrew/bin:" + (env["PATH"] ?? "")
            process.environment = env

            process.terminationHandler = { _ in
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let errorOutput = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if process.terminationStatus != 0 {
                    let msg = errorOutput.isEmpty ? "Claude Code exited with status \(process.terminationStatus)" : errorOutput
                    continuation.resume(throwing: LLMError(message: "Claude Code error: \(msg)"))
                } else if output.isEmpty {
                    continuation.resume(throwing: LLMError(message: "Claude Code returned empty response"))
                } else {
                    continuation.resume(returning: output)
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: LLMError(message: "Failed to launch Claude Code: \(error.localizedDescription)"))
            }
        }
    }

    private static func findClaudeCLI() -> String? {
        let candidates = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
        ]

        // Check common paths first
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }

        // Check PATH via `which`
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        // Include nvm/homebrew paths
        var env = ProcessInfo.processInfo.environment
        let extra = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            NSHomeDirectory() + "/.nvm/versions/node/v22.17.1/bin",
        ]
        env["PATH"] = (env["PATH"] ?? "") + ":" + extra.joined(separator: ":")
        process.environment = env

        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty ? nil : path
    }

    // MARK: - Request building

    private func buildRequest(text: String, systemPrompt: String, provider: LLMProvider, apiKey: String, model: String) throws -> URLRequest {
        guard let url = URL(string: provider.baseURL) else {
            throw LLMError(message: "Invalid URL for \(provider.rawValue)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch provider {
        case .claudeCode:
            fatalError("Claude Code does not use HTTP requests")
        case .openAI, .groq:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try openAIBody(text: text, systemPrompt: systemPrompt, model: model)
        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.httpBody = try anthropicBody(text: text, systemPrompt: systemPrompt, model: model)
        }

        return request
    }

    private func openAIBody(text: String, systemPrompt: String, model: String) throws -> Data {
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text],
            ],
            "temperature": 0.3,
            "max_tokens": 4096,
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    private func anthropicBody(text: String, systemPrompt: String, model: String) throws -> Data {
        let body: [String: Any] = [
            "model": model,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": text],
            ],
            "temperature": 0.3,
            "max_tokens": 4096,
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    // MARK: - Response parsing

    private func extractContent(from data: Data, provider: LLMProvider) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError(message: "Failed to parse \(provider.rawValue) response")
        }

        switch provider {
        case .claudeCode:
            fatalError("Claude Code does not use HTTP response parsing")
        case .openAI, .groq:
            guard let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw LLMError(message: "Unexpected response format from \(provider.rawValue)")
            }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)

        case .anthropic:
            guard let contentArray = json["content"] as? [[String: Any]],
                  let first = contentArray.first,
                  let text = first["text"] as? String else {
                throw LLMError(message: "Unexpected response format from Anthropic")
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
