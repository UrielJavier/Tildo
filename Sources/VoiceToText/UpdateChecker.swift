import Foundation

private let apiURL = URL(string: "https://api.github.com/repos/UrielJavier/Tildo/releases/latest")!

@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()
    private init() {}

    func check(appState: AppState) {
        Task.detached(priority: .background) {
            guard let (version, url) = await Self.fetchLatest() else { return }
            let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            guard Self.isNewer(version, than: current) else { return }
            await MainActor.run {
                appState.availableUpdate = version
                appState.availableUpdateURL = url
            }
        }
    }

    private nonisolated static func fetchLatest() async -> (String, String)? {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1"
        var request = URLRequest(url: apiURL, timeoutInterval: 8)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Tildo/\(appVersion)", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let html = json["html_url"] as? String
        else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return (version, html)
    }

    private nonisolated static func isNewer(_ remote: String, than current: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        let len = max(r.count, c.count)
        for i in 0..<len {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv != cv { return rv > cv }
        }
        return false
    }
}
