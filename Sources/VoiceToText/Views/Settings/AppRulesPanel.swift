import SwiftUI
import AppKit

struct AppRulesPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    @State private var showAddSheet = false
    @State private var editingRule: AppRule? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHero(icon: "app.badge", title: "App Rules",
                      subtitle: "Assign a tone per app. Rules are checked in order — first match wins.")
                .padding(.horizontal, 32)
                .padding(.top, 28)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    defaultToneCard
                    evaluationHint
                    toolbar
                    if !state.appRules.isEmpty {
                        rulesTable
                    }
                    footerNote
                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
        }
        .onChange(of: state.appRules) { onSave() }
        .sheet(isPresented: $showAddSheet) {
            AppRuleEditSheet(tones: state.tones, rule: nil) { newRule in
                state.appRules.append(newRule)
                onSave()
            }
        }
        .sheet(item: $editingRule) { rule in
            AppRuleEditSheet(tones: state.tones, rule: rule) { updated in
                if let idx = state.appRules.firstIndex(where: { $0.id == updated.id }) {
                    state.appRules[idx] = updated
                    onSave()
                }
            }
        }
    }

    // MARK: - Default tone card

    private var defaultToneCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(DS.Colors.accentSoft).frame(width: 32, height: 32)
                Image(systemName: "sparkles").font(.system(size: 14)).foregroundStyle(DS.Colors.accent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Default tone").font(DS.Fonts.sans(12.5, weight: .medium)).foregroundStyle(DS.Colors.ink)
                Text("Applied when no app rule matches").font(DS.Fonts.sans(11)).foregroundStyle(DS.Colors.ink3)
            }
            Spacer()
            Menu {
                Button("None") { state.defaultToneId = nil; onSave() }
                if !state.tones.isEmpty { Divider() }
                ForEach(state.tones) { tone in
                    Button(tone.name) { state.defaultToneId = tone.id; onSave() }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(state.tones.first(where: { $0.id == state.defaultToneId })?.name ?? "None")
                        .font(DS.Fonts.sans(13)).foregroundStyle(DS.Colors.ink)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)).foregroundStyle(DS.Colors.ink3)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(DS.Colors.bg)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(DS.Colors.line2, lineWidth: 1))
            }
            .menuStyle(.borderlessButton).fixedSize()
        }
        .padding(14)
        .background(DS.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(DS.Colors.line, lineWidth: 1))
    }

    // MARK: - Evaluation hint

    private var evaluationHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle").font(.system(size: 12)).foregroundStyle(DS.Colors.ink3)
            Text("Rules are checked top to bottom. The first match wins.")
                .font(DS.Fonts.sans(11.5)).foregroundStyle(DS.Colors.ink3)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(DS.Colors.bg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(DS.Colors.line2, style: StrokeStyle(lineWidth: 1, dash: [4]))
        )
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("\(state.appRules.filter { $0.isEnabled }.count) enabled · \(state.appRules.count) total")
                .font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink2)
            Spacer()
            Button { showAddSheet = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                    Text("Add rule").font(DS.Fonts.sans(12, weight: .medium))
                }
            }
            .buttonStyle(.dsPrimary)
            .disabled(state.tones.isEmpty)
        }
    }

    // MARK: - Rules table

    private var rulesTable: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                Color.clear.frame(width: 20)
                Color.clear.frame(width: 32)
                Text("APP / MATCH")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(DS.Colors.ink3).tracking(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("TONE")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(DS.Colors.ink3).tracking(0.8)
                    .frame(width: 110, alignment: .leading)
                Color.clear.frame(width: 36)
                Color.clear.frame(width: 24)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(DS.Colors.bg)
            DSDivider()

            ForEach(Array(state.appRules.enumerated()), id: \.element.id) { i, rule in
                RuleRow(
                    rule: $state.appRules[i],
                    toneName: state.tones.first(where: { $0.id == rule.toneId })?.name ?? "—",
                    tones: state.tones,
                    onEdit: { editingRule = rule },
                    onDelete: {
                        state.appRules.removeAll { $0.id == rule.id }
                        onSave()
                    },
                    onToneChange: { toneId in
                        state.appRules[i].toneId = toneId
                        onSave()
                    }
                )
                if i < state.appRules.count - 1 { DSDivider() }
            }
        }
        .background(DS.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(DS.Colors.line, lineWidth: 1))
    }

    // MARK: - Footer note

    private var footerNote: some View {
        Text("Match by app name or URL (browsers only). Patterns support * wildcards.")
            .font(DS.Fonts.sans(11)).foregroundStyle(DS.Colors.ink3).lineSpacing(1.5)
    }
}

