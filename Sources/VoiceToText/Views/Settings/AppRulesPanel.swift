import SwiftUI
import AppKit

struct AppRulesPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    @State private var scrollVersion = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHero(icon: "app.badge", title: "App Rules",
                      subtitle: "Assign a tone per app. Rules are checked in order — first match wins.")
                .padding(.horizontal, 32)
                .padding(.top, 28)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    defaultToneCard
                    toolbar
                    if !state.appRules.isEmpty { rulesTable }
                    footerNote
                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
            .simultaneousGesture(DragGesture().onChanged { _ in scrollVersion += 1 })
        }
        .onChange(of: state.appRules) { onSave() }
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
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(DS.Colors.bg)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(DS.Colors.line2, lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
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
            Button { state.ruleAddOpen = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                    Text("Add rule").font(DS.Fonts.sans(12, weight: .medium))
                }
            }
            .buttonStyle(.dsPrimary)
        }
    }

    // MARK: - Rules table

    private var rulesTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Color.clear.frame(width: 28)
                Text("APP / TONO")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(DS.Colors.ink3).tracking(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: 32)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(DS.Colors.bg)
            DSDivider()

            ForEach(Array(state.appRules.enumerated()), id: \.element.id) { i, rule in
                RuleRow(
                    rule: $state.appRules[i],
                    toneName: state.tones.first(where: { $0.id == rule.toneId })?.name ?? "—",
                    scrollVersion: scrollVersion,
                    onEdit: { state.ruleEditing = rule },
                    onDelete: {
                        state.appRules.removeAll { $0.id == rule.id }
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
    let scrollVersion: Int
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showActions = false

    var body: some View {
        HStack(spacing: 8) {
            AppIconImage(appName: rule.appName)
                .frame(width: 28, height: 28)
                .background(DS.Colors.bg)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(DS.Colors.line, lineWidth: 1))

            VStack(alignment: .leading, spacing: 1) {
                Text(rule.appName.isEmpty ? "—" : rule.appName)
                    .font(DS.Fonts.sans(12.5, weight: .medium)).foregroundStyle(DS.Colors.ink).lineLimit(1)
                Text(toneName)
                    .font(DS.Fonts.mono(10)).foregroundStyle(DS.Colors.ink3).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DSToggleTrack(isOn: $rule.isEnabled).scaleEffect(0.75).frame(width: 32, height: 18)

            Button { showActions = true } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.Colors.ink3)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showActions, arrowEdge: .trailing) {
                VStack(spacing: 0) {
                    PopoverAction(label: String(localized: "Edit")) { showActions = false; onEdit() }
                    Divider()
                    PopoverAction(label: "Eliminar", color: DS.Colors.rec) { showActions = false; onDelete() }
                }
                .frame(width: 160)
                .background(DS.Colors.paper)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .opacity(rule.isEnabled ? 1 : 0.55)
        .contentShape(Rectangle())
        .onChange(of: scrollVersion) { showActions = false }
    }
}

private final class MonitorRef {
    var monitor: Any?
    deinit { if let m = monitor { NSEvent.removeMonitor(m) } }
}

// Gets the text field's frame in window coordinates using AppKit directly.
// Uses nsView.convert(bounds, to: nil) which maps to window coords — same space as event.locationInWindow.
private struct FieldWindowFrameReader: NSViewRepresentable {
    @Binding var frame: CGRect
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard nsView.window != nil else { return }
            frame = nsView.convert(nsView.bounds, to: nil)
        }
    }
}

// MARK: - Add / Edit side panel

struct AppRuleEditSheet: View {
    let tones: [AppTone]
    let rule: AppRule?
    let existingAppNames: Set<String>
    let onClose: () -> Void
    let onSave: (AppRule) -> Void

