import SwiftUI

struct MainWindowView: View {
    @Bindable var state: AppState
    var onSave: () -> Void
    var onHotkeyChange: (() -> Void)?
    var onCancelHotkeyChange: (() -> Void)?
    var onPauseHotkey: (() -> Void)?
    var onResumeHotkey: (() -> Void)?
    var onStartMonitoring: (() -> Void)?
    var onStopMonitoring: (() -> Void)?
    var onDownloadModel: ((WhisperModel) -> Void)?
    var onLoadModel: ((WhisperModel) -> Void)?
    var onUnloadModel: (() -> Void)?
    var onCancelDownload: (() -> Void)?

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                MainSidebar(state: state)
                    .frame(width: 220)

                Rectangle()
                    .fill(DS.Colors.line)
                    .frame(width: 1)

                mainContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if state.showSettings {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        state.showSettings = false
                        state.ruleAddOpen = false
                        state.ruleEditing = nil
                    }

                SettingsView(
                    state: state,
                    onSave: onSave,
                    onHotkeyChange: onHotkeyChange,
                    onCancelHotkeyChange: onCancelHotkeyChange,
                    onPauseHotkey: onPauseHotkey,
                    onResumeHotkey: onResumeHotkey,
                    onStartMonitoring: onStartMonitoring,
                    onStopMonitoring: onStopMonitoring,
                    onDownloadModel: onDownloadModel,
                    onLoadModel: onLoadModel,
                    onUnloadModel: onUnloadModel,
                    onCancelDownload: onCancelDownload
                )
                .frame(width: 760, height: 560)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.22), radius: 40, x: 0, y: 12)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }

            if state.ruleAddOpen || state.ruleEditing != nil {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture { state.ruleAddOpen = false; state.ruleEditing = nil }

                HStack(spacing: 0) {
                    Spacer()
                    AppRuleEditSheet(
                        tones: state.tones,
                        rule: state.ruleEditing,
                        existingAppNames: Set(state.appRules.map { $0.appName }),
                        onClose: { state.ruleAddOpen = false; state.ruleEditing = nil },
                        onSave: { saved in
                            if let editing = state.ruleEditing,
                               let idx = state.appRules.firstIndex(where: { $0.id == editing.id }) {
                                state.appRules[idx] = saved
                            } else {
                                state.appRules.append(saved)
                            }
                            onSave()
                            state.ruleAddOpen = false
                            state.ruleEditing = nil
                        }
                    )
                    .id(state.ruleEditing?.id ?? UUID())
                    .frame(width: 380)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if state.toneAddOpen || state.toneEditing != nil {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture { state.toneAddOpen = false; state.toneEditing = nil }

                HStack(spacing: 0) {
                    Spacer()
                    ToneSidePanel(
                        tone: state.toneEditing,
                        allTones: state.tones,
                        onClose: { state.toneAddOpen = false; state.toneEditing = nil },
                        onSave: { saved in
                            if let editing = state.toneEditing,
                               let idx = state.tones.firstIndex(where: { $0.id == editing.id }) {
                                state.tones[idx] = saved
                            } else {
                                state.tones.append(saved)
                            }
                            onSave()
                            state.toneAddOpen = false
                            state.toneEditing = nil
                        }
                    )
                    .id(state.toneEditing?.id ?? UUID())
                    .frame(width: 480)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

        }
        .animation(.spring(duration: 0.25), value: state.showSettings)
        .animation(.spring(duration: 0.28), value: state.ruleAddOpen || state.ruleEditing != nil)
        .animation(.spring(duration: 0.28), value: state.toneAddOpen || state.toneEditing != nil)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var mainContent: some View {
        switch state.selectedMainSection {
        case .inicio:
            InicioView(state: state, onOpenCuaderno: {
                state.selectedMainSection = .cuaderno
            })
        case .diccionario:
            ReplacementsPanel(state: state, onSave: onSave)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(DS.Colors.paper)
        case .tonos:
            TonesPanel(state: state, onSave: onSave)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(DS.Colors.paper)
        case .cuaderno:
            HistoryView(state: state, onSave: onSave)
                .background(DS.Colors.paper)
        }
    }
}

// MARK: - Sidebar

private struct MainSidebar: View {
    @Bindable var state: AppState

    private var wordsToday: Int {
        state.history
            .filter { Calendar.current.isDateInToday($0.date) }
            .compactMap { $0.wordCount }
            .reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text("∼")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Colors.moss)
                Text("Tildo")
                    .font(DS.Fonts.sans(14, weight: .semibold))
                    .foregroundStyle(DS.Colors.ink)
                Spacer()
                if wordsToday > 0 {
                    Text("\(wordsToday)")
                        .font(DS.Fonts.mono(10))
                        .foregroundStyle(DS.Colors.ink4)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(DS.Colors.panel)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // Main nav items
            VStack(spacing: 1) {
                MainSidebarItem(
                    label: "Home",
                    icon: MainSection.inicio.icon,
                    badge: nil,
                    isSelected: state.selectedMainSection == .inicio
                ) {
                    state.selectedMainSection = .inicio
                }

                MainSidebarItem(
                    label: "Dictionary",
                    icon: MainSection.diccionario.icon,
                    badge: state.replacementRules.isEmpty ? nil : "\(state.replacementRules.count)",
                    isSelected: state.selectedMainSection == .diccionario
                ) {
                    state.selectedMainSection = .diccionario
                }

                MainSidebarItem(
                    label: "Tones",
                    icon: MainSection.tonos.icon,
                    badge: state.tones.isEmpty ? nil : "\(state.tones.count)",
                    isSelected: state.selectedMainSection == .tonos
                ) {
                    state.selectedMainSection = .tonos
                }

                MainSidebarItem(
                    label: "Notebook",
                    icon: MainSection.cuaderno.icon,
                    badge: nil,
                    isSelected: state.selectedMainSection == .cuaderno
                ) {
                    state.selectedMainSection = .cuaderno
                }
            }
            .padding(.horizontal, 4)

            Text("SYSTEM")
                .font(DS.Fonts.mono(10, weight: .medium))
                .foregroundStyle(DS.Colors.ink4)
                .tracking(0.5)
                .padding(.horizontal, 14)
                .padding(.top, 20)
                .padding(.bottom, 6)

            VStack(spacing: 1) {
                MainSidebarItem(
                    label: "Settings",
                    icon: "gearshape",
                    badge: nil,
                    isSelected: false
                ) {
                    state.showSettings = true
                }
            }
            .padding(.horizontal, 4)

            Spacer()

            GitHubCard()
                .padding(.horizontal, 10)
                .padding(.bottom, 10)

            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                .font(DS.Fonts.mono(10))
                .foregroundStyle(DS.Colors.ink4)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
        .background(DS.Colors.panel)
    }
}

// MARK: - GitHub Card

private struct GitHubCard: View {
    private var githubLogo: NSImage? {
        Bundle.main.url(forResource: "github-mark", withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
    }
    private var githubLogoWhite: NSImage? {
        Bundle.main.url(forResource: "github-mark-white", withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let logo = githubLogo {
                    Image(nsImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                }
                Text("Open source")
                    .font(DS.Fonts.sans(12, weight: .semibold))
                    .foregroundStyle(DS.Colors.ink)
            }

            Text("Tildo is free and lives on GitHub. A star means a lot.")
                .font(DS.Fonts.sans(11))
                .foregroundStyle(DS.Colors.ink3)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                NSWorkspace.shared.open(URL(string: "https://github.com/UrielJavier/Tildo")!)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Star on GitHub")
                        .font(DS.Fonts.sans(11.5, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(DS.Colors.paper)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(DS.Colors.ink)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(DS.Colors.paper)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(DS.Colors.line, lineWidth: 1)
        )
    }
}

// MARK: - Sidebar Item

private struct MainSidebarItem: View {
    let label: LocalizedStringKey
    let icon: String
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isSelected ? DS.Colors.ink : DS.Colors.ink3)
                    .frame(width: 16, alignment: .center)

                Text(label)
                    .font(DS.Fonts.sans(12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DS.Colors.ink : DS.Colors.ink2)

                Spacer()

                if let badge {
                    Text(badge)
                        .font(DS.Fonts.mono(10))
                        .foregroundStyle(DS.Colors.ink4)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(DS.Colors.panel)
                        .clipShape(Capsule())
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .frame(height: 32)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DS.Colors.paper)
                            .padding(4)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DS.Colors.lineSoft)
                            .padding(4)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
