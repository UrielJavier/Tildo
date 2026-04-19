import SwiftUI

struct TonesPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    @State private var selectedIdx: Int? = nil
    @State private var isCreating = false
    @State private var editingTone: AppTone?

    private func isActive(_ tone: AppTone) -> Bool {
        state.defaultToneId == tone.id || state.appRules.contains { $0.toneId == tone.id }
    }

    private func usageLabel(_ tone: AppTone) -> String {
        if state.defaultToneId == tone.id { return "Default tone" }
        let names = state.appRules.filter { $0.toneId == tone.id }.map { $0.appName }.prefix(3).joined(separator: ", ")
        return names.isEmpty ? "Not assigned" : "Used in \(names)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHero(icon: "music.note.list", title: "Tones",
                      subtitle: "Styles applied by the AI when post-processing your transcriptions.")
                .padding(.horizontal, 32)
                .padding(.top, 28)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Header: count + New tone
                    HStack {
                        let activeCount = state.tones.filter { isActive($0) }.count
                        Text("\(activeCount) active · \(state.tones.count) total")
                            .font(DS.Fonts.sans(13)).foregroundStyle(DS.Colors.ink2)
                        Spacer()
                        Button { isCreating = true } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                                Text("New tone").font(DS.Fonts.sans(12, weight: .medium))
                            }
                        }
                        .buttonStyle(.dsPrimary)
                    }

                    if state.tones.isEmpty {
                        emptyState
                    } else {
                        // Tone list
                        VStack(spacing: 6) {
                            ForEach(Array(state.tones.enumerated()), id: \.element.id) { i, tone in
                                ToneRow(
                                    tone: tone,
                                    isSelected: selectedIdx == i,
                                    isActive: isActive(tone),
                                    usageLabel: usageLabel(tone),
                                    onTap: { selectedIdx = selectedIdx == i ? nil : i }
                                )
                            }
                        }

                        // Inspector for selected tone
                        if let idx = selectedIdx, idx < state.tones.count {
                            ToneInspector(
                                tone: state.tones[idx],
                                onEdit: { editingTone = state.tones[idx] },
                                onDelete: {
                                    state.tones.remove(at: idx)
                                    selectedIdx = nil
                                    onSave()
                                }
                            )
                        }
                    }

                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
        }
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.system(size: 28)).foregroundStyle(DS.Colors.ink3.opacity(0.4))
            Text("No tones yet")
                .font(DS.Fonts.sans(14, weight: .medium)).foregroundStyle(DS.Colors.ink2)
            Text("Create tones to control how the AI styles your transcriptions.")
                .font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Tone row

