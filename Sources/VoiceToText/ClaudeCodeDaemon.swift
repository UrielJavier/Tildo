import Foundation

/// Keeps a single `claude --print --input-format stream-json` process alive across requests,
/// eliminating the Node.js startup cost (~1-2 s) that occurs when spawning per-call.
actor ClaudeCodeDaemon {

    // MARK: - State

    private var process: Process?
    private var stdinHandle: FileHandle?
    private var pendingContinuation: CheckedContinuation<String, Error>?
    private var outputBuffer = ""
    private var accumulatedInputTokens = 0

    private let claudePath: String
    var model: String

    // Restart the process when accumulated context exceeds this threshold.
    // Each post-processing request adds ~100-300 input tokens; 40k gives ~100-200 requests.
    private let tokenRestartThreshold = 40_000

    // MARK: - Init

    init(claudePath: String, model: String) {
        self.claudePath = claudePath
        self.model = model
    }

    // MARK: - Public API

    func send(text: String, systemPrompt: String) async throws -> String {
        try ensureRunning()

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: DaemonError("Daemon deallocated"))
                return
            }
            Task { await self.enqueue(text: text, systemPrompt: systemPrompt, continuation: continuation) }
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        stdinHandle = nil
        pendingContinuation?.resume(throwing: DaemonError("Daemon stopped"))
        pendingContinuation = nil
    }

    // MARK: - Internal

    private func enqueue(text: String, systemPrompt: String, continuation: CheckedContinuation<String, Error>) {
        guard process?.isRunning == true else {
            continuation.resume(throwing: DaemonError("Claude Code process not running"))
            return
        }

        pendingContinuation = continuation

        let payload: [String: Any] = [
            "type": "user",
            "message": ["role": "user", "content": "\(systemPrompt)\n\nText to process:\n\(text)"]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              var line = String(data: data, encoding: .utf8) else {
            continuation.resume(throwing: DaemonError("Failed to encode request"))
            pendingContinuation = nil
            return
        }
        line += "\n"
        stdinHandle?.write(Data(line.utf8))
    }

    private func ensureRunning() throws {
        guard process == nil || process?.isRunning == false else { return }

        let p = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()

        p.executableURL = URL(fileURLWithPath: claudePath)
        p.arguments = [
            "--print",
            "--input-format", "stream-json",
            "--output-format", "stream-json",
            "--verbose",
            "--model", model,
            "--no-session-persistence",
            "--effort", "low",
        ]
        p.standardInput  = stdinPipe
        p.standardOutput = stdoutPipe
        p.standardError  = FileHandle.nullDevice

        var env = ProcessInfo.processInfo.environment
        let claudeDir = URL(fileURLWithPath: claudePath).deletingLastPathComponent().path
        env["PATH"] = claudeDir + ":/usr/local/bin:/opt/homebrew/bin:" + (env["PATH"] ?? "")
        p.environment = env

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { await self?.receive(text) }
        }

        p.terminationHandler = { [weak self] _ in
            Task { await self?.handleTermination() }
        }

        try p.run()
        self.process = p
        self.stdinHandle = stdinPipe.fileHandleForWriting
    }

    private func receive(_ chunk: String) {
        outputBuffer += chunk
        var lines = outputBuffer.components(separatedBy: "\n")
        outputBuffer = lines.removeLast()

        for line in lines where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["type"] as? String == "result" else { continue }

            // Track accumulated input tokens to decide when to restart
            if let usage = json["usage"] as? [String: Any] {
                let input   = usage["input_tokens"]                as? Int ?? 0
                let created = usage["cache_creation_input_tokens"] as? Int ?? 0
                let read    = usage["cache_read_input_tokens"]     as? Int ?? 0
                accumulatedInputTokens += input + created + read
            }

            let isError = json["is_error"] as? Bool ?? false
            let result  = json["result"]   as? String ?? ""

            if isError {
                pendingContinuation?.resume(throwing: DaemonError(result.isEmpty ? "Claude Code returned an error" : result))
            } else {
                pendingContinuation?.resume(returning: result)
            }
            pendingContinuation = nil

            // Restart process if context is getting large to avoid compaction
            if accumulatedInputTokens >= tokenRestartThreshold {
                restartProcess()
            }
        }
    }

    private func restartProcess() {
        process?.terminate()
        process = nil
        stdinHandle = nil
        outputBuffer = ""
        accumulatedInputTokens = 0
        try? ensureRunning()
    }

    private func handleTermination() {
        process = nil
        stdinHandle = nil
        outputBuffer = ""
        pendingContinuation?.resume(throwing: DaemonError("Claude Code process exited unexpectedly"))
        pendingContinuation = nil
    }

    struct DaemonError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
