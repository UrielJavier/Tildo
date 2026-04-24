import SwiftUI

struct AtajosPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void
    var onHotkeyChange: (() -> Void)?
    var onCancelHotkeyChange: (() -> Void)?
    var onPauseHotkey: (() -> Void)?
    var onResumeHotkey: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Keyboard shortcuts")
                .font(DS.Fonts.display(22))
                .foregroundStyle(DS.Colors.ink)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 4)

            Text("Global: work even when Tildo is in the background.")
                .font(DS.Fonts.sans(13))
                .foregroundStyle(DS.Colors.ink3)
                .padding(.horizontal, 28)
                .padding(.bottom, 20)

            triggerModeSection
                .padding(.horizontal, 28)
                .padding(.bottom, 16)

            shortcutsCard
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
        }
    }

    // MARK: - Trigger mode

    private var triggerModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trigger mode")
                .font(DS.Fonts.sans(11, weight: .medium))
                .foregroundStyle(DS.Colors.ink3)
                .padding(.horizontal, 2)

            HStack(spacing: 10) {
                TriggerModeCard(
                    title: "Hold to talk",
                    description: "Records while the hotkey is held.",
                    isSelected: state.triggerMode == .holdToTalk
                ) { state.triggerMode = .holdToTalk; onSave() }

                TriggerModeCard(
                    title: "Tap to toggle",
                    description: "Tap once to start, again to stop.",
                    isSelected: state.triggerMode == .tapToToggle
                ) { state.triggerMode = .tapToToggle; onSave() }
            }
        }
    }

    private var shortcutsCard: some View {
        VStack(spacing: 0) {
            ShortcutRow(
                title: "Record",
                description: "Starts or stops transcription.",
                keyCode: $state.hotkeyKeyCode,
                modifiers: $state.hotkeyModifiers,
                onPauseHotkey: onPauseHotkey,
                onResumeHotkey: onResumeHotkey,
                onChange: { onHotkeyChange?(); onSave() }
            )

            Divider().padding(.leading, 16)

            ShortcutRow(
                title: "Cancel recording",
                description: "Stops and discards audio without transcribing.",
                keyCode: $state.cancelKeyCode,
                modifiers: $state.cancelModifiers,
                onChange: { onCancelHotkeyChange?(); onSave() }
            )
        }
        .background(DS.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(DS.Colors.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }
}

// MARK: - Shortcut row

private struct ShortcutRow: View {
    let title: String
    let description: String
    @Binding var keyCode: UInt16
    @Binding var modifiers: UInt
    var onPauseHotkey: (() -> Void)?
    var onResumeHotkey: (() -> Void)?
    var onChange: (() -> Void)?

    // Editing state
    @State private var isEditing = false
    @State private var liveKeyCode: UInt16? = nil      // non-modifier key being held
    @State private var liveModifiers: UInt = 0          // modifier keys currently held
    @State private var countdown = 0
    @State private var confirmed = false

    @State private var countdownTask: Task<Void, Never>?
    @State private var confirmTask: Task<Void, Never>?
    @State private var holder = MonitorHolder()

    private var isUnassigned: Bool { keyCode == UInt16.max }

    // Pending combo has a key (not just modifiers alone)
    private var hasPendingCombo: Bool { liveKeyCode != nil }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Fonts.sans(13, weight: .medium))
                    .foregroundStyle(DS.Colors.ink)
                Text(description)
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.ink3)
            }

            Spacer()

            if isEditing {
                editingControls
            } else {
                staticControls
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .animation(.easeInOut(duration: 0.15), value: isEditing)
    }

    // MARK: - Static

    private var staticControls: some View {
        HStack(spacing: 10) {
            if isUnassigned {
                Text("Unassigned")
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.ink4)
                    .italic()
            } else {
                KeyCapsDisplay(
                    components: hotkeyComponents(
                        keyCode: keyCode,
                        modifiers: NSEvent.ModifierFlags(rawValue: modifiers)
                    ),
                    confirmed: confirmed
                )
            }

            Button(isUnassigned ? "Assign" : "Change") { startEditing() }
                .buttonStyle(ShortcutChipButton())
        }
    }

    // MARK: - Editing

    private var editingControls: some View {
        HStack(spacing: 8) {
            // Live key caps (or prompt when nothing pressed yet)
            ZStack(alignment: .leading) {
                if liveModifiers != 0 || liveKeyCode != nil {
                    KeyCapsDisplay(
                        components: liveComponents,
                        confirmed: false,
                        isLive: true
                    )
                } else {
                    Text("Press the shortcut…")
                        .font(DS.Fonts.sans(12))
                        .foregroundStyle(DS.Colors.ink4)
                        .italic()
                        .frame(minWidth: 90, alignment: .leading)
                }
            }

            // Countdown badge (only when a full combo is detected)
            if hasPendingCombo && countdown > 0 {
                Text("\(countdown)")
                    .font(DS.Fonts.mono(13, weight: .bold))
                    .foregroundStyle(DS.Colors.moss)
                    .frame(width: 18, alignment: .center)
                    .transition(.scale.combined(with: .opacity))
            }

            Button("Cancel") { cancelEditing() }
                .buttonStyle(ShortcutChipButton())
        }
        .animation(.easeInOut(duration: 0.1), value: hasPendingCombo)
        .animation(.easeInOut(duration: 0.1), value: countdown)
    }

    private var liveComponents: [String] {
        let mods = NSEvent.ModifierFlags(rawValue: liveModifiers)
        var parts = [String]()
        if mods.contains(.function) { parts.append("fn") }
        if mods.contains(.control)  { parts.append("⌃") }
        if mods.contains(.option)   { parts.append("⌥") }
        if mods.contains(.shift)    { parts.append("⇧") }
        if mods.contains(.command)  { parts.append("⌘") }
        if let kc = liveKeyCode     { parts.append(keyCodeString(kc)) }
        return parts
    }

    // MARK: - Recording

    private func startEditing() {
        isEditing = true
        liveKeyCode = nil
        liveModifiers = 0
        countdown = 0
        confirmed = false
        countdownTask?.cancel()
        confirmTask?.cancel()
        onPauseHotkey?()

        let relevantMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control, .function]

        holder.install(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            guard self.isEditing else { return event }

            if event.type == .flagsChanged {
                let newMods = event.modifierFlags.intersection(relevantMask)
                let prevMods = NSEvent.ModifierFlags(rawValue: self.liveModifiers)
                self.liveModifiers = newMods.rawValue

                if newMods.isEmpty {
                    self.liveKeyCode = nil
                    self.cancelCountdown()
                } else if prevMods.isSubset(of: newMods) {
                    // New modifier added — restart countdown if combo is complete
                    if self.liveKeyCode != nil { self.startCountdown() }
                } else {
                    // Modifier released — cancel countdown
                    self.cancelCountdown()
                }
                return event
            }

            if event.type == .keyUp {
                if event.keyCode == self.liveKeyCode {
                    self.liveKeyCode = nil
                    self.cancelCountdown()
                }
                return nil
            }

            // keyDown — Escape with no extra modifiers = cancel recording
            if event.keyCode == 53,
               event.modifierFlags.intersection(relevantMask).isEmpty {
                self.cancelEditing()
                return nil
            }

            // Key repeats don't change the combo — ignore to avoid resetting countdown
            if event.isARepeat { return nil }

            let mods = event.modifierFlags.intersection(relevantMask)
            self.liveKeyCode = event.keyCode
            self.liveModifiers = mods.rawValue
            self.startCountdown()
            return nil
        }
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdown = 3
        countdownTask = Task { @MainActor in
            for i in stride(from: 3, through: 1, by: -1) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                countdown = i - 1
            }
            guard !Task.isCancelled else { return }
            commit()
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdown = 0
    }

    private func commit() {
        guard let pk = liveKeyCode else { return }
        holder.remove()
        keyCode = pk
        modifiers = liveModifiers
        isEditing = false
        countdown = 0
        liveKeyCode = nil
        liveModifiers = 0
        confirmed = true
        onResumeHotkey?()
        onChange?()
        confirmTask?.cancel()
        confirmTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            confirmed = false
        }
    }

    private func cancelEditing() {
        countdownTask?.cancel()
        holder.remove()
        isEditing = false
        liveKeyCode = nil
        liveModifiers = 0
        countdown = 0
        onResumeHotkey?()
    }
}