    @State private var appName: String
    @State private var urlPattern: String
    @State private var selectedToneId: UUID?
    @State private var showAppDropdown = false
    @FocusState private var appFieldFocused: Bool
    @State private var allAppEntries: [(name: String, icon: NSImage?)] = []
    @State private var fieldHeight: CGFloat = 38
    @State private var monitorRef = MonitorRef()
    @State private var fieldWindowFrame: CGRect = .zero
    @State private var highlightedIndex: Int? = nil
    @State private var keyMonitorRef = MonitorRef()
    @State private var showToneDropdown = false
    @State private var toneFieldWindowFrame: CGRect = .zero
    @State private var highlightedToneIndex: Int? = nil

    private let knownBrowsers: Set<String> = [
        "Google Chrome", "Google Chrome Canary", "Chromium",
        "Brave Browser", "Arc", "Microsoft Edge", "Opera", "Vivaldi",
        "Safari", "Safari Technology Preview", "Firefox"
    ]

    init(tones: [AppTone], rule: AppRule?, existingAppNames: Set<String>, onClose: @escaping () -> Void, onSave: @escaping (AppRule) -> Void) {
        self.tones = tones
        self.rule = rule
        self.existingAppNames = existingAppNames
        self.onClose = onClose
        self.onSave = onSave
        _appName = State(initialValue: rule?.appName ?? "")
        _urlPattern = State(initialValue: rule?.urlPattern ?? "")
        _selectedToneId = State(initialValue: rule?.toneId ?? tones.first?.id)
    }

    private var isBrowser: Bool { knownBrowsers.contains(appName) }

    private var isDuplicate: Bool {
        let trimmed = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let isEditingSelf = rule?.appName.lowercased() == trimmed.lowercased()
        return !isEditingSelf && existingAppNames.contains(where: { $0.lowercased() == trimmed.lowercased() })
    }

    private var isValid: Bool {
        !appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedToneId != nil
            && !isDuplicate
    }

    private var filteredApps: [(name: String, icon: NSImage?)] {
        let query = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let list = query.isEmpty
            ? allAppEntries
            : allAppEntries.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return Array(list.prefix(8))
    }

