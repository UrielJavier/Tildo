import Foundation

struct AppTone: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var stylePrompt: String
}
