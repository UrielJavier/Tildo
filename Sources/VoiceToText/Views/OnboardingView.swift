import SwiftUI
import AVFoundation

// MARK: - Root

struct OnboardingView: View {
    let appState: AppState
    let onStartMonitoring: () -> Void
    let onStopMonitoring: () -> Void
    let onPauseHotkey: () -> Void
    let onResumeHotkey: () -> Void
    let onComplete: () -> Void

    @State private var step: OnboardingStep = .accessibility

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).ignoresSafeArea()

            stepContent
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)
        }
        .animation(.spring(duration: 0.4), value: step)
        .frame(width: 540, height: 460)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .accessibility:
            AccessibilityStep { step = .microphone }
        case .microphone:
            MicrophoneStep(
                appState: appState,
                onStartMonitoring: onStartMonitoring,
                onStopMonitoring: onStopMonitoring,
                onContinue: { step = .shortcut }
            )
        case .shortcut:
            ShortcutStep(
                appState: appState,
                onPauseHotkey: onPauseHotkey,
                onResumeHotkey: onResumeHotkey,
                onContinue: { step = .done }
            )
        case .done:
            DoneStep(appState: appState, onComplete: onComplete)
        }
    }
}

private enum OnboardingStep: Hashable {
    case accessibility, microphone, shortcut, done
}

// MARK: - Step 1: Accessibility

private struct AccessibilityStep: View {
    let onGranted: () -> Void

    @State private var isGranted = TextSimulator.hasAccessibilityPermission

    var body: some View {
        OnboardingCard(
            icon: isGranted ? "checkmark.circle.fill" : "rectangle.and.pencil.and.ellipsis",
            iconColor: isGranted ? .green : .primary,
            badge: isGranted ? nil : "lock.fill",
            title: "Allow EchoWrite to type for you",
            description: "EchoWrite needs Accessibility access to insert your transcribed words directly into any app.",
            isGranted: isGranted,
            grantedLabel: "Access granted",
            actionLabel: "Open System Settings",
            onAction: {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                )
            },
            onContinue: onGranted
        )
        .task {
            while !isGranted {
                try? await Task.sleep(nanoseconds: 600_000_000)
                let granted = TextSimulator.hasAccessibilityPermission
                if granted {
                    withAnimation { isGranted = true }
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    onGranted()
                }
            }
        }
    }
}

// MARK: - Step 2: Microphone

private struct MicrophoneStep: View {
    let appState: AppState
    let onStartMonitoring: () -> Void
    let onStopMonitoring: () -> Void
    let onContinue: () -> Void

    @State private var micStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(micStatus == .authorized ? Color.accentColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 80, height: 80)
                    .background(
                        Circle().fill(micStatus == .authorized
                            ? Color.accentColor.opacity(0.1)
                            : Color.secondary.opacity(0.08))
                    )
                if micStatus != .authorized {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Circle().fill(Color.secondary))
                        .offset(x: 6, y: 6)
                }
            }

            Spacer().frame(height: 24)
            Text("Allow EchoWrite to hear you")
                .font(.title2.weight(.semibold))
            Spacer().frame(height: 10)
            Text("EchoWrite needs microphone access to transcribe your voice.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 340)
            Spacer().frame(height: 32)

            if micStatus == .authorized {
                VStack(spacing: 10) {
                    AudioLevelMeter(level: appState.audioLevel, threshold: appState.liveSilenceThreshold)
                        .frame(width: 320, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("Speak and make sure you see movement")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                Spacer().frame(height: 28)
                Button("Looks good →") { onStopMonitoring(); onContinue() }
                    .buttonStyle(.borderedProminent).controlSize(.large)

            } else if micStatus == .denied || micStatus == .restricted {
                VStack(spacing: 10) {
                    Label("Microphone access was denied", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout).foregroundStyle(.orange)
                    Button("Open System Settings") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
                        )
                    }.buttonStyle(.bordered)
                }
            } else {
                Button("Allow Microphone Access") {
                    Task {
                        await AVCaptureDevice.requestAccess(for: .audio)
                        withAnimation { micStatus = AVCaptureDevice.authorizationStatus(for: .audio) }
                        if micStatus == .authorized { onStartMonitoring() }
                    }
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
            }

            Spacer()
        }
        .padding(.horizontal, 48)
        .onAppear { if micStatus == .authorized { onStartMonitoring() } }
        .onDisappear { onStopMonitoring() }
        .animation(.spring(duration: 0.35), value: micStatus)
    }
}

// MARK: - Step 3: Shortcut

private struct ShortcutStep: View {
    let appState: AppState
    let onPauseHotkey: () -> Void
    let onResumeHotkey: () -> Void
    let onContinue: () -> Void

    @State private var triggered = false
    @State private var pressing = false
    @State private var tappedKeys: Set<String> = []
    @State private var eventMonitor: Any?

    private var isComplete: Bool { triggered || tappedKeys.count >= keyParts.count }

    private var keyParts: [String] {
        let mods = NSEvent.ModifierFlags(rawValue: appState.hotkeyModifiers)
        var parts: [String] = []
        if mods.contains(.control)  { parts.append("⌃") }
        if mods.contains(.option)   { parts.append("⌥") }
        if mods.contains(.shift)    { parts.append("⇧") }
        if mods.contains(.command)  { parts.append("⌘") }
        if mods.contains(.function) { parts.append("fn") }
        parts.append(keyLabel(for: appState.hotkeyKeyCode))
        return parts
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: isComplete ? "checkmark.circle.fill" : "keyboard")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(isComplete ? .green : .primary)
                .frame(width: 80, height: 80)
                .background(Circle().fill(isComplete ? Color.green.opacity(0.1) : Color.secondary.opacity(0.08)))
                .contentTransition(.symbolEffect(.replace))