    var body: some View {
        formContent
            .background(DS.Colors.paper)
            .onAppear {
                allAppEntries = Self.fetchAllApps()
                monitorRef.monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
                    let loc = event.locationInWindow
                    // fieldWindowFrame is already in window coords (same space as locationInWindow)
                    if !fieldWindowFrame.isEmpty && fieldWindowFrame.contains(loc) {
                        DispatchQueue.main.async { showAppDropdown = true }
                    } else if showAppDropdown {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showAppDropdown = false }
                    }
                    if showToneDropdown && (toneFieldWindowFrame.isEmpty || !toneFieldWindowFrame.contains(loc)) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showToneDropdown = false }
                    }
                    return event
                }
                keyMonitorRef.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if showAppDropdown {
                        let apps = filteredApps
                        guard !apps.isEmpty else { return event }
                        switch event.keyCode {
                        case 125:
                            let next = highlightedIndex.map { min($0 + 1, apps.count - 1) } ?? 0
                            DispatchQueue.main.async { highlightedIndex = next }
                            return nil
                        case 126:
                            let prev = highlightedIndex.map { max($0 - 1, 0) } ?? (apps.count - 1)
                            DispatchQueue.main.async { highlightedIndex = prev }
                            return nil
                        case 36, 76:
                            guard let idx = highlightedIndex, idx < apps.count else { return event }
                            let name = apps[idx].name
                            DispatchQueue.main.async {
                                appName = name
                                showAppDropdown = false
                                highlightedIndex = nil
                                NSApp.keyWindow?.makeFirstResponder(nil)
                            }
                            return nil
                        case 53:
                            DispatchQueue.main.async { showAppDropdown = false; highlightedIndex = nil }
                            return nil
                        default: return event
                        }
                    } else if showToneDropdown {
                        let count = tones.count
                        guard count > 0 else { return event }
                        switch event.keyCode {
                        case 125:
                            let next = highlightedToneIndex.map { min($0 + 1, count - 1) } ?? 0
                            DispatchQueue.main.async { highlightedToneIndex = next }
                            return nil
                        case 126:
                            let prev = highlightedToneIndex.map { max($0 - 1, 0) } ?? (count - 1)
                            DispatchQueue.main.async { highlightedToneIndex = prev }
                            return nil
                        case 36, 76:
                            guard let idx = highlightedToneIndex, idx < count else { return event }
                            let tone = tones[idx]
                            DispatchQueue.main.async {
                                selectedToneId = tone.id
                                showToneDropdown = false
                                highlightedToneIndex = nil
                            }
                            return nil
                        case 53:
                            DispatchQueue.main.async { showToneDropdown = false; highlightedToneIndex = nil }
                            return nil
                        default: return event
                        }
                    } else {
                        return event
                    }
                }
            }
            .onDisappear {
                if let m = monitorRef.monitor { NSEvent.removeMonitor(m); monitorRef.monitor = nil }
                if let m = keyMonitorRef.monitor { NSEvent.removeMonitor(m); keyMonitorRef.monitor = nil }
            }
            .onChange(of: appName) { _ in highlightedIndex = nil }
            .onChange(of: showAppDropdown) { open in if !open { highlightedIndex = nil } }
            .onChange(of: showToneDropdown) { open in if !open { highlightedToneIndex = nil } }
    }

    private static func fetchAllApps() -> [(name: String, icon: NSImage?)] {
        var entries: [String: NSImage?] = [:]
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular, let name = app.localizedName else { continue }
            entries[name] = app.icon
        }
        let dirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications")
        ]
        for dir in dirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
            ) else { continue }
            for url in contents where url.pathExtension == "app" {
                let name = (Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                if entries[name] == nil {
                    entries[name] = NSWorkspace.shared.icon(forFile: url.path)
                }
            }
        }
        return entries.map { (name: $0.key, icon: $0.value) }.sorted { $0.name < $1.name }
    }

    private var formContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(rule == nil ? "New rule" : "Edit rule")
                        .font(DS.Fonts.sans(18, weight: .semibold)).foregroundStyle(DS.Colors.ink)
                    Text("Assign a tone to a specific app.")
                        .font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink3)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(DS.Colors.ink3)
                        .frame(width: 22, height: 22).background(DS.Colors.panel).clipShape(Circle())
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 20)

            Rectangle().fill(DS.Colors.line).frame(height: 1)

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("APP").font(DS.Fonts.mono(10, weight: .medium)).foregroundStyle(DS.Colors.ink4).tracking(0.4)
                    appTextField
                }
                .zIndex(2)

                if isBrowser {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("URL PATTERN").font(DS.Fonts.mono(10, weight: .medium)).foregroundStyle(DS.Colors.ink4).tracking(0.4)
                        TextField("e.g. github.com, mail.google.com", text: $urlPattern)
                            .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced)).padding(10)
                            .background(DS.Colors.paper)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.line, lineWidth: 1))
                        Text("Leave empty to match any URL.").font(DS.Fonts.sans(11)).foregroundStyle(DS.Colors.ink3)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("TONO").font(DS.Fonts.mono(10, weight: .medium)).foregroundStyle(DS.Colors.ink4).tracking(0.4)
                    toneField
                }
                .zIndex(1)

                Button {
                    guard let toneId = selectedToneId else { return }
                    onSave(AppRule(
                        id: rule?.id ?? UUID(),
                        appName: appName.trimmingCharacters(in: .whitespacesAndNewlines),
                        urlPattern: isBrowser ? urlPattern.trimmingCharacters(in: .whitespacesAndNewlines) : "",
                        toneId: toneId,
                        isEnabled: rule?.isEnabled ?? true
                    ))
                } label: {
                    Text(rule == nil ? "Add rule" : "Save rule")
                        .font(DS.Fonts.sans(13, weight: .semibold))
                        .foregroundStyle(DS.Colors.paper)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(isValid ? DS.Colors.ink : DS.Colors.ink4)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain).disabled(!isValid)

                Spacer()
            }
            .padding(28)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var toneField: some View {
        HStack {
            Text(tones.first(where: { $0.id == selectedToneId })?.name ?? String(localized: "Select tone"))
                .font(DS.Fonts.sans(13))
                .foregroundStyle(selectedToneId == nil ? DS.Colors.ink3 : DS.Colors.ink)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 10))
                .foregroundStyle(DS.Colors.ink3)
                .rotationEffect(showToneDropdown ? .degrees(180) : .zero)
                .animation(.easeInOut(duration: 0.15), value: showToneDropdown)
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background(GeometryReader { _ in
            FieldWindowFrameReader(frame: $toneFieldWindowFrame)
        })
        .background(DS.Colors.paper)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm)
            .strokeBorder(showToneDropdown ? DS.Colors.ink3 : DS.Colors.line, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { showToneDropdown.toggle() }
        .overlay(alignment: .top) {
            if showToneDropdown && !tones.isEmpty {
                toneDropdownListView.offset(y: 40)
            }
        }
    }

    private var toneDropdownListView: some View {
        ToneDropdownList(
            tones: tones,
            highlightedIndex: $highlightedToneIndex,
            selectedToneId: $selectedToneId,
            isVisible: $showToneDropdown
        )
        .background(DS.Colors.paper)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 4)
    }

    private var appTextField: some View {
        HStack(spacing: 8) {
            if let icon = allAppEntries.first(where: { $0.name == appName })?.icon {
                Image(nsImage: icon).resizable().scaledToFit().frame(width: 18, height: 18)
            }
            TextField("App name", text: $appName)
                .textFieldStyle(.plain)
                .font(DS.Fonts.sans(13))
                .focused($appFieldFocused)
                .onTapGesture { showAppDropdown = true }
                .onChange(of: appFieldFocused) { focused in
                    if focused { showAppDropdown = true }
                }
        }
        .padding(10)
        .background(GeometryReader { geo in
            FieldWindowFrameReader(frame: $fieldWindowFrame)
                .onAppear { fieldHeight = geo.size.height }
        })
        .background(DS.Colors.paper)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .strokeBorder(appFieldFocused ? DS.Colors.ink3 : DS.Colors.line, lineWidth: 1)
        )
        .overlay(alignment: .top) {
            if showAppDropdown && !filteredApps.isEmpty {
                appDropdownListView
                    .offset(y: fieldHeight + 4)
            }
        }
    }

    private var appDropdownListView: some View {
        AppDropdownList(
            apps: filteredApps,
            disabledNames: existingAppNames.filter { $0.lowercased() != rule?.appName.lowercased() ?? "" },
            highlightedIndex: $highlightedIndex,
            selectedName: $appName,
            isVisible: $showAppDropdown
        )
        .background(DS.Colors.paper)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 4)
    }
}

