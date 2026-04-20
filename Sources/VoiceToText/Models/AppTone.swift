import Foundation

struct AppTone: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var description: String = ""
    var category: String = ""
    var stylePrompt: String
    var preview: String = ""
}
