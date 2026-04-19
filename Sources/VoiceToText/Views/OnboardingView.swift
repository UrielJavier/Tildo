import SwiftUI
import AVFoundation

// MARK: - Root

struct OnboardingView: View {
    let appState: AppState
    let onStartMonitoring: () -> Void
    let onStopMonitoring: () -> Void
    let onPauseHotkey: () -> Void
    let onResumeHotkey: () -> Void
    let onDownloadModel: (WhisperModel) -> Void
    let onComplete: () -> Void

    @State private var step: OnboardingStep = .accessibility

    private let steps: [OnboardingStep] = [.accessibility, .microphone, .model, .shortcut, .done]

    var body: some View {
        ZStack(alignment: .top) {
            DS.Colors.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                progressDots
                    .padding(.top, 20)

                // Step content
                stepContent
                    .padding(.top, 40)
                    .padding(.horizontal, 52)
                    .padding(.bottom, 28)
            }
        }
        .frame(width: 540, height: 480)
        .animation(DS.Motion.snappy, value: step)
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(steps, id: \.self) { s in
                let isActive = s == step
                RoundedRectangle(cornerRadius: 999)
                    .fill(DS.Colors.ink.opacity(isActive ? 1 : 0.15))
                    .frame(width: isActive ? 18 : 5, height: 5)
                    .animation(DS.Motion.snappy, value: step)
            }
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .accessibility:
            AccessibilityStep { step = .microphone }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)
        case .microphone:
            MicrophoneStep(
                appState: appState,
                onStartMonitoring: onStartMonitoring,
                onStopMonitoring: onStopMonitoring,
                onContinue: { step = .model }
            )
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id(step)
        case .model:
            ModelStep(
                appState: appState,
                onDownload: onDownloadModel,
                onContinue: { step = .shortcut }
            )
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id(step)
        case .shortcut:
            ShortcutStep(
                appState: appState,
                onPauseHotkey: onPauseHotkey,
                onResumeHotkey: onResumeHotkey,
                onContinue: { step = .done }
            )
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id(step)
        case .done:
            DoneStep(appState: appState, onComplete: onComplete)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)
        }
    }
}

private enum OnboardingStep: Hashable {
    case accessibility, microphone, model, shortcut, done
}

// MARK: - Icon tile

private struct IconTile: View {
    let icon: String
    var badge: String? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(DS.Colors.panel)
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(DS.Colors.line, lineWidth: 1))
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(DS.Colors.ink)
            }
            if let badge {
                ZStack {
                    Circle().fill(DS.Colors.ink).frame(width: 22, height: 22)
                    Image(systemName: badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DS.Colors.paper)
                }
                .offset(x: 4, y: 4)
            }
        }
    }
}

// MARK: - Ink button style (default CTA for onboarding)

private struct InkButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Fonts.sans(13, weight: .medium))
                .foregroundStyle(DS.Colors.paper)
                .padding(.vertical, 9)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm + 1)
                        .fill(isHovered ? DS.Colors.ink2 : DS.Colors.ink)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Step 1: Accessibility

private struct AccessibilityStep: View {
    let onGranted: () -> Void
    @State private var isGranted = TextSimulator.hasAccessibilityPermission

    var body: some View {
        VStack(spacing: 0) {
            IconTile(
                icon: isGranted ? "checkmark" : "rectangle.and.pencil.and.ellipsis",
                badge: isGranted ? nil : "lock.fill"
            )
            .contentTransition(.symbolEffect(.replace))

            Spacer().frame(height: 20)

            Text("Allow Tildo to paste into other apps")
                .font(DS.Fonts.sans(20, weight: .semibold))
                .foregroundStyle(DS.Colors.ink)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 8)

            Text("Tildo uses Accessibility to paste text at your cursor — it never reads your screen or sends data anywhere.")
                .font(DS.Fonts.sans(13))
                .foregroundStyle(DS.Colors.ink3)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Spacer().frame(height: 24)

            // Numbered steps card
            VStack(alignment: .leading, spacing: 8) {
                NumberedStep(n: 1, text: "Open System Settings")
                NumberedStep(n: 2, text: "Go to Privacy & Security → Accessibility")
                NumberedStep(n: 3, text: "Enable the toggle next to Tildo")
            }
            .padding(14)
            .background(DS.Colors.panel)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.line, lineWidth: 1))
            .frame(maxWidth: .infinity)

            Spacer().frame(height: 20)

            if isGranted {
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Circle().fill(DS.Colors.moss).frame(width: 7, height: 7)
                        Text("Access granted")
                            .font(DS.Fonts.sans(13, weight: .medium))
                            .foregroundStyle(DS.Colors.moss)
                    }
                    InkButton(title: "Continue →", action: onGranted)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                VStack(spacing: 10) {
                    InkButton(title: "Open System Settings") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        )
                    }
                    Text("Waiting for permission…")
                        .font(DS.Fonts.sans(11.5))
                        .foregroundStyle(DS.Colors.ink4)
                }
            }

            Spacer()
        }
        .animation(DS.Motion.snappy, value: isGranted)
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

