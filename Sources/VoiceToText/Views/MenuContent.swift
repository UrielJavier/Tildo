import SwiftUI
import AppKit

struct MenuContent: View {
    let appDelegate: AppDelegate

    var body: some View {
        @Bindable var state = appDelegate.appState

        VStack(spacing: 0) {
            PopoverHeader(state: state)
                .frame(height: 44)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

            Rectangle().fill(DS.Colors.line).frame(height: 1)

            ToneRow(
                state: state,
                onRules: { appDelegate.openSettings(section: .atajos) },
                onLLM: { appDelegate.openSettings(section: .llm) }
            )
            .frame(height: 56)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Rectangle().fill(DS.Colors.lineSoft).frame(height: 1)

            StatsStrip(state: state, onModelos: { appDelegate.openSettings(section: .modelos) })
                .frame(height: 54)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(DS.Colors.panel)

            Rectangle().fill(DS.Colors.line).frame(height: 1)

            PopoverFooter(
                onSettings: { appDelegate.openMainWindow() },
                onHistory: { appDelegate.openHistory() },
                onQuit: { NSApplication.shared.terminate(nil) }
            )
            .frame(height: 34)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 360)
        .background(DS.Colors.paper)
    }
}

// MARK: - Header (44 pt)

private struct PopoverHeader: View {
    let state: AppState

    var body: some View {
        HStack(spacing: 0) {
            // Mark + wordmark
            HStack(spacing: 6) {
                Text("∼")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.Colors.moss)
                    .kerning(-0.2)
                Text("Tildo")
                    .font(DS.Fonts.sans(13, weight: .semibold))
                    .foregroundStyle(DS.Colors.ink)
                    .kerning(-0.2)
            }

            Spacer()

            // Status text
            statusChip
        }
    }

    @ViewBuilder
    private var statusChip: some View {
        switch state.status {
        case .recording:
            HStack(spacing: 5) {
                RecDot()
                Text("escuchando")
                    .font(DS.Fonts.mono(11))
                    .foregroundStyle(DS.Colors.ink2)
            }
        case .transcribing:
            HStack(spacing: 5) {
                Text("∼")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Colors.moss)
                    .modifier(TildeWave())
                Text("transcribiendo…")
                    .font(DS.Fonts.mono(11))
                    .foregroundStyle(DS.Colors.ink2)
            }
        default:
            Text("listo para dictar")
                .font(DS.Fonts.mono(11))
                .foregroundStyle(DS.Colors.ink3)
        }
    }
}

// MARK: - Tone row (56 pt)

private struct ToneRow: View {
    @Bindable var state: AppState
    let onRules: () -> Void
    let onLLM: () -> Void

    private var llmActive: Bool { state.llmPostProcessEnabled }
    private var defaultToneName: String {
        if let id = state.defaultToneId, let tone = state.tones.first(where: { $0.id == id }) {
            return tone.name
        }
        return "Normal"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TONO POR DEFECTO")
                    .font(DS.Fonts.mono(10, weight: .medium))
                    .foregroundStyle(DS.Colors.ink4)
                    .tracking(0.4)

                Button(action: llmActive ? onRules : onLLM) {
                    Text(llmActive ? "ver reglas por app →" : "Activa un modelo para usar tonos →")
                        .font(DS.Fonts.sans(12))
                        .foregroundStyle(DS.Colors.mossInk)
                        .underline()
                }
                .buttonStyle(.plain)
            }

            Spacer()

            toneChip
        }
    }

    @ViewBuilder
    private var toneChip: some View {
        if llmActive {
            Menu {
                Button("Normal") { state.defaultToneId = nil }
                if !state.tones.isEmpty { Divider() }
                ForEach(state.tones) { tone in
                    Button(tone.name) { state.defaultToneId = tone.id }
                }
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(DS.Colors.moss)
                        .frame(width: 6, height: 6)
                    Text(defaultToneName)
                        .font(DS.Fonts.sans(12, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(Color(hex: "1C1B17"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DS.Colors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .strokeBorder(DS.Colors.line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        } else {
            HStack(spacing: 6) {
                Circle()
                    .fill(DS.Colors.ink4)
                    .frame(width: 6, height: 6)
                Text("Sin tono")
                    .font(DS.Fonts.sans(12, weight: .medium))
                    .foregroundStyle(DS.Colors.ink4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DS.Colors.panel)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(DS.Colors.line)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }
}

// MARK: - Stats strip (54 pt)

private struct StatsStrip: View {
    let state: AppState
    let onModelos: () -> Void

    private var wordsToday: Int {
        state.history
            .filter { Calendar.current.isDateInToday($0.date) }
            .compactMap(\.wordCount)
            .reduce(0, +)
    }

    private var modelLine: String {
        let lang = state.language == .auto ? "auto" : state.language.label
        return "\(state.model.rawValue) · \(lang)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text("\(wordsToday)")
                    .font(DS.Fonts.sans(13, weight: .semibold))
                    .foregroundStyle(DS.Colors.ink)
                    .kerning(-0.2)
                Text("palabras hoy")
                    .font(DS.Fonts.sans(13))
                    .foregroundStyle(DS.Colors.ink3)
            }

            if state.isModelLoaded {
                Text(modelLine)
                    .font(DS.Fonts.mono(10.5))
                    .foregroundStyle(DS.Colors.ink3)
            } else if state.isLoadingModel {
                Text("cargando modelo…")
                    .font(DS.Fonts.mono(10.5))
                    .foregroundStyle(DS.Colors.ink3)
            } else {
                Button(action: onModelos) {
                    Text("sin modelo · descargar →")
                        .font(DS.Fonts.mono(10.5))
                        .foregroundStyle(DS.Colors.mossInk)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Footer (34 pt)

private struct PopoverFooter: View {
    let onSettings: () -> Void
    let onHistory: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack {
            Spacer()
            FooterLink("Ajustes", action: onSettings)
            midDot
            FooterLink("Cuaderno", action: onHistory)
            midDot
            FooterLink("Salir", action: onQuit)
            Spacer()
        }
    }

    private var midDot: some View {
        Text("·")
            .font(DS.Fonts.sans(12))
            .foregroundStyle(DS.Colors.ink4)
            .padding(.horizontal, 6)
    }
}

// MARK: - Shared sub-components

private struct FooterLink: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Fonts.sans(11.5))
                .foregroundStyle(isHovered ? DS.Colors.ink : DS.Colors.ink3)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct RecDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(DS.Colors.rec)
            .frame(width: 6, height: 6)
            .opacity(pulse ? 0.4 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

private struct TildeWave: ViewModifier {
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    offset = -1
                }
            }
    }
}
