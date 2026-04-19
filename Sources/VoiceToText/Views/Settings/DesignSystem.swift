// DesignSystem.swift — Tildo rebrand (2026)
//
// Paste this over Views/Settings/DesignSystem.swift.
// New tokens live first; aliases below keep existing code compiling
// until every view is migrated.
//
// Palette identity: warm paper background, warm-black ink, single
// moss-green accent, warm red used only during recording.

import SwiftUI
import AppKit

enum DS {

    // ── Colors ─────────────────────────────────────────────────
    enum Colors {

        // Surfaces
        static let paper     = Color(hex: "FAF7F2")  // app canvas
        static let panel     = Color(hex: "F3EFE7")  // sidebars, tinted rows
        static let card      = Color(hex: "FFFFFF")  // raised surfaces
        static let line      = Color(hex: "E6E1D6")  // hairlines
        static let lineSoft  = Color(hex: "EFEAE0")

        // Ink (text)
        static let ink       = Color(hex: "1C1B17")  // primary
        static let ink2      = Color(hex: "4A4740")  // secondary
        static let ink3      = Color(hex: "8A857A")  // tertiary / labels
        static let ink4      = Color(hex: "B8B2A4")  // disabled / hint

        // Accent — moss green (the ONLY accent. No blues, no purples.)
        static let moss      = Color(hex: "4F6F3A")
        static let mossSoft  = Color(hex: "EEF2E6")  // 6% tint, for bg chips
        static let mossInk   = Color(hex: "3A5327")  // darker moss, for text on mossSoft

        // Status
        static let rec       = Color(hex: "C8462B")  // warm red — ONLY while recording

        // Dark-theme counterparts (used only by FloatingRecordingView when theme == .dark)
        static let paperDark = Color(hex: "1A1915")
        static let panelDark = Color(hex: "23211C")
        static let lineDark  = Color(hex: "2F2C25")
        static let inkDark   = Color(hex: "F4F0E7")

        // ─── ALIASES for compatibility ────────────────────────
        // Aliases from the handoff spec
        static let parchment    = paper
        static let charcoalWarm = ink2
        static let accent       = moss
        static let accentSoft   = mossSoft
        static let accentInk    = mossInk
        static let separator    = line
        static let subtle       = ink3
        static let muted        = ink4

        // Additional legacy aliases — keep until every view is migrated
        static let bg           = paper      // was warm near-white
        static let bg2          = panel      // was secondary surface
        static let line2        = line       // was stronger border → map to line
        static let nearBlack    = ink
        static let terracotta   = moss       // was blue accent, now single moss accent
        static let accentHover  = mossInk   // was hover variant
        static let ivory        = card
        static let warmSand     = panel
        static let oliveGray    = ink2
        static let stoneGray    = ink3
        static let warmSilver   = ink4
        static let borderCream  = line
        static let borderWarm   = line
        static let ringWarm     = line
        static let darkSurface  = panelDark
        static let red          = rec        // recording red
        static let redSoft      = rec.opacity(0.12)
        static let green        = moss       // success/in-use → now moss
        static let greenSoft    = mossSoft
        static let amber        = ink2       // warm accent → nearest available
        static let amberSoft    = panel
    }

    // ── Typography ─────────────────────────────────────────────
    // All system fonts — no custom bundle fonts.
    // SF Pro for UI, SF Mono for numeric / keycap / technical labels.
    enum Fonts {
        // Display — used sparingly, for modal titles and onboarding headings
        static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .default)
        }
        // Body UI font
        static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }
        // Monospaced — for keycaps, sizes (MB/GB), shortcuts, hashes, file paths
        static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }

        // Semantic shortcuts
        static let windowTitle    = display(22)
        static let sheetTitle     = sans(15, weight: .semibold)
        static let sectionLabel   = mono(10.5, weight: .medium)
        static let body           = sans(13)
        static let bodyStrong     = sans(13, weight: .semibold)
        static let caption        = sans(12, weight: .regular)
        static let hint           = sans(11.5, weight: .regular)
        static let chip           = mono(10.5, weight: .medium)

        // Legacy alias — keep until all call sites use display() or sans()
        static func serif(_ size: CGFloat) -> Font { display(size) }
    }

    // ── Spacing ────────────────────────────────────────────────
    enum Spacing {
        static let hairline: CGFloat   = 1
        static let xxs: CGFloat        = 2
        static let xs: CGFloat         = 4
        static let sm: CGFloat         = 8
        static let md: CGFloat         = 12
        static let lg: CGFloat         = 16
        static let xl: CGFloat         = 20
        static let xxl: CGFloat        = 28

        static let cardPadding        = EdgeInsets(top: 14, leading: 14, bottom: 12, trailing: 14)
        static let rowPadding         = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        static let pagePadding        = EdgeInsets(top: 20, leading: 28, bottom: 28, trailing: 28)
    }

    // ── Radii ──────────────────────────────────────────────────
    enum Radius {
        static let sm: CGFloat = 6    // inputs, buttons
        static let md: CGFloat = 8    // inline rows
        static let lg: CGFloat = 10   // cards, sheets
        static let xl: CGFloat = 14   // pill widget
        static let pill: CGFloat = 999
    }

    // ── Shadows ────────────────────────────────────────────────
    struct ShadowSpec {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    enum Shadow {
        static let card  = ShadowSpec(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 4)
        static let sheet = ShadowSpec(color: Color.black.opacity(0.18), radius: 40, x: 0, y: 12)
        static let pill  = ShadowSpec(color: Color.black.opacity(0.22), radius: 40, x: 0, y: 12)
    }

    // ── Motion ─────────────────────────────────────────────────
    enum Motion {
        static let snappy: Animation = .spring(response: 0.32, dampingFraction: 0.82)
        static let gentle: Animation = .spring(response: 0.4,  dampingFraction: 0.85)
        static let tick:   Animation = .easeOut(duration: 0.15)
    }
}

// MARK: - Hex Color helper

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var n: UInt64 = 0
        Scanner(string: s).scanHexInt64(&n)
        let r = Double((n >> 16) & 0xFF) / 255
        let g = Double((n >>  8) & 0xFF) / 255
        let b = Double((n      ) & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}

// MARK: - View modifiers

extension View {
    func dsCard(padding: EdgeInsets = DS.Spacing.cardPadding) -> some View {
        self
            .padding(padding)
            .background(DS.Colors.card)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(DS.Colors.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    func dsShadow(_ spec: DS.ShadowSpec) -> some View {
        self.shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
    }
}
