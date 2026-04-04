import SwiftUI

struct TonesPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    @State private var editingTone: AppTone?
    @State private var isCreating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                sectionHeader("Tones", subtitle: "Styles applied by the AI when post-processing your transcriptions.")
                Spacer()
                Button { isCreating = true } label: {
                    Label("New Tone", systemImage: "plus")
                        .font(.callout)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.top, 2)
            }

            settingsCard {
                VStack(spacing: 0) {
                    ForEach(state.tones) { tone in
                        let inUse = state.defaultToneId == tone.id || state.appRules.contains { $0.toneId == tone.id }
                        ToneRow(
                            tone: tone,
                            inUse: inUse,
                            onEdit: { editingTone = tone },
                            onDelete: {
                                state.tones.removeAll { $0.id == tone.id }
                                onSave()
                            }
                        )
                        if tone.id != state.tones.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .padding(24)
        .sheet(isPresented: $isCreating) {
            ToneEditSheet(tone: nil) { newTone in
                state.tones.append(newTone)
                onSave()
            }
        }
        .sheet(item: $editingTone) { tone in
            ToneEditSheet(tone: tone) { updated in
                if let idx = state.tones.firstIndex(where: { $0.id == updated.id }) {
                    state.tones[idx] = updated
                    onSave()
                }
            }
        }
    }
}

// MARK: - Row

private struct ToneRow: View {
    let tone: AppTone
    let inUse: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var matchedPreset: StylePreset? {
        StylePreset.allCases.first { $0 != .none && $0.rawValue == tone.name }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: matchedPreset?.icon ?? "music.note")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tone.name).font(.callout.weight(.medium))
                    if inUse {
                        Text("In use")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(.quaternary))
                    }
                }
                Text(tone.stylePrompt.isEmpty ? "No instructions" : tone.stylePrompt)
                    .font(.caption).foregroundStyle(.tertiary).lineLimit(1)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil").font(.caption).foregroundStyle(.secondary)
            }.buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill").font(.callout)
                    .foregroundColor(inUse ? .secondary : .red.opacity(0.6))
            }
            .buttonStyle(.plain)
            .disabled(inUse)
            .help(inUse ? "Remove it from App Rules before deleting" : "Delete tone")
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Edit Sheet

private struct ToneEditSheet: View {
    let tone: AppTone?
    let onSave: (AppTone) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedPreset: StylePreset
    @State private var stylePrompt: String

    init(tone: AppTone?, onSave: @escaping (AppTone) -> Void) {
        self.tone = tone
        self.onSave = onSave
        _name = State(initialValue: tone?.name ?? "")
        let prompt = tone?.stylePrompt ?? ""
        let matched = StylePreset.allCases.first { $0 != .none && $0.prompt == prompt }
        _selectedPreset = State(initialValue: matched ?? .none)
        _stylePrompt = State(initialValue: prompt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(tone == nil ? "New Tone" : "Edit Tone")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Name").font(.callout.weight(.medium))
                TextField("e.g. Casual, Work Formal, WhatsApp", text: $name)
                    .textFieldStyle(.plain).font(.callout)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Preset").font(.callout.weight(.medium))
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 8
                ) {
                    ForEach(StylePreset.allCases) { preset in
                        TonePresetButton(preset: preset, isSelected: selectedPreset == preset) {
                            selectedPreset = preset
                            if preset != .none { stylePrompt = preset.prompt }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Instructions").font(.callout.weight(.medium))
                TextField(
                    "e.g. Casual tone, no capital letters, skip periods.",
                    text: $stylePrompt,
                    axis: .vertical
                )
                .textFieldStyle(.plain).font(.callout)
                .lineLimit(3...6)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
                .onChange(of: stylePrompt) {
                    if stylePrompt != selectedPreset.prompt { selectedPreset = .none }
                }
                Text("These instructions are sent to the AI. Leave empty to just fix punctuation.")
                    .font(.caption).foregroundStyle(.tertiary)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Button("Save") {
                    onSave(AppTone(
                        id: tone?.id ?? UUID(),
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        stylePrompt: stylePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}

private struct TonePresetButton: View {
    let preset: StylePreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: preset.icon).font(.system(size: 11))
                Text(preset.rawValue).font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6).padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15)))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}
