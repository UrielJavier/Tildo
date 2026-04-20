import Foundation
import SwiftUI

// MARK: - Built-in category names
enum ReplacementCategory: String, Codable, CaseIterable, Identifiable {
    case brands = "Brands"
    case tech = "Tech"
    case typos = "Typos"
    case names = "Names"
    case emoji = "Emoji"
    case general = "General"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .brands:  return DS.Colors.accent
        case .tech:    return Color(hex: "7c3aed")
        case .typos:   return DS.Colors.red
        case .names:   return DS.Colors.amber
        case .emoji:   return DS.Colors.green
        case .general: return DS.Colors.ink3
        }
    }

    var softColor: Color {
        switch self {
        case .brands:  return DS.Colors.accentSoft
        case .tech:    return Color(hex: "ede9fe")
        case .typos:   return DS.Colors.redSoft
        case .names:   return DS.Colors.amberSoft
        case .emoji:   return DS.Colors.greenSoft
        case .general: return DS.Colors.bg2
        }
    }
}

// MARK: - Category helper (built-in + custom)

struct CategoryInfo: Identifiable {
    let name: String
    let color: Color
    let softColor: Color
    var id: String { name }

    static let customPalette: [(Color, Color)] = [
        (Color(hex: "0ea5e9"), Color(hex: "e0f2fe")),
        (Color(hex: "10b981"), Color(hex: "d1fae5")),
        (Color(hex: "f59e0b"), Color(hex: "fef3c7")),
        (Color(hex: "ef4444"), Color(hex: "fee2e2")),
        (Color(hex: "8b5cf6"), Color(hex: "ede9fe")),
        (Color(hex: "ec4899"), Color(hex: "fce7f3")),
    ]

    static func from(_ name: String, customIndex: Int = 0) -> CategoryInfo {
        if let builtin = ReplacementCategory(rawValue: name) {
            return CategoryInfo(name: name, color: builtin.color, softColor: builtin.softColor)
        }
        let pair = customPalette[customIndex % customPalette.count]
        return CategoryInfo(name: name, color: pair.0, softColor: pair.1)
    }
}

// MARK: - Replacement rule

struct ReplacementRule: Identifiable, Codable, Equatable {
    var id = UUID()
    var find: String
    var replace: String
    var enabled: Bool = true
    var categoryName: String = "General"
    var caseSensitive: Bool = false
    var wholeWord: Bool = false

    // Backward compat: decode old `category` enum field
    enum CodingKeys: String, CodingKey {
        case id, find, replace, enabled, categoryName, category, caseSensitive, wholeWord
    }

    init(id: UUID = UUID(), find: String, replace: String, enabled: Bool = true,
         categoryName: String = "General", caseSensitive: Bool = false, wholeWord: Bool = false) {
        self.id = id
        self.find = find
        self.replace = replace
        self.enabled = enabled
        self.categoryName = categoryName
        self.caseSensitive = caseSensitive
        self.wholeWord = wholeWord
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        find = try c.decode(String.self, forKey: .find)
        replace = try c.decode(String.self, forKey: .replace)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        caseSensitive = try c.decodeIfPresent(Bool.self, forKey: .caseSensitive) ?? false
        wholeWord = try c.decodeIfPresent(Bool.self, forKey: .wholeWord) ?? false
        // Try new field first, fall back to old enum field
        if let name = try c.decodeIfPresent(String.self, forKey: .categoryName) {
            categoryName = name
        } else if let oldCat = try c.decodeIfPresent(ReplacementCategory.self, forKey: .category) {
            categoryName = oldCat.rawValue
        } else {
            categoryName = "General"
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(find, forKey: .find)
        try c.encode(replace, forKey: .replace)
        try c.encode(enabled, forKey: .enabled)
        try c.encode(categoryName, forKey: .categoryName)
        try c.encode(caseSensitive, forKey: .caseSensitive)
        try c.encode(wholeWord, forKey: .wholeWord)
    }
}

extension ReplacementRule {
    // Legacy init for compatibility with old code using ReplacementCategory
    init(find: String, replace: String, category: ReplacementCategory, enabled: Bool = true) {
        self.init(find: find, replace: replace, enabled: enabled, categoryName: category.rawValue)
    }

    static let defaultRules: [ReplacementRule] = [
        .init(find: "arroba", replace: "@", category: .general),
        .init(find: "hashtag", replace: "#", category: .general),
        .init(find: "guion bajo", replace: "_", category: .general),
    ]
}
