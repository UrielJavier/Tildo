import SwiftUI

struct AboutPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void
    var onHotkeyChange: (() -> Void)?

    @State private var showResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Privacy")
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
                    Text("Local dictation for macOS")
                        .font(DS.Fonts.sans(12))
                        .foregroundStyle(DS.Colors.ink3)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            DSDivider()

            linkRow(label: "Tildo on GitHub", url: "https://github.com/UrielJavier/Tildo",
                    icon: "star")

            DSDivider()

            linkRow(label: "Report an issue",
                    url: "https://github.com/UrielJavier/Tildo/issues/new",
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
                Text("Everything is processed on this Mac. No audio or text leaves the network.")
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.mossInk)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.mossSoft)

            DSDivider()

            permissionRow(icon: "mic",
                          name: "Microphone",
                          desc: "Records your voice for local transcription. Audio is fully processed on this device by whisper.cpp and discarded when done.")

            DSDivider()

            permissionRow(icon: "accessibility",
                          name: "Accessibility",
                          desc: "Required for the global hotkey (CGEvent tap) and to simulate keystrokes in Keyboard mode.")
        }
        .background(DS.Colors.card)
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    // MARK: - Data card

    private var dataCard: some View {
        VStack(spacing: 0) {
            dataRow(icon: "brain",
                    label: "Models",
                    path: "~/.voicetotext/models/",
                    desc: "Downloaded model files (binary weights from OpenAI Whisper via whisper.cpp). You can delete them from Settings > Models.")

            DSDivider()

            dataRow(icon: "gearshape",
                    label: "Settings",
                    path: "UserDefaults",
                    desc: "Preferences, rules, and history. No analytics, telemetry, or crash reports.")
        }
        .background(DS.Colors.card)
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    // MARK: - Reset card

    private var resetCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Reset settings")
                    .font(DS.Fonts.sans(13, weight: .medium))
                    .foregroundStyle(DS.Colors.ink)
                Text("Restores all settings to their original values. Models and history will not be affected.")
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.ink3)
            }
            Spacer(minLength: 12)
            Button("Reset") {
                showResetConfirmation = true
            }
            .buttonStyle(.dsDestructive)
            .alert("Reset all settings?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    state.resetToDefaults()
                    onSave()
                    onHotkeyChange?()
                }
            } message: {
                Text("All settings will be restored to their default values. Downloaded models and history will not be affected.")
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

    private func permissionRow(icon: String, name: LocalizedStringKey, desc: LocalizedStringKey) -> some View {
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

    private func dataRow(icon: String, label: LocalizedStringKey, path: String, desc: LocalizedStringKey) -> some View {
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
