import Foundation

struct AppRule: Identifiable, Codable {
    var id: UUID = UUID()
    var appName: String
    var urlPattern: String
    var toneId: UUID
    var isEnabled: Bool = true
}