private struct AppDropdownList: View {
    let apps: [(name: String, icon: NSImage?)]
    let disabledNames: Set<String>
    @Binding var highlightedIndex: Int?
    @Binding var selectedName: String
    @Binding var isVisible: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(apps.indices, id: \.self) { i in
                        let disabled = disabledNames.contains(apps[i].name)
                        DropdownAppRow(
                            app: apps[i],
                            isHighlighted: !disabled && highlightedIndex == i,
                            isDisabled: disabled
                        ) {
                            guard !disabled else { return }
                            selectedName = apps[i].name
                            isVisible = false
                            NSApp.keyWindow?.makeFirstResponder(nil)
                        }
                        .id(i)
                    }
                }
            }
            .frame(maxHeight: 220)
            .fixedSize(horizontal: false, vertical: true)
            .onChange(of: highlightedIndex) { _, idx in
                if let idx { withAnimation { proxy.scrollTo(idx, anchor: nil) } }
            }
        }
    }
}

private struct ToneDropdownList: View {
    let tones: [AppTone]
    @Binding var highlightedIndex: Int?
    @Binding var selectedToneId: UUID?
    @Binding var isVisible: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(tones.indices, id: \.self) { i in
                        ToneDropdownRow(
                            name: tones[i].name,
                            isSelected: selectedToneId == tones[i].id,
                            isHighlighted: highlightedIndex == i
                        ) {
                            selectedToneId = tones[i].id
                            isVisible = false
                        }
                        .id(i)
                    }
                }
            }
            .frame(maxHeight: 220)
            .fixedSize(horizontal: false, vertical: true)
            .onChange(of: highlightedIndex) { _, idx in
                if let idx { withAnimation { proxy.scrollTo(idx, anchor: nil) } }
            }
        }
    }
}

