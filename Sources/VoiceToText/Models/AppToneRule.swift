import Foundation

struct AppToneRule: Identifiable, Codable {
    var id: UUID = UUID()
    var appName: String     // matches RecordingTarget.appName, e.g. "Slack", "Google Chrome"
    var urlPattern: String  // empty = any URL; e.g. "github.com", "mail.google.com"
    var stylePrompt: String
    var isEnabled: Bool = true
}