private struct NumberedStep: View {
    let n: Int
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Text("\(n)")
                .font(DS.Fonts.mono(11, weight: .medium))
                .foregroundStyle(DS.Colors.ink4)
                .frame(width: 20)
            Text(text)
                .font(DS.Fonts.sans(12.5))
                .foregroundStyle(DS.Colors.ink2)
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
            IconTile(
                icon: micStatus == .authorized ? "mic.fill" : "mic.slash",
                badge: micStatus == .authorized ? nil : "lock.fill"
            )
            .contentTransition(.symbolEffect(.replace))

            Spacer().frame(height: 20)

            Text("Let Tildo hear you")
                .font(DS.Fonts.sans(20, weight: .semibold))
                .foregroundStyle(DS.Colors.ink)

            Spacer().frame(height: 8)

            Text("Tildo needs microphone access to transcribe your voice.")
                .font(DS.Fonts.sans(13))
                .foregroundStyle(DS.Colors.ink3)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 24)

            if micStatus == .authorized {
                VStack(spacing: 8) {
                    // VU meter
                    HStack(spacing: 3) {
                        ForEach(0..<15, id: \.self) { i in
                            let threshold = Float(i) / 15.0
                            let isLit = appState.audioLevel > threshold
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(isLit ? DS.Colors.moss : DS.Colors.line)
                                .frame(width: 3, height: 3 + CGFloat(i) * 1.2)
                                .animation(.easeOut(duration: 0.06), value: appState.audioLevel)
                        }
                    }
                    .frame(height: 24)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(DS.Colors.panel)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.line, lineWidth: 1))
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 6) {
                        Circle().fill(DS.Colors.moss).frame(width: 6, height: 6)
                        Text("Sounds good. Say a few words to test.")
                            .font(DS.Fonts.sans(11.5))
                            .foregroundStyle(DS.Colors.ink3)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))

                Spacer().frame(height: 20)

                InkButton(title: "Looks good →") {
                    onStopMonitoring()
                    onContinue()
                }

            } else if micStatus == .denied || micStatus == .restricted {
                VStack(spacing: 10) {
                    Text("Microphone access was denied")
                        .font(DS.Fonts.sans(13))
                        .foregroundStyle(DS.Colors.rec)
                    InkButton(title: "Open System Settings") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
                        )
                    }
                }
            } else {
                InkButton(title: "Allow Microphone Access") {
                    Task {
                        await AVCaptureDevice.requestAccess(for: .audio)
                        withAnimation { micStatus = AVCaptureDevice.authorizationStatus(for: .audio) }
                        if micStatus == .authorized { onStartMonitoring() }
                    }
                }
            }

            Spacer()
        }
        .animation(DS.Motion.snappy, value: micStatus)
        .onAppear { if micStatus == .authorized { onStartMonitoring() } }
        .onDisappear { onStopMonitoring() }
    }
}

// File-private tier struct so ModelRadioCard can access it
private struct OnboardingModelTier: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let size: String
    let model: WhisperModel
    let isRecommended: Bool
}

// MARK: - Step 3: Model

private struct ModelStep: View {
    let appState: AppState
    let onDownload: (WhisperModel) -> Void
    let onContinue: () -> Void

    private let tiers: [OnboardingModelTier] = [
        OnboardingModelTier(name: "Simple",   subtitle: "Fast and lightweight",    size: "~60 MB",  model: .baseQ5,         isRecommended: false),
        OnboardingModelTier(name: "Normal",   subtitle: "Speed + accuracy balance", size: "~190 MB", model: .smallQ5,        isRecommended: false),
        OnboardingModelTier(name: "Advanced", subtitle: "Maximum accuracy",         size: "~574 MB", model: .largeV3TurboQ5, isRecommended: true),
    ]

    @State private var selected: WhisperModel = .largeV3TurboQ5

