import SwiftUI
import AppKit

struct AppRulesPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("App Rules", subtitle: "Assign a tone per app or set a global default.")

            defaultToneSection

            if !state.appRules.isEmpty {
                perAppSection
            }

            HStack(spacing: 8) {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add rule", systemImage: "plus.circle.fill").font(.callout)
                }
                .buttonStyle(.bordered)
                .disabled(state.tones.isEmpty)

                if state.tones.isEmpty {
                    Text("Create tones first in the Tones section.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(24)
        .sheet(isPresented: $showAddSheet) {
            AppRuleEditSheet(tones: state.tones, rule: nil) { newRule in
                state.appRules.append(newRule)
                onSave()
            }
        }
    }

    // MARK: - Default tone

    private var defaultToneSection: some View {
        settingsCard {
            HStack {
                settingsRow("Default tone", icon: "sparkles")
                Spacer()
                Picker("", selection: Binding(
                    get: { state.defaultToneId },
                    set: { state.defaultToneId = $0; onSave() }
                )) {
                    Text("None").tag(Optional<UUID>.none)
                    if !state.tones.isEmpty { Divider() }
                    ForEach(state.tones) { tone in
                        Text(tone.name).tag(Optional<UUID>.some(tone.id))
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            Text("Applied when no per-app rule matches.")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }

    // MARK: - Per-app rules

    private var perAppSection: some View {
        settingsCard {
            Text("Per-app rules").font(.callout.weight(.medium))
            Divider()
            VStack(spacing: 0) {
                ForEach(state.appRules) { rule in
                    AppRuleRow(
                        rule: rule,
                        toneName: state.tones.first(where: { $0.id == rule.toneId })?.name ?? "—",
                        onToggle: {
                            if let idx = state.appRules.firstIndex(where: { $0.id == rule.id }) {
                                state.appRules[idx].isEnabled.toggle()
                                onSave()
                            }
                        },
                        onDelete: {
                            state.appRules.removeAll { $0.id == rule.id }
                            onSave()
                        }
                    )
                    if rule.id != state.appRules.last?.id {
                        Divider().padding(.leading, 36)
                    }
                }
            }
        }
    }
}

// MARK: - Rule Row

private struct AppRuleRow: View {
    let rule: AppRule
    let toneName: String
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            AppIconImage(appName: rule.appName).frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(rule.appName).font(.callout.weight(.medium))
                    if !rule.urlPattern.isEmpty {
                        Text(rule.urlPattern)
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(.quaternary))
                    }
                }
                Text(toneName).font(.caption).foregroundStyle(.tertiary)
            }

            Spacer()

            Toggle("", isOn: Binding(get: { rule.isEnabled }, set: { _ in onToggle() }))
                .toggleStyle(.switch).controlSize(.mini).labelsHidden()

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill").font(.callout).foregroundStyle(.red.opacity(0.6))
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Add Rule Sheet

private struct AppRuleEditSheet: View {
    let tones: [AppTone]
    let rule: AppRule?
    let onSave: (AppRule) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var appName: String
    @State private var urlPattern: String
    @State private var selectedToneId: UUID?
    @State private var showAppPicker = false

    private let knownBrowsers: Set<String> = [
        "Google Chrome", "Google Chrome Canary", "Chromium",
        "Brave Browser", "Arc", "Microsoft Edge", "Opera", "Vivaldi",
        "Safari", "Safari Technology Preview", "Firefox"
    ]

    init(tones: [AppTone], rule: AppRule?, onSave: @escaping (AppRule) -> Void) {
        self.tones = tones
        self.rule = rule
        self.onSave = onSave
        _appName = State(initialValue: rule?.appName ?? "")
        _urlPattern = State(initialValue: rule?.urlPattern ?? "")
        _selectedToneId = State(initialValue: rule?.toneId ?? tones.first?.id)
    }

    private var isBrowser: Bool { knownBrowsers.contains(appName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(rule == nil ? "Add Rule" : "Edit Rule")
                .font(.title3.weight(.semibold))

            // App
            VStack(alignment: .leading, spacing: 6) {
                Text("App").font(.callout.weight(.medium))
                HStack(spacing: 8) {
                    if !appName.isEmpty {
                        AppIconImage(appName: appName).frame(width: 24, height: 24)
                    }
                    TextField("App name", text: $appName)
                        .textFieldStyle(.plain).font(.callout)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
                    Button {
                        showAppPicker = true
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                    .buttonStyle(.bordered)
                    .popover(isPresented: $showAppPicker, arrowEdge: .bottom) {
                        RunningAppPickerPopover { picked in
                            appName = picked
                            showAppPicker = false
                        }
                    }
                }
            }

            // URL pattern (browsers only)
            if isBrowser {
                VStack(alignment: .leading, spacing: 6) {
                    Text("URL Pattern").font(.callout.weight(.medium))
                    TextField("e.g. github.com, mail.google.com", text: $urlPattern)
                        .textFieldStyle(.plain).font(.callout)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
                    Text("Leave empty to match any site.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }

            // Tone
            VStack(alignment: .leading, spacing: 6) {
                Text("Tone").font(.callout.weight(.medium))
                Picker("", selection: Binding(
                    get: { selectedToneId },
                    set: { selectedToneId = $0 }
                )) {
                    ForEach(tones) { tone in
                        Text(tone.name).tag(Optional<UUID>.some(tone.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Button(rule == nil ? "Add" : "Save") {
                    guard let toneId = selectedToneId else { return }
                    onSave(AppRule(
                        id: rule?.id ?? UUID(),
                        appName: appName.trimmingCharacters(in: .whitespacesAndNewlines),
                        urlPattern: isBrowser ? urlPattern.trimmingCharacters(in: .whitespacesAndNewlines) : "",
                        toneId: toneId,
                        isEnabled: rule?.isEnabled ?? true
                    ))
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedToneId == nil)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

// MARK: - Running app picker popover

private struct RunningAppPickerPopover: View {
    let onSelect: (String) -> Void

    private var apps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.localizedName != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(apps, id: \.processIdentifier) { app in
                    Button { onSelect(app.localizedName ?? "") } label: {
                        HStack(spacing: 8) {
                            if let icon = app.icon {
                                Image(nsImage: icon).resizable().scaledToFit().frame(width: 20, height: 20)
                            }
                            Text(app.localizedName ?? "").font(.callout)
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .background(AppPickerRowHover())
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 200, height: 280)
    }
}

private struct AppPickerRowHover: View {
    @State private var hovered = false
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(hovered ? Color.accentColor.opacity(0.12) : Color.clear)
            .onHover { hovered = $0 }
    }
}