private struct ToneDropdownRow: View {
    let name: String
    let isSelected: Bool
    let isHighlighted: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Text(name).font(DS.Fonts.sans(13)).foregroundStyle(DS.Colors.ink)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Colors.moss)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 10)
            .background(isHighlighted || isHovered ? DS.Colors.panel : DS.Colors.paper)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct DropdownAppRow: View {
    let app: (name: String, icon: NSImage?)
    let isHighlighted: Bool
    let isDisabled: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                if let icon = app.icon {
                    Image(nsImage: icon).resizable().scaledToFit().frame(width: 18, height: 18)
                        .opacity(isDisabled ? 0.4 : 1)
                } else {
                    RoundedRectangle(cornerRadius: 4).fill(DS.Colors.panel).frame(width: 18, height: 18)
                }
                Text(app.name).font(DS.Fonts.sans(13))
                    .foregroundStyle(isDisabled ? DS.Colors.ink4 : DS.Colors.ink)
                Spacer()
                if isDisabled {
                    Text("Already added")
                        .font(DS.Fonts.mono(9))
                        .foregroundStyle(DS.Colors.ink4)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 10)
            .background(isHighlighted || (!isDisabled && isHovered) ? DS.Colors.panel : DS.Colors.paper)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { if !isDisabled { isHovered = $0 } }
        .disabled(isDisabled)
    }
}

struct RunningAppPickerPopover: View {
    let onSelect: (String) -> Void
    @State private var search = ""

    private struct AppEntry: Identifiable {
        let id: String
        let name: String
        let icon: NSImage?
    }

    private var allApps: [AppEntry] {
        var entries: [String: AppEntry] = [:]

        // Running apps (have better icons)
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular, let name = app.localizedName else { continue }
            entries[name] = AppEntry(id: name, name: name, icon: app.icon)
        }

        // Installed apps from /Applications and ~/Applications
        let dirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications")
        ]
        for dir in dirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
            ) else { continue }
            for url in contents where url.pathExtension == "app" {
                let name = (Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                if entries[name] == nil {
                    entries[name] = AppEntry(id: name, name: name, icon: NSWorkspace.shared.icon(forFile: url.path))
                }
            }
        }

        let filtered = search.isEmpty ? Array(entries.values) : entries.values.filter {
            $0.name.localizedCaseInsensitiveContains(search)
        }
        return filtered.sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(DS.Colors.ink3).font(.system(size: 12))
                TextField("Search app…", text: $search)
                    .textFieldStyle(.plain).font(DS.Fonts.sans(13))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(allApps) { app in
                        Button { onSelect(app.name) } label: {
                            HStack(spacing: 8) {
                                if let icon = app.icon {
                                    Image(nsImage: icon).resizable().scaledToFit().frame(width: 20, height: 20)
                                } else {
                                    RoundedRectangle(cornerRadius: 4).fill(DS.Colors.panel).frame(width: 20, height: 20)
                                }
                                Text(app.name).font(DS.Fonts.sans(13)).foregroundStyle(DS.Colors.ink)
                                Spacer()
                            }
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(AppPickerRowHover())
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 220, height: 320)
    }
}

struct AppPickerRowHover: View {
    @State private var hovered = false
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(hovered ? DS.Colors.bg : Color.clear)
            .onHover { hovered = $0 }
    }
}

// MARK: - App icon resolver

struct AppIconImage: View {
    let appName: String

    var body: some View {
        if let icon = resolveIcon() {
            Image(nsImage: icon).resizable().scaledToFit()
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: 22))
                .foregroundStyle(DS.Colors.ink3)
        }
    }

    private func resolveIcon() -> NSImage? {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }),
           let icon = app.icon { return icon }
        for path in [
            "/Applications/\(appName).app",
            "/System/Applications/\(appName).app",
            "/Applications/Utilities/\(appName).app"
        ] {
            if FileManager.default.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }
        return nil
    }
}

