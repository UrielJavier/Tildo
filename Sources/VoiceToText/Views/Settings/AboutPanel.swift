import SwiftUI

struct AboutPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void
    var onHotkeyChange: (() -> Void)?

    @State private var showResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Privacidad")
                .font(DS.Fonts.display(22))
                .foregroundStyle(DS.Colors.ink)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 20)

            appCard
                .padding(.horizontal, 28)

            permissionsCard
                .padding(.horizontal, 28)
                .padding(.top, 12)

            dataCard
                .padding(.horizontal, 28)
                .padding(.top, 12)

            resetCard
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 28)
        }
    }

    // MARK: - App card

    private var appCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("∼")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DS.Colors.moss)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Tildo")
                            .font(DS.Fonts.sans(13, weight: .semibold))
                            .foregroundStyle(DS.Colors.ink)
                        Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                            .font(DS.Fonts.mono(11))
                            .foregroundStyle(DS.Colors.ink4)
                    }
                    Text("Dictado local para macOS")
                        .font(DS.Fonts.sans(12))
                        .foregroundStyle(DS.Colors.ink3)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            DSDivider()

            linkRow(label: "Tildo en GitHub", url: "https://github.com/urieljavier/EchoWrite",
                    icon: "star")

            DSDivider()

            linkRow(label: "Reportar un problema",
                    url: "https://github.com/urieljavier/EchoWrite/issues/new",
                    icon: "exclamationmark.bubble")
        }
        .background(DS.Colors.card)
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    // MARK: - Permissions card

    private var permissionsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("∼")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.mossInk)
                Text("Todo se procesa en este Mac. Ningún audio ni texto sale a la red.")
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.mossInk)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.mossSoft)

            DSDivider()

            permissionRow(icon: "mic",
                          name: "Micrófono",
                          desc: "Graba tu voz para la transcripción local. El audio se procesa íntegramente en este dispositivo con whisper.cpp y se descarta al terminar.")

            DSDivider()

            permissionRow(icon: "accessibility",
                          name: "Accesibilidad",
                          desc: "Necesario para el hotkey global (CGEvent tap) y para simular pulsaciones de teclado en modo Teclado.")
        }
        .background(DS.Colors.card)
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    // MARK: - Data card

    private var dataCard: some View {
        VStack(spacing: 0) {
            dataRow(icon: "brain",
                    label: "Modelos",
                    path: "~/.voicetotext/models/",
                    desc: "Archivos de modelo descargados (pesos binarios de OpenAI Whisper, vía whisper.cpp). Puedes eliminarlos desde Ajustes > Modelos.")

            DSDivider()

            dataRow(icon: "gearshape",
                    label: "Ajustes",
                    path: "UserDefaults",
                    desc: "Preferencias, reglas y historial. Sin analíticas, telemetría ni reportes de errores.")
        }
        .background(DS.Colors.card)
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    // MARK: - Reset card

    private var resetCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Restablecer ajustes")
                    .font(DS.Fonts.sans(13, weight: .medium))
                    .foregroundStyle(DS.Colors.ink)
                Text("Restaura todos los ajustes a sus valores originales. Los modelos y el historial no se verán afectados.")
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.ink3)
            }
            Spacer(minLength: 12)
            Button("Restablecer") {
                showResetConfirmation = true
            }
            .buttonStyle(.dsDestructive)
            .alert("¿Restablecer todos los ajustes?", isPresented: $showResetConfirmation) {
                Button("Cancelar", role: .cancel) {}
                Button("Restablecer", role: .destructive) {
                    state.resetToDefaults()
                    onSave()
                    onHotkeyChange?()
                }
            } message: {
                Text("Se restaurarán todos los ajustes a sus valores por defecto. Los modelos descargados y el historial no se verán afectados.")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(DS.Colors.card)
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    // MARK: - Row helpers

    private func linkRow(label: String, url: String, icon: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Colors.ink3)
                    .frame(width: 18)
                Text(label)
                    .font(DS.Fonts.sans(13))
                    .foregroundStyle(DS.Colors.moss)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Colors.ink4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func permissionRow(icon: String, name: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Colors.ink3)
                    .frame(width: 18)
                Text(name)
                    .font(DS.Fonts.sans(13, weight: .medium))
                    .foregroundStyle(DS.Colors.ink)
                Spacer()
            }
            Text(desc)
                .font(DS.Fonts.sans(12))
                .foregroundStyle(DS.Colors.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 28)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func dataRow(icon: String, label: String, path: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Colors.ink3)
                    .frame(width: 18)
                Text(label)
                    .font(DS.Fonts.sans(13, weight: .medium))
                    .foregroundStyle(DS.Colors.ink)
                Spacer()
            }
            Text(path)
                .font(DS.Fonts.mono(11))
                .foregroundStyle(DS.Colors.ink3)
                .textSelection(.enabled)
                .padding(.leading, 28)
            Text(desc)
                .font(DS.Fonts.sans(12))
                .foregroundStyle(DS.Colors.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 28)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
