import SwiftUI

struct TonesPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    @State private var selectedTab: ToneTab = .biblioteca

    enum ToneTab { case biblioteca, porAplicacion }

    private var appsConfigured: Int { state.appRules.count }

    private func usageCount(_ tone: AppTone) -> Int {
        state.appRules.filter { $0.toneId == tone.id }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Top bar ──────────────────────────────────
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(state.tones.count) TONOS · \(appsConfigured) APPS CONFIGURADAS")
                        .font(DS.Fonts.mono(10, weight: .medium))
                        .foregroundStyle(DS.Colors.ink4)
                        .tracking(0.4)

                    Text("Tonos")
                        .font(DS.Fonts.display(28))
                        .foregroundStyle(DS.Colors.ink)
                        .tracking(-0.4)
                }

                Spacer()

                Button { state.toneAddOpen = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                        Text("New tone").font(DS.Fonts.sans(13, weight: .semibold))
                    }
                    .foregroundStyle(DS.Colors.paper)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(DS.Colors.ink)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // ── Tabs ─────────────────────────────────────
            HStack(spacing: 0) {
                ToneTabButton(
                    label: "Library",
                    count: state.tones.count,
                    isSelected: selectedTab == .biblioteca
                ) { selectedTab = .biblioteca }

                ToneTabButton(
                    label: "By app",
                    count: appsConfigured,
                    isSelected: selectedTab == .porAplicacion
                ) { selectedTab = .porAplicacion }
            }
            .padding(.horizontal, 28)

            Rectangle().fill(DS.Colors.line).frame(height: 1)

            // ── Content ──────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if selectedTab == .biblioteca {
                        bibliotecaContent
                    } else {
                        porAplicacionContent
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
        }
        .background(DS.Colors.paper)
    }

    // MARK: - Biblioteca tab

    @ViewBuilder
    private var bibliotecaContent: some View {
        // Intro
        Text("A **tone** is a way to rewrite your dictation. Create as many as you want and assign them per app in the **By app** tab.")
            .font(DS.Fonts.sans(13))
            .foregroundStyle(DS.Colors.ink2)
            .fixedSize(horizontal: false, vertical: true)

        if state.tones.isEmpty {
            emptyState
        } else {
            VStack(spacing: 10) {
                ForEach(state.tones) { tone in
                    ToneCard(
                        tone: tone,
                        isDefault: state.defaultToneId == tone.id,
                        usageCount: usageCount(tone),
                        onSetDefault: {
                            state.defaultToneId = state.defaultToneId == tone.id ? nil : tone.id
                            onSave()
                        },
                        onEdit: { state.toneEditing = tone },
                        onDuplicate: { copy in
                            state.tones.append(copy)
                            onSave()
                        },
                        onDelete: {
                            state.tones.removeAll { $0.id == tone.id }
                            if state.defaultToneId == tone.id { state.defaultToneId = nil }
                            onSave()
                        }
                    )
                }
            }
        }
    }

    // MARK: - Por aplicación tab

    @ViewBuilder
    private var porAplicacionContent: some View {
        AppRulesPanel(state: state, onSave: onSave)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 28)).foregroundStyle(DS.Colors.ink3.opacity(0.4))
            Text("No tones")
                .font(DS.Fonts.sans(14, weight: .medium)).foregroundStyle(DS.Colors.ink2)
            Text("Create tones to control how AI rewrites your transcriptions.")
                .font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Tab button

private struct ToneTabButton: View {
    let label: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(DS.Fonts.sans(13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DS.Colors.ink : DS.Colors.ink3)

                Text("\(count)")
                    .font(DS.Fonts.mono(10))
                    .foregroundStyle(isSelected ? DS.Colors.ink3 : DS.Colors.ink4)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DS.Colors.panel)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 10)
            .padding(.trailing, 20)
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle()
                        .fill(DS.Colors.ink)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tone Card

private struct ToneCard: View {
    let tone: AppTone
    let isDefault: Bool
    let usageCount: Int
    let onSetDefault: () -> Void
    let onEdit: () -> Void
    let onDuplicate: (AppTone) -> Void
    let onDelete: () -> Void

