import SwiftUI

struct AboutPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void
    var onHotkeyChange: (() -> Void)?

    @State private var showResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            panelHero(icon: "info.circle", title: "About")

            settingsCard {
                HStack(spacing: 12) {
                    Image(systemName: "mic.badge.xmark")
                        .font(.system(size: 28))
                        .foregroundStyle(DS.Colors.moss)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("EchoWrite")
                            .font(DS.Fonts.serif(18))
                            .foregroundStyle(DS.Colors.ink)
                        Text("Local speech-to-text for macOS")
                            .font(DS.Fonts.sans(13))
                            .foregroundStyle(DS.Colors.oliveGray)
                    }
                }
            }

            settingsCard {
                settingsRow("Feedback & Issues", icon: "exclamationmark.bubble")
                Text("Found a bug or have a suggestion? Open an issue on GitHub.")
                    .font(DS.Fonts.sans(13))
                    .foregroundStyle(DS.Colors.oliveGray)

                Link(destination: URL(string: "https://github.com/urieljavier/EchoWrite")!) {
                    linkRow("EchoWrite on GitHub")
                }
                Link(destination: URL(string: "https://github.com/urieljavier/EchoWrite/issues/new")!) {
                    linkRow("Report an issue")
                }
            }

            settingsCard {
                settingsRow("Permissions", icon: "lock.shield")
                Text("Everything runs locally on your Mac. No audio, text or data is ever sent to any server.")
                    .font(DS.Fonts.sans(13))
                    .foregroundStyle(DS.Colors.oliveGray)

                DSDivider()

                permissionRow(
                    icon: "mic", name: "Microphone",
                    reason: "Records your voice for local transcription. Audio is processed entirely on-device by whisper.cpp and discarded after transcription — it is never stored or transmitted.",
                    api: "AVCaptureDevice (AVFoundation)"
                )

                DSDivider()

                permissionRow(
                    icon: "accessibility", name: "Accessibility",
                    reason: "Required for two features:",
                    details: [
                        ("keyboard", "Global hotkey — intercepts your shortcut (\(state.hotkeyLabel)) via CGEvent tap so it works in any app without the system beep."),
                        ("text.cursor", "Type mode — simulates keystrokes (CGEvent) to type the transcribed text at your cursor position. Not used in Clipboard mode."),
                    ],
                    api: "CGEvent.tapCreate / CGEvent (CoreGraphics)"
                )

                DSDivider()

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "network.slash")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                            .frame(width: 20)
                        Text("No network access required")
                            .font(DS.Fonts.sans(14, weight: .medium))
                            .foregroundStyle(DS.Colors.charcoalWarm)
                    }
                    Text("The app only connects to the internet when you explicitly download a model from Settings > Models.")
                        .font(DS.Fonts.sans(12))
                        .foregroundStyle(DS.Colors.stoneGray)
                }
            }

            settingsCard {
                settingsRow("Data & Storage", icon: "folder.badge.gearshape")
                dataRow(icon: "brain", label: "Models", path: "~/.voicetotext/models/",
                        detail: "Downloaded model files (binary weights, no code). You can delete them from Settings > Models.")
                DSDivider()
                dataRow(icon: "gearshape", label: "Settings", path: "UserDefaults (standard)",
                        detail: "Preferences, prompt, replacement rules and history. Reset from About > Reset.")
                Text("No other files are created. No analytics, telemetry or crash reports are collected.")
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.stoneGray)
            }

            settingsCard {
                settingsRow("Trust chain", icon: "checkmark.shield")
                VStack(alignment: .leading, spacing: 6) {
                    trustStep("1", "OpenAI trains and publishes the original Whisper models (open-source, MIT license)")
                    trustStep("2", "Georgi Gerganov converts them to GGML format via whisper.cpp, the most used C/C++ inference engine for Whisper")
                    trustStep("3", "Models are hosted on HuggingFace and downloaded over HTTPS to ~/.voicetotext/models/")
                }

                Text("Model files are binary weights (numbers, no executable code).")
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.stoneGray)

                DSDivider()

                VStack(alignment: .leading, spacing: 6) {
                    ForEach([
                        ("whisper.cpp on GitHub", "https://github.com/ggml-org/whisper.cpp"),
                        ("Models on HuggingFace", "https://huggingface.co/ggerganov/whisper.cpp"),
                        ("OpenAI Whisper (MIT License)", "https://github.com/openai/whisper"),
                    ], id: \.0) { item in
                        Link(destination: URL(string: item.1)!) {
                            linkRow(item.0)
                        }
                    }
                }
            }

            Spacer().frame(height: 8)

            settingsCard {
                settingsRow("Reset", icon: "arrow.counterclockwise")
                Text("Restore all settings to their original values. This will not delete downloaded models or history.")
                    .font(DS.Fonts.sans(13))
                    .foregroundStyle(DS.Colors.oliveGray)
                Button {
                    showResetConfirmation = true
                } label: {
                    Label("Reset all settings to defaults", systemImage: "arrow.counterclockwise")
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
                    Text("This will restore all settings to their default values. Downloaded models and history will not be affected.")
                }
            }
        }
        .padding(24)
    }

    private func linkRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "link").font(.system(size: 10))
            Text(text).font(DS.Fonts.sans(13))
        }
        .foregroundStyle(DS.Colors.moss)
    }

    private func permissionRow(icon: String, name: String, reason: String,
                               details: [(icon: String, text: String)]? = nil, api: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12)).foregroundStyle(.orange).frame(width: 20)
                Text(name).font(DS.Fonts.sans(14, weight: .medium)).foregroundStyle(DS.Colors.charcoalWarm)
            }
            Text(reason).font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.oliveGray)
            if let details {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(details, id: \.icon) { item in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: item.icon).font(.system(size: 10)).foregroundStyle(DS.Colors.stoneGray).frame(width: 16).padding(.top, 2)
                            Text(item.text).font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.oliveGray)
                        }
                    }
                }
                .padding(.leading, 4)
            }
            Text("API: \(api)").font(DS.Fonts.sans(10)).foregroundStyle(DS.Colors.stoneGray.opacity(0.6))
        }
    }

    private func dataRow(icon: String, label: String, path: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12)).foregroundStyle(DS.Colors.stoneGray).frame(width: 20)
                Text(label).font(DS.Fonts.sans(14, weight: .medium)).foregroundStyle(DS.Colors.charcoalWarm)
            }
            Text(path).font(.system(size: 11, design: .monospaced)).foregroundStyle(DS.Colors.stoneGray).textSelection(.enabled)
            Text(detail).font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.oliveGray)
        }
    }

    private func trustStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(DS.Fonts.sans(11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(DS.Colors.stoneGray.opacity(0.5)))
            Text(text)
                .font(DS.Fonts.sans(13))
                .foregroundStyle(DS.Colors.oliveGray)
        }
    }
}