    var body: some View {
        VStack(spacing: 0) {
            IconTile(icon: "waveform.badge.mic")

            Spacer().frame(height: 20)

            Text("Choose a transcription model")
                .font(DS.Fonts.sans(20, weight: .semibold))
                .foregroundStyle(DS.Colors.ink)

            Spacer().frame(height: 8)

            Text("Free, open-source models that run fully on your Mac.")
                .font(DS.Fonts.sans(13))
                .foregroundStyle(DS.Colors.ink3)

            Spacer().frame(height: 20)

            VStack(spacing: 7) {
                ForEach(tiers) { tier in
                    ModelRadioCard(
                        tier: tier,
                        isSelected: selected == tier.model,
                        isDownloading: appState.downloadingModel == tier.model,
                        downloadProgress: appState.downloadProgress
                    ) { selected = tier.model }
                }
            }

            Spacer().frame(height: 18)

            if appState.isDownloading {
                VStack(spacing: 6) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(DS.Colors.line).frame(height: 3)
                        RoundedRectangle(cornerRadius: 2).fill(DS.Colors.moss)
                            .frame(width: CGFloat(appState.downloadProgress) * 340, height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    Text("Downloading… \(Int(appState.downloadProgress * 100))%")
                        .font(DS.Fonts.mono(11.5))
                        .foregroundStyle(DS.Colors.ink3)
                }
                .transition(.opacity)
            } else if selected.isDownloaded || appState.isModelLoaded {
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Circle().fill(DS.Colors.moss).frame(width: 6, height: 6)
                        Text("Model ready")
                            .font(DS.Fonts.sans(13, weight: .medium))
                            .foregroundStyle(DS.Colors.moss)
                    }
                    InkButton(title: "Continue →", action: onContinue)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                VStack(spacing: 10) {
                    InkButton(title: "Download \(tiers.first(where: { $0.model == selected })?.name ?? selected.rawValue)") {
                        onDownload(selected)
                    }
                    Button("Skip — choose later in Settings") { onContinue() }
                        .buttonStyle(.plain)
                        .font(DS.Fonts.sans(11.5))
                        .foregroundStyle(DS.Colors.ink4)
                }
            }

            Spacer()
        }
        .animation(DS.Motion.snappy, value: appState.isDownloading)
        .animation(DS.Motion.snappy, value: selected.isDownloaded)
    }
}

private struct ModelRadioCard: View {
    let tier: OnboardingModelTier
    let isSelected: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Radio circle
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? DS.Colors.ink : DS.Colors.line, lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    if isSelected {
                        Circle().fill(DS.Colors.ink).frame(width: 8, height: 8)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(tier.name)
                            .font(DS.Fonts.sans(13, weight: .semibold))
                            .foregroundStyle(DS.Colors.ink)
                        if tier.isRecommended {
                            Text("RECOMMENDED")
                                .font(DS.Fonts.mono(9.5, weight: .medium))
                                .foregroundStyle(DS.Colors.mossInk)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(DS.Colors.mossSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    Text(tier.subtitle)
                        .font(DS.Fonts.sans(11.5))
                        .foregroundStyle(DS.Colors.ink3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(tier.size)
                        .font(DS.Fonts.mono(11))
                        .foregroundStyle(DS.Colors.ink2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(DS.Colors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .strokeBorder(isSelected ? DS.Colors.ink : DS.Colors.line, lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(DS.Motion.snappy, value: isSelected)
    }
}

// MARK: - Step 4: Shortcut

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
            IconTile(icon: "keyboard")

            Spacer().frame(height: 20)

            Text("Pick your shortcut")
                .font(DS.Fonts.sans(20, weight: .semibold))
                .foregroundStyle(DS.Colors.ink)

            Spacer().frame(height: 8)

            Text("Press the shortcut or tap each key below to confirm it's working.")
                .font(DS.Fonts.sans(13))
                .foregroundStyle(DS.Colors.ink3)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 28)

            // Keycap row
            VStack(spacing: 8) {
                Text("CURRENT SHORTCUT")
                    .font(DS.Fonts.mono(11, weight: .medium))
                    .foregroundStyle(DS.Colors.ink4)
                    .tracking(0.6)

                HStack(spacing: 8) {
                    ForEach(keyParts, id: \.self) { part in
                        let isActive = pressing || triggered || tappedKeys.contains(part)
                        Button {
                            withAnimation(DS.Motion.snappy) { _ = tappedKeys.insert(part) }
                        } label: {
                            OnboardingKeyCap(label: part, glow: isActive)
                        }
                        .buttonStyle(.plain)
                        .disabled(tappedKeys.contains(part))
                    }
                }
                .animation(DS.Motion.snappy, value: pressing)
            }
            .padding(16)
            .background(DS.Colors.panel)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.line, lineWidth: 1))
            .frame(maxWidth: .infinity)

            Spacer().frame(height: 20)

            if isComplete {
                VStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Circle().fill(DS.Colors.moss).frame(width: 6, height: 6)
                        Text("Shortcut is working!")
                            .font(DS.Fonts.sans(13, weight: .medium))
                            .foregroundStyle(DS.Colors.moss)
                    }
                    InkButton(title: "Continue →") { onResumeHotkey(); onContinue() }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
        }
        .animation(DS.Motion.snappy, value: isComplete)
        .onAppear { onPauseHotkey(); installMonitor() }
        .onDisappear { removeMonitor() }
    }