    @State private var showActions = false

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(DS.Colors.moss)
                .frame(width: 3)
                .padding(.vertical, 1)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: 8) {
                    Text(tone.name)
                        .font(DS.Fonts.sans(15, weight: .semibold))
                        .foregroundStyle(DS.Colors.ink)

                    Spacer()

                    Button { showActions = true } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DS.Colors.ink3)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showActions, arrowEdge: .trailing) {
                        ToneActionsPopover(
                            isDefault: isDefault,
                            usageCount: usageCount,
                            onSetDefault: { showActions = false; onSetDefault() },
                            onEdit: { showActions = false; onEdit() },
                            onDuplicate: {
                                showActions = false
                                let copy = AppTone(id: UUID(), name: tone.name + " (copy)", description: tone.description, category: tone.category, stylePrompt: tone.stylePrompt, preview: tone.preview)
                                onDuplicate(copy)
                            },
                            onDelete: { showActions = false; onDelete() }
                        )
                    }
                }

                if !tone.stylePrompt.isEmpty {
                    Text(tone.stylePrompt)
                        .font(DS.Fonts.sans(11))
                        .foregroundStyle(DS.Colors.ink3)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }

                if isDefault || usageCount > 0 {
                    HStack(spacing: 5) {
                        if isDefault { TagChip(label: String(localized: "default"), style: .dark) }
                        if usageCount > 0 { TagChip(label: "\(usageCount) app\(usageCount == 1 ? "" : "s")", style: .green) }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.leading, 14)
            .padding(.vertical, 14)
            .padding(.trailing, 14)
        }
        .background(DS.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(isDefault ? DS.Colors.ink : DS.Colors.line, lineWidth: 1)
        )
    }
}

// MARK: - Actions Popover

private struct ToneActionsPopover: View {
    let isDefault: Bool
    let usageCount: Int
    let onSetDefault: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PopoverAction(label: isDefault ? String(localized: "Remove as default") : String(localized: "Set as default"), action: onSetDefault)
            Divider()
            PopoverAction(label: String(localized: "Edit"), action: onEdit)
            Divider()
            PopoverAction(label: String(localized: "Duplicate"), action: onDuplicate)
            Divider()
            PopoverAction(label: "Delete", color: DS.Colors.rec, disabled: isDefault || usageCount > 0, disabledHint: "Remove the tone from all apps first", action: onDelete)
        }
        .frame(width: 180)
        .background(DS.Colors.paper)
    }
}

struct PopoverAction: View {
    let label: String
    var color: Color = DS.Colors.ink
    var disabled: Bool = false
    var disabledHint: String = ""
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: { if !disabled { action() } }) {
            Text(label)
                .font(DS.Fonts.sans(13))
                .foregroundStyle(disabled ? DS.Colors.ink4 : color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isHovered && !disabled ? DS.Colors.panel : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(disabled ? disabledHint : "")
    }
}

// MARK: - Tag Chip

private struct TagChip: View {
    let label: String
    enum Style { case green, dark }
    let style: Style

    var body: some View {
        Text(label)
            .font(DS.Fonts.mono(9))
            .foregroundStyle(style == .dark ? DS.Colors.paper : DS.Colors.mossInk)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(style == .dark ? DS.Colors.ink : DS.Colors.mossSoft)
            .clipShape(Capsule())
    }
}

// MARK: - Side Panel

struct ToneSidePanel: View {
    let tone: AppTone?
    let allTones: [AppTone]
    let onClose: () -> Void
    let onSave: (AppTone) -> Void

    @State private var name: String
    @State private var etiqueta: String
    @State private var description: String
    @State private var stylePrompt: String
    @State private var preview: String
    @State private var basedOnId: UUID?

    private static let sampleRaw = "pues mira, hemos sacado como una nueva versión del editor que es bastante más rápida y tiene modo oscuro"