            Spacer().frame(height: 24)

            Text("Try your shortcut")
                .font(.title2.weight(.semibold))

            Spacer().frame(height: 10)

            Text("Press the shortcut or tap each key below.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 32)

            // Key caps — clickable
            HStack(spacing: 8) {
                ForEach(keyParts, id: \.self) { part in
                    let isActive = pressing || triggered || tappedKeys.contains(part)
                    Button {
                        withAnimation(.spring(duration: 0.2)) { _ = tappedKeys.insert(part) }
                    } label: {
                        KeyCap(label: part, isActive: isActive)
                    }
                    .buttonStyle(.plain)
                    .disabled(tappedKeys.contains(part))
                }
            }
            .animation(.spring(duration: 0.15), value: pressing)

            Spacer().frame(height: 28)

            if isComplete {
                VStack(spacing: 16) {
                    Label("Shortcut is working!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.callout.weight(.medium))
                    Button("Continue →") { onResumeHotkey(); onContinue() }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
        }
        .padding(.horizontal, 48)
        .animation(.spring(duration: 0.3), value: isComplete)
        .onAppear {
            onPauseHotkey()
            installMonitor()
        }
        .onDisappear {
            removeMonitor()
        }
    }

    private func installMonitor() {
        let targetKeyCode = appState.hotkeyKeyCode
        let targetMods = NSEvent.ModifierFlags(rawValue: appState.hotkeyModifiers)
            .intersection([.command, .shift, .option, .control, .function])

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [self] event in
            if event.type == .keyDown, event.keyCode == targetKeyCode {
                let mods = event.modifierFlags.intersection([.command, .shift, .option, .control, .function])
                if mods == targetMods {
                    withAnimation { pressing = true; triggered = true }
                    return nil  // consume — don't pass to the system
                }
            }
            if event.type == .keyUp, event.keyCode == targetKeyCode {
                withAnimation { pressing = false }
            }
            return event
        }
    }

    private func removeMonitor() {
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
    }

    private func keyLabel(for keyCode: UInt16) -> String {
        let map: [UInt16: String] = [
            0:"A", 1:"S", 2:"D", 3:"F", 4:"H", 5:"G", 6:"Z", 7:"X",
            8:"C", 9:"V", 11:"B", 12:"Q", 13:"W", 14:"E", 15:"R",
            16:"Y", 17:"T", 18:"1", 19:"2", 20:"3", 21:"4", 22:"6",
            23:"5", 24:"=", 25:"9", 26:"7", 27:"-", 28:"8", 29:"0",
            30:"]", 31:"O", 32:"U", 33:"[", 34:"I", 35:"P", 36:"↩",
            37:"L", 38:"J", 39:"'", 40:"K", 41:";", 42:"\\", 43:",",
            44:"/", 45:"N", 46:"M", 47:".", 48:"⇥", 49:"Space",
            51:"⌫", 53:"⎋", 96:"F5", 97:"F6", 98:"F7", 99:"F3",
            100:"F8", 101:"F9", 103:"F11", 109:"F10", 111:"F12",
            122:"F1", 120:"F2", 118:"F4",
        ]
        return map[keyCode] ?? "?"
    }
}

private struct KeyCap: View {
    let label: String
    let isActive: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(isActive ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.12))
                    .shadow(color: isActive ? Color.accentColor.opacity(0.35) : .clear, radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isActive ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.25), lineWidth: 1)
            )
            .scaleEffect(isActive ? 1.06 : 1.0)
    }
}

// MARK: - Step 4: Done

private struct DoneStep: View {
    let appState: AppState
    let onComplete: () -> Void

    @State private var didBounce = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: didBounce)

            Spacer().frame(height: 24)
            Text("You're all set!")
                .font(.title.weight(.bold))
            Spacer().frame(height: 10)
            (Text("Press ") + Text(appState.hotkeyLabel).bold() + Text(" to start recording anywhere."))
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 32)

            Button("Start using EchoWrite") { onComplete() }
                .buttonStyle(.borderedProminent).controlSize(.large)

            Spacer()
        }
        .padding(.horizontal, 48)
        .onAppear { didBounce = true }
    }
}

// MARK: - Shared card layout

private struct OnboardingCard: View {
    let icon: String
    let iconColor: Color
    let badge: String?
    let title: String
    let description: String
    let isGranted: Bool
    let grantedLabel: String
    let actionLabel: String
    let onAction: () -> Void
    var onContinue: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack(alignment: .bottomTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(iconColor)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 80, height: 80)
                    .background(
                        Circle().fill(isGranted ? Color.green.opacity(0.1) : Color.secondary.opacity(0.08))
                    )
                if let badge {
                    Image(systemName: badge)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Circle().fill(Color.secondary))
                        .offset(x: 6, y: 6)
                }
            }

            Spacer().frame(height: 24)
            Text(title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Spacer().frame(height: 10)
            Text(description)
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 360)
            Spacer().frame(height: 32)

            if isGranted {
                VStack(spacing: 16) {
                    Label(grantedLabel, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.callout.weight(.medium))
                    if let onContinue {
                        Button("Continue →") { onContinue() }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                Button(actionLabel) { onAction() }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }

            Spacer()
        }
        .padding(.horizontal, 48)
        .animation(.spring(duration: 0.3), value: isGranted)
    }
}