    private func installMonitor() {
        let targetKeyCode = appState.hotkeyKeyCode
        let targetMods = NSEvent.ModifierFlags(rawValue: appState.hotkeyModifiers)
            .intersection([.command, .shift, .option, .control, .function])
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            if event.type == .keyDown, event.keyCode == targetKeyCode {
                let mods = event.modifierFlags.intersection([.command, .shift, .option, .control, .function])
                if mods == targetMods {
                    withAnimation { pressing = true; triggered = true }
                    return nil
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

private struct OnboardingKeyCap: View {
    let label: String
    let glow: Bool

    var body: some View {
        Text(label)
            .font(DS.Fonts.mono(13, weight: .medium))
            .foregroundStyle(glow ? DS.Colors.mossInk : DS.Colors.ink)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(glow ? DS.Colors.mossSoft : DS.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .strokeBorder(glow ? DS.Colors.moss : DS.Colors.line, lineWidth: glow ? 1.5 : 1)
            )
            .shadow(
                color: glow ? DS.Colors.moss.opacity(0.13) : .black.opacity(0.05),
                radius: glow ? 4 : 1, y: 1
            )
            .scaleEffect(glow ? 1.05 : 1.0)
            .animation(DS.Motion.snappy, value: glow)
    }
}

// MARK: - Step 5: Done

private struct DoneStep: View {
    let appState: AppState
    let onComplete: () -> Void

    @State private var didBounce = false

    var body: some View {
        VStack(spacing: 0) {
            // Moss check circle (72pt, no tile border)
            ZStack {
                Circle()
                    .fill(DS.Colors.mossSoft)
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(DS.Colors.moss)
                    .symbolEffect(.bounce, value: didBounce)
            }

            Spacer().frame(height: 20)

            Text("You're all set.")
                .font(DS.Fonts.sans(26, weight: .semibold))
                .foregroundStyle(DS.Colors.ink)
                .tracking(-0.4)

            Spacer().frame(height: 10)

            HStack(spacing: 4) {
                Text("Hold")
                    .font(DS.Fonts.sans(13))
                    .foregroundStyle(DS.Colors.ink2)
                Text(appState.hotkeyLabel)
                    .font(DS.Fonts.mono(12, weight: .medium))
                    .foregroundStyle(DS.Colors.ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DS.Colors.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(DS.Colors.line, lineWidth: 1))
                Text("anywhere, speak, and release.")
                    .font(DS.Fonts.sans(13))
                    .foregroundStyle(DS.Colors.ink2)
            }

            Spacer().frame(height: 28)

            // Hint card
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DS.Colors.mossSoft)
                        .frame(width: 28, height: 28)
                    Text("∼")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Colors.moss)
                }
                Text("Look up there ↑ — the ∼ in your menu bar is Tildo.")
                    .font(DS.Fonts.sans(12.5))
                    .foregroundStyle(DS.Colors.ink2)
                Spacer()
            }
            .padding(14)
            .background(DS.Colors.panel)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.line, lineWidth: 1))
            .frame(maxWidth: .infinity)

            Spacer().frame(height: 24)

            // Moss CTA — the ONLY moss button in onboarding
            Button(action: onComplete) {
                Text("Start using Tildo")
                    .font(DS.Fonts.sans(13, weight: .medium))
                    .foregroundStyle(DS.Colors.paper)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 20)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.sm + 1).fill(DS.Colors.moss))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .onAppear { didBounce = true }
    }
}