    init(tone: AppTone?, allTones: [AppTone], onClose: @escaping () -> Void, onSave: @escaping (AppTone) -> Void) {
        self.tone = tone
        self.allTones = allTones
        self.onClose = onClose
        self.onSave = onSave
        _name = State(initialValue: tone?.name ?? "")
        _etiqueta = State(initialValue: tone?.category ?? "")
        _description = State(initialValue: tone?.description ?? "")
        _stylePrompt = State(initialValue: tone?.stylePrompt ?? "")
        _preview = State(initialValue: tone?.preview ?? "")
        _basedOnId = State(initialValue: nil)
    }

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tone == nil ? "New tone" : "Edit tone")
                        .font(DS.Fonts.sans(18, weight: .semibold))
                        .foregroundStyle(DS.Colors.ink)
                    Text("Define how to rewrite your dictation.")
                        .font(DS.Fonts.sans(12))
                        .foregroundStyle(DS.Colors.ink3)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.Colors.ink3)
                        .frame(width: 22, height: 22)
                        .background(DS.Colors.panel)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Rectangle().fill(DS.Colors.line).frame(height: 1)

            // ── Form ──────────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Nombre
                    SidePanelField(label: "Name", hint: "Appears in the list and in per-app menus.") {
                        TextField("e.g. Marketing, Casual, Work", text: $name)
                            .textFieldStyle(.plain)
                            .font(DS.Fonts.sans(14))
                            .padding(10)
                            .background(DS.Colors.paper)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.line, lineWidth: 1))
                    }

                    // Partir de...
                    if !allTones.isEmpty {
                        HStack(spacing: 10) {
                            Text("Start from…")
                                .font(DS.Fonts.sans(13, weight: .medium))
                                .foregroundStyle(DS.Colors.ink2)
                            Picker("", selection: $basedOnId) {
                                Text("Blank").tag(UUID?.none)
                                ForEach(allTones) { t in
                                    Text(t.name).tag(Optional(t.id))
                                }
                            }
                            .labelsHidden()
                            .onChange(of: basedOnId) {
                                if let id = basedOnId, let base = allTones.first(where: { $0.id == id }) {
                                    if stylePrompt.isEmpty { stylePrompt = base.stylePrompt }
                                }
                            }
                        }
                    }

                    // Instrucciones al modelo
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Instructions")
                                .font(DS.Fonts.sans(13, weight: .medium))
                                .foregroundStyle(DS.Colors.ink2)
                            Spacer()
                            Text("prompt")
                                .font(DS.Fonts.mono(10))
                                .foregroundStyle(DS.Colors.ink4)
                        }
                        TextField("e.g. Rewrite in marketing copy tone: short proposals, verb first…", text: $stylePrompt, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12.5, design: .monospaced))
                            .lineLimit(5...10)
                            .padding(10)
                            .background(DS.Colors.paper)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.line, lineWidth: 1))
                    }

                    // Vista previa
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PREVIEW")
                            .font(DS.Fonts.mono(10, weight: .medium))
                            .foregroundStyle(DS.Colors.ink4)
                            .tracking(0.4)

                        VStack(alignment: .leading, spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("RAW")
                                    .font(DS.Fonts.mono(9, weight: .medium))
                                    .foregroundStyle(DS.Colors.ink4)
                                    .tracking(0.3)
                                Text(Self.sampleRaw)
                                    .font(DS.Fonts.sans(13))
                                    .foregroundStyle(DS.Colors.ink2)
                            }
                            .padding(14)

                            Rectangle().fill(DS.Colors.line).frame(height: 1)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(etiqueta.isEmpty ? (name.isEmpty ? String(localized: "TONE") : name.uppercased()) : etiqueta.uppercased())
                                    .font(DS.Fonts.mono(9, weight: .medium))
                                    .foregroundStyle(DS.Colors.moss)
                                    .tracking(0.3)
                                Text(preview.isEmpty ? String(localized: "Result will appear here after a real recording.") : preview)
                                    .font(DS.Fonts.sans(13))
                                    .foregroundStyle(preview.isEmpty ? DS.Colors.ink4 : DS.Colors.ink2)
                                    .italic(preview.isEmpty)
                            }
                            .padding(14)
                        }
                        .background(DS.Colors.panel)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.line, lineWidth: 1))
                    }

                    // Guardar
                    Button {
                        onSave(AppTone(
                            id: tone?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: "",
                            stylePrompt: stylePrompt.trimmingCharacters(in: .whitespacesAndNewlines),
                            preview: preview.trimmingCharacters(in: .whitespacesAndNewlines)
                        ))
                    } label: {
                        Text("Save tone")
                            .font(DS.Fonts.sans(13, weight: .semibold))
                            .foregroundStyle(DS.Colors.paper)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isValid ? DS.Colors.ink : DS.Colors.ink4)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isValid)
                }
                .padding(28)
            }
        }
        .background(DS.Colors.paper)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .shadow(color: .black.opacity(0.12), radius: 24, x: -4, y: 0)
    }
}

private struct SidePanelField<Content: View>: View {
    let label: String
    let hint: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(DS.Fonts.sans(13, weight: .medium))
                .foregroundStyle(DS.Colors.ink2)
            content()
            Text(hint)
                .font(DS.Fonts.sans(11))
                .foregroundStyle(DS.Colors.ink4)
        }
    }
}
