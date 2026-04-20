import ServiceManagement
import SwiftUI

struct GeneralPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    @State private var openSelector: SelectorField? = nil
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private enum SelectorField { case language, outputMode }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("General")
                .font(DS.Fonts.display(22))
                .foregroundStyle(DS.Colors.ink)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 20)

            switchesCard
                .padding(.horizontal, 28)

            modoLocalBanner
                .padding(.horizontal, 28)
                .padding(.top, 12)

            selectorsCard
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 28)
        }
    }

    // MARK: - Switches card

    private var switchesCard: some View {
        VStack(spacing: 0) {
            settingRow(title: "Abrir al iniciar",
                       desc: "Tildo se lanza al encender el Mac.") {
                DSToggleTrack(isOn: Binding(
                    get: { launchAtLogin },
                    set: { v in
                        launchAtLogin = v
                        try? v ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }
                ))
            }
            Divider().padding(.leading, 16)

            settingRow(title: "Mostrar en barra de menús",
                       desc: "El ícono de la tilde vive arriba a la derecha.") {
                DSToggleTrack(isOn: $state.showFloatingWindow.onChange { onSave() })
            }
            Divider().padding(.leading, 16)

            settingRow(title: "Sonido al empezar y parar",
                       desc: "Un tic muy corto, nada intrusivo.") {
                DSToggleTrack(isOn: Binding(
                    get: { state.startSound != .none },
                    set: { v in
                        state.startSound = v ? .pop : .none
                        state.stopSound  = v ? .funk : .none
                        onSave()
                    }
                ))
            }
        }
        .background(DS.Colors.card)
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    // MARK: - Selectors card

    private var selectorsCard: some View {
        VStack(spacing: 0) {
            // Language — zIndex(2) when open so dropdown renders above output row
            selectorRow(title: "Idioma principal",
                        desc: "Tildo detecta cambios puntuales al inglés.") {
                TildoDropdown(
                    items: Language.allCases,
                    isOpen: Binding(get: { openSelector == .language },
                                    set: { openSelector = $0 ? .language : nil }),
                    triggerHeight: rowTriggerHeight,
                    onSelect: { lang in state.language = lang; onSave() },
                    minListWidth: 200,
                    listAlignment: .topTrailing
                ) {
                    selectorTrigger(label: state.language.label,
                                    isOpen: openSelector == .language,
                                    action: { openSelector = openSelector == .language ? nil : .language })
                } row: { lang, highlighted in
                    TildoDropdownRow(label: lang.label, isHighlighted: highlighted,
                                     isSelected: state.language == lang)
                }
            }
            .zIndex(openSelector == .language ? 2 : 0)

            Divider().padding(.leading, 16)

            // Output mode
            selectorRow(title: "Modo de salida",
                        desc: "Teclado simula pulsaciones. Portapapeles copia el texto.") {
                TildoDropdown(
                    items: OutputMode.allCases,
                    isOpen: Binding(get: { openSelector == .outputMode },
                                    set: { openSelector = $0 ? .outputMode : nil }),
                    triggerHeight: rowTriggerHeight,
                    onSelect: { mode in state.outputMode = mode; onSave() },
                    minListWidth: 180,
                    listAlignment: .topTrailing
                ) {
                    selectorTrigger(label: state.outputMode.rawValue,
                                    isOpen: openSelector == .outputMode,
                                    action: { openSelector = openSelector == .outputMode ? nil : .outputMode })
                } row: { mode, highlighted in
                    TildoDropdownRow(label: mode.rawValue, isHighlighted: highlighted,
                                     isSelected: state.outputMode == mode)
                }
            }
            .zIndex(openSelector == .outputMode ? 2 : 0)
        }
        // No clipShape — clip would hide the dropdown overlay that overflows the card bounds.
        // Shape is applied via background so children can overflow visually.
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(DS.Colors.card)
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(DS.Colors.line, lineWidth: 1))
        )
    }

    // Fixed height for each selector row trigger so TildoDropdown offsets correctly
    private let rowTriggerHeight: CGFloat = 30

    // MARK: - Helpers

    @ViewBuilder
    private func settingRow<Control: View>(
        title: String,
        desc: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DS.Fonts.sans(13, weight: .medium)).foregroundStyle(DS.Colors.ink)
                Text(desc).font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink3)
            }
            Spacer()
            control()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    @ViewBuilder
    private func selectorRow<DropdownContent: View>(
        title: String,
        desc: String,
        @ViewBuilder dropdown: () -> DropdownContent
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DS.Fonts.sans(13, weight: .medium)).foregroundStyle(DS.Colors.ink)
                Text(desc).font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink3)
            }
            Spacer()
            dropdown()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func selectorTrigger(label: String, isOpen: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label)
                    .font(DS.Fonts.sans(13))
                    .foregroundStyle(DS.Colors.ink2)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DS.Colors.ink3)
                    .rotationEffect(isOpen ? .degrees(180) : .zero)
                    .animation(.easeInOut(duration: 0.15), value: isOpen)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .frame(height: 30)
            .background(DS.Colors.panel)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm)
                .strokeBorder(isOpen ? DS.Colors.ink3 : DS.Colors.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Modo local banner

    private var modoLocalBanner: some View {
        HStack(spacing: 8) {
            Text("∼")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.mossInk)
            (Text("Modo local.").font(DS.Fonts.sans(12, weight: .semibold)) +
             Text(" Tu voz se procesa en este ordenador. Ningún audio sale a la red.")
                .font(DS.Fonts.sans(12)))
            .foregroundStyle(DS.Colors.mossInk)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.mossSoft)
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(Color(hex: "DCE4CC"), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

// MARK: - Binding onChange helper (kept here for use within panel)

extension Binding {
    func onChange(_ perform: @escaping () -> Void) -> Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { newValue in wrappedValue = newValue; perform() }
        )
    }
}