// MARK: - Key caps display

private struct KeyCapsDisplay: View {
    let components: [String]
    let confirmed: Bool
    var isLive: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(components, id: \.self) { symbol in
                KeyCapCell(symbol: symbol, isLive: isLive)
            }
            if confirmed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DS.Colors.moss)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.1), value: components)
    }
}

private struct KeyCapCell: View {
    let symbol: String
    var isLive: Bool = false

    private var isWide: Bool { symbol.count > 1 }

    var body: some View {
        Text(symbol)
            .font(isWide ? DS.Fonts.sans(10, weight: .medium) : DS.Fonts.mono(13, weight: .medium))
            .foregroundStyle(isLive ? DS.Colors.mossInk : DS.Colors.ink2)
            .frame(minWidth: isWide ? 32 : 26, minHeight: 26)
            .padding(.horizontal, isWide ? 6 : 0)
            .background(isLive ? DS.Colors.mossSoft : DS.Colors.paper)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        isLive ? DS.Colors.moss.opacity(0.5) : DS.Colors.line,
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .shadow(color: .black.opacity(isLive ? 0 : 0.06), radius: 0, x: 0, y: 1)
    }
}

// MARK: - Trigger mode card

private struct TriggerModeCard: View {
    let title: String
    let description: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DS.Fonts.sans(13, weight: .medium))
                    .foregroundStyle(isSelected ? DS.Colors.rec : DS.Colors.ink)
                Text(description)
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(isSelected ? DS.Colors.rec.opacity(0.06) : DS.Colors.card)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(isSelected ? DS.Colors.rec : DS.Colors.line,
                                  lineWidth: isSelected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Button style

private struct ShortcutChipButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Fonts.sans(12))
            .foregroundStyle(DS.Colors.ink3)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(DS.Colors.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(DS.Colors.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
