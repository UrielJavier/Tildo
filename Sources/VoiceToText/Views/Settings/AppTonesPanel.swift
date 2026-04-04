import SwiftUI
import AppKit

// MARK: - Known browsers (shared between panel and TextSimulator logic)
private let knownBrowsers: Set<String> = [
    "Google Chrome", "Google Chrome Canary", "Chromium",
    "Brave Browser", "Arc", "Microsoft Edge", "Opera", "Vivaldi",
    "Safari", "Safari Technology Preview", "Firefox"
]

// MARK: - Panel

struct AppTonesPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    @State private var editingRule: AppToneRule?
    @State private var addingWithApp: String?   // pre-filled app name for new rule
    @State private var showMorePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                "App Tones",
                subtitle: "Apply a different AI tone depending on which app is active when you record."
            )

            // Quick-add: top apps from Dock + running apps
            settingsCard {
                Text("Your apps").font(.callout.weight(.medium))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6),
                    spacing: 12
                ) {
                    ForEach(topApps, id: \.self) { appName in
                        AppIconButton(
                            appName: appName,
                            isConfigured: state.appToneRules.contains { $0.appName == appName }
                        ) {
                            if let existing = state.appToneRules.first(where: { $0.appName == appName }) {
                                editingRule = existing
                            } else {
                                addingWithApp = appName
                            }
                        }
                    }

                    // "More" button
                    Button { showMorePicker = true } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.secondary)
                            Text("More")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showMorePicker, arrowEdge: .bottom) {
                        RunningAppPicker { picked in
                            showMorePicker = false
                            if let existing = state.appToneRules.first(where: { $0.appName == picked }) {
                                editingRule = existing
                            } else {
                                addingWithApp = picked
                            }
                        }
                    }
                }
            }

            // Configured rules list
            if !state.appToneRules.isEmpty {
                settingsCard {
                    Text("Configured rules").font(.callout.weight(.medium))
                    Divider()
                    VStack(spacing: 0) {
                        ForEach(state.appToneRules) { rule in
                            AppToneRuleRow(
                                rule: rule,
                                onToggle: { toggle(rule); onSave() },
                                onEdit: { editingRule = rule },
                                onDelete: { state.appToneRules.removeAll { $0.id == rule.id }; onSave() }
                            )
                            if rule.id != state.appToneRules.last?.id {
                                Divider().padding(.leading, 36)
                            }
                        }
                    }
                }
            }

            Text("When no rule matches, the global style from AI Enhance is used.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
        .padding(24)
        .sheet(item: $addingWithApp) { appName in
            AppToneEditSheet(appName: appName, rule: nil) { newRule in
                state.appToneRules.append(newRule)
                onSave()
            }
        }
        .sheet(item: $editingRule) { rule in
            AppToneEditSheet(appName: rule.appName, rule: rule) { updated in
                if let idx = state.appToneRules.firstIndex(where: { $0.id == updated.id }) {
                    state.appToneRules[idx] = updated
                    onSave()
                }
            }
        }
    }

    // MARK: - Top apps (Dock pinned + running, deduplicated, up to 5)
    private var topApps: [String] {
        var names: [String] = []

        // Dock pinned apps
        let dockURL = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Preferences/com.apple.dock.plist")
        if let data = try? Data(contentsOf: dockURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let apps = plist["persistent-apps"] as? [[String: Any]] {
            let dockNames = apps.compactMap { ($0["tile-data"] as? [String: Any])?["file-label"] as? String }
            names.append(contentsOf: dockNames)
        }

        // Add running regular apps not already in list
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular, let name = app.localizedName, !names.contains(name) else { continue }
            names.append(name)
        }

        return Array(names.filter { $0 != "EchoWrite" }.prefix(5))
    }

    private func toggle(_ rule: AppToneRule) {
        if let idx = state.appToneRules.firstIndex(where: { $0.id == rule.id }) {
            state.appToneRules[idx].isEnabled.toggle()
        }
    }
}

// String conformance for sheet(item:) — uses the app name as identity
extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - App Icon Button

private struct AppIconButton: View {
    let appName: String
    let isConfigured: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    AppIconImage(appName: appName)
                        .frame(width: 36, height: 36)
                    if isConfigured {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white, Color.accentColor)
                            .offset(x: 4, y: -4)
                    }
                }
                Text(appName)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isConfigured ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isConfigured ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App Icon Image (reused in row + button)

struct AppIconImage: View {
    let appName: String