private struct ToneRow: View {
    let tone: AppTone
    let isSelected: Bool
    let isActive: Bool
    let usageLabel: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(DS.Colors.mossSoft).frame(width: 32, height: 32)
                    Image(systemName: "music.note").font(.system(size: 14)).foregroundStyle(DS.Colors.moss)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(tone.name)
                        .font(DS.Fonts.sans(13, weight: .medium)).foregroundStyle(DS.Colors.ink)
                    Text(usageLabel)
                        .font(DS.Fonts.sans(11)).foregroundStyle(DS.Colors.ink3)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isActive {
                    Text("ACTIVE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white).tracking(0.2)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(DS.Colors.moss))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? DS.Colors.card : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? DS.Colors.line : Color.clear, lineWidth: 1)
            )
            .shadow(color: isSelected ? .black.opacity(0.04) : .clear, radius: 2, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tone inspector

private struct ToneInspector: View {
    let tone: AppTone
    let onEdit: () -> Void
    let onDelete: () -> Void

    private static let sampleRaw = "hey so um i think we should like push the launch to next week"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Inspector header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(DS.Colors.mossSoft).frame(width: 30, height: 30)
                    Image(systemName: "music.note").font(.system(size: 13)).foregroundStyle(DS.Colors.moss)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(tone.name).font(DS.Fonts.sans(13, weight: .medium)).foregroundStyle(DS.Colors.ink)
                    Text("Prompt & preview").font(DS.Fonts.sans(11)).foregroundStyle(DS.Colors.ink3)
                }
                Spacer()
                Button("Edit", action: onEdit).buttonStyle(.dsSecondary)
                Button(action: onDelete) {
                    Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(DS.Colors.rec)
                }
                .buttonStyle(.dsGhost)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            DSDivider()

            VStack(alignment: .leading, spacing: 0) {
                // PROMPT
                Text("PROMPT")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(DS.Colors.ink3).tracking(0.6)
                    .padding(.bottom, 6)
                Text(tone.stylePrompt.isEmpty ? "No custom instructions" : tone.stylePrompt)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(DS.Colors.ink).lineSpacing(3)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Colors.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DS.Colors.line, lineWidth: 1))

                // PREVIEW
                Text("PREVIEW")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(DS.Colors.ink3).tracking(0.6)
                    .padding(.top, 16).padding(.bottom, 8)

                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RAW")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(DS.Colors.ink3).tracking(0.6)
                        Text("\"\(Self.sampleRaw)\"")
                            .font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink2)
                            .italic().lineSpacing(2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Colors.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DS.Colors.line, lineWidth: 1))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12)).foregroundStyle(DS.Colors.moss)
                        .padding(.top, 18)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AFTER")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(DS.Colors.moss).tracking(0.6)
                        Text(tone.stylePrompt.isEmpty ? "No transformation" : "Result will appear here after a real recording.")
                            .font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink2).lineSpacing(2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Colors.mossSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DS.Colors.moss.opacity(0.25), lineWidth: 1))
                }
            }
            .padding(14)
        }
        .background(DS.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.line, lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.2), value: tone.id)
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
                .font(.system(size: 22, weight: .semibold)).foregroundStyle(DS.Colors.ink)

            VStack(alignment: .leading, spacing: 6) {
                Text("Name").font(DS.Fonts.sans(13, weight: .medium)).foregroundStyle(DS.Colors.ink2)
                TextField("e.g. Casual, Work Formal, WhatsApp", text: $name)
                    .textFieldStyle(.plain).font(DS.Fonts.sans(14))
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.sm).fill(DS.Colors.panel))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.line, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Preset").font(DS.Fonts.sans(13, weight: .medium)).foregroundStyle(DS.Colors.ink2)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(StylePreset.allCases) { preset in
                        TonePresetButton(preset: preset, isSelected: selectedPreset == preset) {
                            selectedPreset = preset
                            if preset != .none { stylePrompt = preset.prompt }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Instructions").font(DS.Fonts.sans(13, weight: .medium)).foregroundStyle(DS.Colors.ink2)
                TextField("e.g. Casual tone, no capital letters, skip periods.", text: $stylePrompt, axis: .vertical)
                    .textFieldStyle(.plain).font(DS.Fonts.sans(14))
                    .lineLimit(3...6).padding(8)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.sm).fill(DS.Colors.panel))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.line, lineWidth: 1))
                    .onChange(of: stylePrompt) {
                        if stylePrompt != selectedPreset.prompt { selectedPreset = .none }
                    }
                Text("These instructions are sent to the AI. Leave empty to just fix punctuation.")
                    .font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink3)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.dsSecondary).keyboardShortcut(.escape)
                Button("Save") {
                    onSave(AppTone(
                        id: tone?.id ?? UUID(),
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        stylePrompt: stylePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                    dismiss()
                }
                .buttonStyle(.dsPrimary)
                .keyboardShortcut(.return)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(DS.Colors.panel)
        .preferredColorScheme(.light)
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
                Text(preset.rawValue).font(DS.Fonts.sans(12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6).padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(isSelected ? DS.Colors.mossSoft : DS.Colors.panel))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm)
                .strokeBorder(isSelected ? DS.Colors.moss : DS.Colors.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? DS.Colors.moss : DS.Colors.ink2)
    }
}
