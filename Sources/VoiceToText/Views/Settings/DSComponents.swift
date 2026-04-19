import SwiftUI

// MARK: - Toggle (full row)

struct DSToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon in accent-soft square
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(DS.Colors.accentSoft)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.Colors.accent)
            }
            Text(title)
                .font(DS.Fonts.sans(13, weight: .medium))
                .foregroundStyle(DS.Colors.ink)
            Spacer()
            DSToggleTrack(isOn: $isOn)
        }
    }
}

// Bare toggle track + knob, 36×20
struct DSToggleTrack: View {
    @Binding var isOn: Bool

    var body: some View {
        ZStack {
            Capsule()
                .fill(isOn ? DS.Colors.accent : DS.Colors.line2)
                .frame(width: 36, height: 20)
            Circle()
                .fill(.white)
                .frame(width: 16, height: 16)
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                .offset(x: isOn ? 8 : -8)
        }
        .animation(.easeInOut(duration: 0.14), value: isOn)
        .onTapGesture { isOn.toggle() }
    }
}

// MARK: - Button Styles

// Primary: near-black bg, white text
struct DSPrimaryStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Inner(configuration: configuration, isEnabled: isEnabled)
    }

    private struct Inner: View {
        let configuration: ButtonStyleConfiguration
        let isEnabled: Bool
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(DS.Fonts.sans(12.5, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(
                            !isEnabled ? DS.Colors.ink4
                            : configuration.isPressed || isHovered ? DS.Colors.ink2
                            : DS.Colors.ink
                        )
                )
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
                .onHover { if isEnabled { isHovered = $0 } }
        }
    }
}

// Secondary: white bg, line border
struct DSSecondaryStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Inner(configuration: configuration, isEnabled: isEnabled)
    }

    private struct Inner: View {
        let configuration: ButtonStyleConfiguration
        let isEnabled: Bool
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(DS.Fonts.sans(12.5))
                .foregroundStyle(isEnabled ? DS.Colors.ink : DS.Colors.ink4)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(isHovered || configuration.isPressed ? DS.Colors.panel : DS.Colors.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .strokeBorder(DS.Colors.line, lineWidth: 1)
                )
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
                .onHover { if isEnabled { isHovered = $0 } }
        }
    }
}

// Destructive: transparent, rec-red text
struct DSDestructiveStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Inner(configuration: configuration)
    }

    private struct Inner: View {
        let configuration: ButtonStyleConfiguration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(DS.Fonts.sans(12.5))
                .foregroundStyle(isHovered || configuration.isPressed ? DS.Colors.rec : DS.Colors.rec.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(isHovered || configuration.isPressed ? DS.Colors.rec.opacity(0.1) : Color.clear)
                )
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
                .onHover { isHovered = $0 }
        }
    }
}

// Ghost: transparent, bg2 on hover
struct DSGhostStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Inner(configuration: configuration)
    }

    private struct Inner: View {
        let configuration: ButtonStyleConfiguration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(isHovered ? DS.Colors.ink2 : DS.Colors.ink3)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(isHovered || configuration.isPressed ? DS.Colors.bg2 : Color.clear)
                )
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
                .onHover { isHovered = $0 }
        }
    }
}

extension ButtonStyle where Self == DSPrimaryStyle {
    static var dsPrimary: DSPrimaryStyle { .init() }
}
extension ButtonStyle where Self == DSSecondaryStyle {
    static var dsSecondary: DSSecondaryStyle { .init() }
}
extension ButtonStyle where Self == DSDestructiveStyle {
    static var dsDestructive: DSDestructiveStyle { .init() }
}
extension ButtonStyle where Self == DSGhostStyle {
    static var dsGhost: DSGhostStyle { .init() }
}

// MARK: - Segmented Control

struct DSSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    let label: (Option) -> String
    @Binding var selection: Option

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.14)) { selection = option }
                } label: {
                    Text(label(option))
                        .font(DS.Fonts.sans(12.5, weight: option == selection ? .medium : .regular))
                        .foregroundStyle(option == selection ? DS.Colors.ink : DS.Colors.ink3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Group {
                                if option == selection {
                                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                                        .fill(DS.Colors.card)
                                        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(DS.Colors.panel, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(DS.Colors.line, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.14), value: selection)
    }
}

// MARK: - Chip

struct DSChip: View {
    let text: String
    var color: Color = DS.Colors.ink3

    init(_ text: String, color: Color = DS.Colors.ink3) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .tracking(0.3)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.12)))
            .overlay(Capsule().strokeBorder(color.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Divider

struct DSDivider: View {
    var body: some View {
        Rectangle()
            .fill(DS.Colors.line)
            .frame(height: 1)
    }
}

// MARK: - Row action buttons

struct DSEditButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "pencil")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(isHovered ? DS.Colors.ink : DS.Colors.ink3)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(isHovered ? DS.Colors.bg2 : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct DSDeleteButton: View {
    let action: () -> Void
    var disabled: Bool = false
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(
                    disabled ? DS.Colors.ink4
                    : isHovered ? DS.Colors.red : DS.Colors.red.opacity(0.5)
                )
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(isHovered && !disabled ? DS.Colors.redSoft : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { if !disabled { isHovered = $0 } }
    }
}

// MARK: - Menu label

extension View {
    func dsMenuLabel() -> some View {
        self
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DS.Colors.card, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .strokeBorder(DS.Colors.line2, lineWidth: 1)
            )
    }
}