// MARK: - Rule row

private struct RuleRow: View {
    @Binding var rule: AppRule
    let toneName: String
    let tones: [AppTone]
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToneChange: (UUID) -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Drag handle (visual)
            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(DS.Colors.ink3).frame(width: 3, height: 3)
                }
            }
            .frame(width: 20).opacity(0.4)

            // App icon
            AppIconImage(appName: rule.appName)
                .frame(width: 32, height: 32)
                .background(DS.Colors.bg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DS.Colors.line, lineWidth: 1))

            // App name + match pattern
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.appName.isEmpty ? "—" : rule.appName)
                    .font(DS.Fonts.sans(13, weight: .medium)).foregroundStyle(DS.Colors.ink)
                let pattern = rule.urlPattern.isEmpty ? "app: \(rule.appName)" : "url: \(rule.urlPattern)"
                Text(pattern)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(DS.Colors.ink3).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Inline tone picker
            Menu {
                ForEach(tones) { tone in
                    Button(tone.name) { onToneChange(tone.id) }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(toneName).font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)).foregroundStyle(DS.Colors.ink3)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(DS.Colors.bg)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(DS.Colors.line2, lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 110)

            // Toggle
            DSToggleTrack(isOn: $rule.isEnabled).scaleEffect(0.8).frame(width: 36, height: 18)

            // More menu
            Menu {
                Button("Edit…", action: onEdit)
                Divider()
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12)).foregroundStyle(DS.Colors.ink3)
                    .frame(width: 24, height: 24)
            }
            .menuStyle(.borderlessButton).frame(width: 24)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .opacity(rule.isEnabled ? 1 : 0.55)
    }
}

// MARK: - Add / Edit sheet

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
                .font(.system(size: 22, weight: .semibold)).foregroundStyle(DS.Colors.ink)

            VStack(alignment: .leading, spacing: 6) {
                Text("App").font(DS.Fonts.sans(13, weight: .medium)).foregroundStyle(DS.Colors.ink2)
                HStack(spacing: 8) {
                    if !appName.isEmpty { AppIconImage(appName: appName).frame(width: 24, height: 24) }
                    TextField("App name", text: $appName)
                        .textFieldStyle(.plain).font(DS.Fonts.sans(14)).padding(8)
                        .background(RoundedRectangle(cornerRadius: DS.Radius.sm).fill(DS.Colors.bg))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.line2, lineWidth: 1))
                    Button { showAppPicker = true } label: { Image(systemName: "list.bullet") }
                        .buttonStyle(.dsSecondary)
                        .popover(isPresented: $showAppPicker, arrowEdge: .bottom) {
                            RunningAppPickerPopover { picked in appName = picked; showAppPicker = false }
                        }
                }
            }

            if isBrowser {
                VStack(alignment: .leading, spacing: 6) {
                    Text("URL Pattern").font(DS.Fonts.sans(13, weight: .medium)).foregroundStyle(DS.Colors.ink2)
                    TextField("e.g. github.com, mail.google.com", text: $urlPattern)
                        .textFieldStyle(.plain).font(DS.Fonts.sans(14)).padding(8)
                        .background(RoundedRectangle(cornerRadius: DS.Radius.sm).fill(DS.Colors.bg))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.line2, lineWidth: 1))
                    Text("Leave empty to match any site.").font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink3)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Tone").font(DS.Fonts.sans(13, weight: .medium)).foregroundStyle(DS.Colors.ink2)
                Menu {
                    ForEach(tones) { tone in Button(tone.name) { selectedToneId = tone.id } }
                } label: {
                    HStack(spacing: 5) {
                        Text(tones.first(where: { $0.id == selectedToneId })?.name ?? "Select tone")
                            .font(DS.Fonts.sans(13)).foregroundStyle(DS.Colors.ink)
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)).foregroundStyle(DS.Colors.ink3)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(DS.Colors.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(DS.Colors.line2, lineWidth: 1))
                }
                .menuStyle(.borderlessButton).fixedSize()
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.dsSecondary).keyboardShortcut(.escape)
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
                .buttonStyle(.dsPrimary).keyboardShortcut(.return)
                .disabled(appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedToneId == nil)
            }
        }
        .padding(24).frame(width: 400)
        .background(DS.Colors.bg).preferredColorScheme(.light)
    }
}

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
                            Text(app.localizedName ?? "").font(DS.Fonts.sans(13)).foregroundStyle(DS.Colors.ink)
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                    }
                    .buttonStyle(.plain).contentShape(Rectangle())
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
            .fill(hovered ? DS.Colors.bg : Color.clear)
            .onHover { hovered = $0 }
    }
}
