import SwiftUI

struct TranscriptionPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            panelHero(icon: "waveform", title: "Transcription", subtitle: "Audio tuning and transcription hints. Changes apply on the next session.")

            // MARK: - Audio tuning

            settingsCard {
                settingsRow("Chunk interval", icon: "clock.arrow.2.circlepath",
                            trailing: String(format: "%.1fs", state.liveChunkInterval))
                Slider(value: $state.liveChunkInterval, in: 1...5, step: 0.5)
                    .tint(.accentColor)
                Text("How often audio is sent to transcribe. Shorter = faster but more CPU.")
                    .font(.caption).foregroundStyle(.tertiary)
            }

            settingsCard {
                settingsRow("Audio overlap", icon: "waveform.path",
                            trailing: "\(state.liveOverlapMs)ms")
                Slider(value: Binding(
                    get: { Double(state.liveOverlapMs) },
                    set: { state.liveOverlapMs = Int($0) }
                ), in: 0...1000, step: 100)
                    .tint(.accentColor)
                Text("Audio kept from the previous chunk to avoid cutting words at boundaries.")
                    .font(.caption).foregroundStyle(.tertiary)
            }

            settingsCard {
                settingsRow("Silence threshold", icon: "waveform.badge.minus",
                            trailing: String(format: "%.4f", state.liveSilenceThreshold))

                AudioLevelMeter(level: state.audioLevel, threshold: state.liveSilenceThreshold)
                    .frame(height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Slider(value: $state.liveSilenceThreshold, in: 0.0005...0.01, step: 0.0005)
                    .tint(.accentColor)
                Text("The bar shows your mic level in real time. The red line marks the silence threshold.")
                    .font(.caption).foregroundStyle(.tertiary)
            }

            settingsCard {
                settingsRow("Silence timeout", icon: "timer",
                            trailing: String(format: "%.0fs", state.liveSilenceTimeout))
                Slider(value: $state.liveSilenceTimeout, in: 4...60, step: 2)
                    .tint(.accentColor)
                Text("Seconds of continuous silence before auto-stopping.")
                    .font(.caption).foregroundStyle(.tertiary)
            }

            // MARK: - Prompt hints (merged from PromptPanel)

            settingsCard {
                settingsRow("Transcription hints", icon: "text.quote")
                Text("Guide the Whisper model with context. All fields are optional.")
                    .font(.caption).foregroundStyle(.tertiary)
            }

            promptField(
                "Context", icon: "doc.text",
                placeholder: "e.g. Technical meeting about iOS development with SwiftUI",
                text: $state.promptContext
            )

            promptField(
                "Vocabulary", icon: "character.textbox",
                placeholder: "e.g. Whisper, Xcode, SwiftUI, Kubernetes",
                text: $state.promptVocabulary
            )

            promptField(
                "Style & Tone", icon: "theatermasks",
                placeholder: "e.g. Formal tone, complete sentences, third person",
                text: $state.promptStyle
            )

            promptField(
                "Punctuation", icon: "textformat.abc",
                placeholder: "e.g. Use commas, periods and question marks. No ellipsis",
                text: $state.promptPunctuation
            )

            promptField(
                "Instructions", icon: "plus.bubble",
                placeholder: "e.g. Ignore background noise. Short paragraphs",
                text: $state.promptInstructions
            )

            let composed = state.composedPrompt
            if !composed.isEmpty {
                settingsCard {
                    HStack(spacing: 8) {
                        Image(systemName: "eye")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text("Prompt preview").font(.callout.weight(.medium))
                        Spacer()
                        Button {
                            state.promptContext = ""
                            state.promptVocabulary = ""
                            state.promptStyle = ""
                            state.promptPunctuation = ""
                            state.promptInstructions = ""
                        } label: {
                            Label("Clear all", systemImage: "xmark.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    Text(composed)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.3)))
                }
            }
        }
        .padding(24)
    }

    private func promptField(
        _ title: String, icon: String, placeholder: String,
        text: Binding<String>, axis: Axis = .vertical
    ) -> some View {
        settingsCard {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(title).font(.callout.weight(.medium))
            }
            TextField(placeholder, text: text, axis: axis)
                .textFieldStyle(.plain)
                .font(.callout)
                .lineLimit(1...4)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
                .onChange(of: text.wrappedValue) { onSave() }
        }
    }
}