    var body: some View {
        if let icon = resolveIcon() {
            Image(nsImage: icon).resizable().scaledToFit()
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
        }
    }

    private func resolveIcon() -> NSImage? {
        // 1. Running app icon
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }),
           let icon = app.icon { return icon }
        // 2. Installed app via NSWorkspace
        if let url = NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: "/")) {
            _ = url // unused, just checking pattern
        }
        // 3. Search by name in /Applications
        let candidates = [
            "/Applications/\(appName).app",
            "/System/Applications/\(appName).app",
            "/Applications/Utilities/\(appName).app"
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }
        return nil
    }
}

// MARK: - Rule Row

private struct AppToneRuleRow: View {
    let rule: AppToneRule
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            AppIconImage(appName: rule.appName)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(rule.appName).font(.callout.weight(.medium))
                    if !rule.urlPattern.isEmpty {
                        Text(rule.urlPattern)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(.quaternary))
                    }
                }
                Text(rule.stylePrompt.isEmpty ? "(empty)" : rule.stylePrompt)
                    .font(.caption).foregroundStyle(.tertiary).lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(get: { rule.isEnabled }, set: { _ in onToggle() }))
                .toggleStyle(.switch).controlSize(.mini).labelsHidden()

            Button(action: onEdit) {
                Image(systemName: "pencil").font(.caption).foregroundStyle(.secondary)
            }.buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill").font(.callout).foregroundStyle(.red.opacity(0.6))
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Edit Sheet

private struct AppToneEditSheet: View {
    let appName: String
    let rule: AppToneRule?
    let onSave: (AppToneRule) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var urlPattern: String
    @State private var selectedPreset: StylePreset
    @State private var customPrompt: String

    private var isBrowser: Bool { knownBrowsers.contains(appName) }

    init(appName: String, rule: AppToneRule?, onSave: @escaping (AppToneRule) -> Void) {
        self.appName = appName
        self.rule = rule
        self.onSave = onSave
        _urlPattern = State(initialValue: rule?.urlPattern ?? "")
        let prompt = rule?.stylePrompt ?? ""
        let matched = StylePreset.allCases.first { $0 != .none && $0.prompt == prompt }
        _selectedPreset = State(initialValue: matched ?? .none)
        _customPrompt = State(initialValue: prompt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // App header
            HStack(spacing: 12) {
                AppIconImage(appName: appName).frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appName).font(.title3.weight(.semibold))
                    if isBrowser {
                        Text("Web browser — you can match by URL").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            // URL pattern — only for browsers
            if isBrowser {
                VStack(alignment: .leading, spacing: 6) {
                    Text("URL Pattern").font(.callout.weight(.medium))
                    TextField("e.g. github.com, mail.google.com", text: $urlPattern)
                        .textFieldStyle(.plain).font(.callout)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
                    Text("Leave empty to match any site. Matched as substring of the active tab's URL.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }

            // Style presets
            VStack(alignment: .leading, spacing: 10) {
                Text("Style").font(.callout.weight(.medium))
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 8
                ) {
                    ForEach(StylePreset.allCases) { preset in
                        TonePresetButton(preset: preset, isSelected: selectedPreset == preset) {
                            selectedPreset = preset
                            if preset != .none { customPrompt = preset.prompt }
                        }
                    }
                }
            }

            // Custom prompt
            VStack(alignment: .leading, spacing: 6) {
                Text(selectedPreset == .none ? "Custom instructions" : "Instructions (from preset)")
                    .font(.callout.weight(.medium))
                TextField(
                    "e.g. Casual, no capital letters, skip periods.",
                    text: $customPrompt,
                    axis: .vertical
                )
                .textFieldStyle(.plain).font(.callout)
                .lineLimit(3...6)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
                .onChange(of: customPrompt) {
                    if customPrompt != selectedPreset.prompt { selectedPreset = .none }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Button("Save") {
                    onSave(AppToneRule(
                        id: rule?.id ?? UUID(),
                        appName: appName,
                        urlPattern: isBrowser ? urlPattern.trimmingCharacters(in: .whitespacesAndNewlines) : "",
                        stylePrompt: customPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
                        isEnabled: rule?.isEnabled ?? true
                    ))
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}

// MARK: - Tone Preset Button

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
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Running App Picker (popover for "More")

private struct RunningAppPicker: View {
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
                    .background(RowHover())
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 200, height: 280)
    }
}

private struct RowHover: View {
    @State private var hovered = false
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(hovered ? Color.accentColor.opacity(0.12) : Color.clear)
            .onHover { hovered = $0 }
    }
}
