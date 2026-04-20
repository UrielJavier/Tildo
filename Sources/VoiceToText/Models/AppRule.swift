import Foundation

struct AppRule: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var appName: String
    var urlPattern: String
    var toneId: UUID
    var isEnabled: Bool = true
}
