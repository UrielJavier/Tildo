import SwiftUI
import AppKit
import AVFoundation

struct InicioView: View {
    @Bindable var state: AppState
    var onOpenCuaderno: (() -> Void)?

    private var wordsToday: Int {
        state.history
            .filter { Calendar.current.isDateInToday($0.date) }
            .compactMap { $0.wordCount }
            .reduce(0, +)
    }

    private var lastEntry: TranscriptionEntry? {
        state.history.first
    }

    private var streak: Int {
        var count = 0
        var day = Calendar.current.startOfDay(for: Date())
        for _ in 0..<365 {
            let next = Calendar.current.date(byAdding: .day, value: 1, to: day)!
            let hasEntry = state.history.contains { entry in
                entry.date >= day && entry.date < next
            }
            if hasEntry {
                count += 1
                day = Calendar.current.date(byAdding: .day, value: -1, to: day)!
            } else {
                break
            }
        }
        return count
    }

    private var totalWords: Int {
        state.history.compactMap { $0.wordCount }.reduce(0, +)
    }

    private var timeSavedMinutes: Int {
        totalWords / 40
    }

    private var wordsPast7Days: [Int] {
        let cal = Calendar.current
        return (0..<7).reversed().map { daysAgo in
            guard let day = cal.date(byAdding: .day, value: -daysAgo, to: Date()) else { return 0 }
            let start = cal.startOfDay(for: day)
            let end = cal.date(byAdding: .day, value: 1, to: start)!
            return state.history
                .filter { $0.date >= start && $0.date < end }
                .compactMap { $0.wordCount }
                .reduce(0, +)
        }
    }

    private var firstName: String {
        NSFullUserName().components(separatedBy: " ").first ?? ""
    }

    private var triggerVerb: String {
        state.triggerMode == .holdToTalk ? "hold" : "press"
    }

    private var hotkeyParts: [String] {
        hotkeyComponents(keyCode: state.hotkeyKeyCode,
                         modifiers: NSEvent.ModifierFlags(rawValue: state.hotkeyModifiers))
    }

    private var claudeCodeActive: Bool {
        state.llmPostProcessEnabled && !state.llmProvider.requiresAPIKey
    }

    var body: some View {
        VStack(spacing: 0) {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Top bar
                HStack {
                    Spacer()

                    if state.isRecording {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(DS.Colors.rec)
                                .frame(width: 6, height: 6)
                            Text(String(format: String(localized: "Listening · %@"), state.hotkeyLabel))
                                .font(DS.Fonts.sans(11.5))
                                .foregroundStyle(DS.Colors.ink2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(DS.Colors.rec.opacity(0.08))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // H1 greeting
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hey, \(firstName)")
                        .font(DS.Fonts.display(28))
                        .foregroundStyle(DS.Colors.ink)
                        .tracking(-0.4)

                    HStack(spacing: 5) {
                        Text("Don't type, just \(triggerVerb)")
                            .font(DS.Fonts.sans(14))
                            .foregroundStyle(DS.Colors.ink3)

                        ForEach(hotkeyParts, id: \.self) { part in
                            HomeKeyCap(symbol: part)
                        }

                        Text(".")
                            .font(DS.Fonts.sans(14))
                            .foregroundStyle(DS.Colors.ink3)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                // Permissions banner (only when something is missing)
                PermissionsBanner()
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                // Two-column card row
                HStack(alignment: .top, spacing: 12) {
                    // HOY card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HOY")
                            .font(DS.Fonts.mono(10, weight: .medium))
                            .foregroundStyle(DS.Colors.ink4)
                            .tracking(0.4)

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(wordsToday)")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(DS.Colors.ink)
                            Text(" \(String(localized: "words"))")
                                .font(DS.Fonts.sans(13))
                                .foregroundStyle(DS.Colors.ink3)
                        }

                        Text("above your average")
                            .font(DS.Fonts.sans(11))
                            .foregroundStyle(DS.Colors.ink4)

                        // Sparkline
                        SparklineView(values: wordsPast7Days)
                            .frame(height: 28)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Colors.card)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .strokeBorder(DS.Colors.line, lineWidth: 1)
                    )

                    // ÚLTIMA TRANSCRIPCIÓN card
                    LastTranscriptionCard(entry: lastEntry)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // Four stat cards
                HStack(spacing: 10) {
                    StatCard(label: String(localized: "STREAK"), value: "\(streak)", unit: String(localized: "days"), sub: String(localized: "in a row"))
                    StatCard(
                        label: String(localized: "TIME SAVED"),
                        value: formatTimeSaved(timeSavedMinutes),
                        unit: "",
                        sub: String(localized: "this week")
                    )
                    StatCard(
                        label: String(localized: "LANGUAGE"),
                        value: state.language.label,
                        unit: "",
                        sub: state.language == .auto ? "+ auto" : nil
                    )
                    StatCard(
                        label: String(localized: "MODEL"),
                        value: state.model.shortLabel,
                        unit: "",
                        sub: state.isLoadingModel ? String(localized: "loading…") : state.isModelLoaded ? String(localized: "loaded") : String(localized: "not loaded")
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // Historial reciente
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Recent history")
                            .font(DS.Fonts.sans(13, weight: .semibold))
                            .foregroundStyle(DS.Colors.ink)

                        Spacer()

                        Button(String(localized: "see all →")) {
                            onOpenCuaderno?()
                        }
                        .buttonStyle(.plain)
                        .font(DS.Fonts.sans(12))
                        .foregroundStyle(DS.Colors.mossInk)
                    }
                    .padding(.bottom, 8)

                    let recent = Array(state.history.prefix(3))
                    if recent.isEmpty {
                        Text("Start dictating to see your history")
                            .font(DS.Fonts.sans(12))
                            .foregroundStyle(DS.Colors.ink4)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(Array(recent.enumerated()), id: \.element.id) { idx, entry in
                            if idx > 0 {
                                Rectangle()
                                    .fill(DS.Colors.line)
                                    .frame(height: 1)
                            }
                            HStack {
                                Text(entry.text)
                                    .font(DS.Fonts.sans(13))
                                    .foregroundStyle(DS.Colors.ink)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(relativeTime(from: entry.date))
                                    .font(DS.Fonts.sans(11))
                                    .foregroundStyle(DS.Colors.ink3)
                            }
                            .frame(height: 42)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
        .background(DS.Colors.paper)

        if claudeCodeActive {
            ClaudeCodeFooterBanner {
                state.llmPostProcessEnabled = false
            }
        }
        } // VStack
    }

    private func formatTimeSaved(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return "\(h)h \(m)m"
        }
        return "\(minutes)m"
    }

    private func relativeTime(from date: Date) -> String {
        let secs = Int(-date.timeIntervalSinceNow)
        if secs < 60 { return String(localized: "just now") }
        if secs < 3600 { return String(format: String(localized: "%d min ago"), secs / 60) }
        if secs < 86400 { return String(format: String(localized: "%d h ago"), secs / 3600) }
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }
}

// MARK: - Permissions Banner

private struct PermissionsBanner: View {
    @State private var hasAccessibility = AXIsProcessTrusted()
    @State private var hasMicrophone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

    private var allGranted: Bool { hasAccessibility && hasMicrophone }

    var body: some View {
        HStack(spacing: 12) {
            PermissionDot(label: String(localized: "Accessibility"), granted: hasAccessibility) {
                openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            }
            PermissionDot(label: String(localized: "Microphone"), granted: hasMicrophone) {
                openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DS.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(DS.Colors.line, lineWidth: 1)
        )
        .onAppear { refresh() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            if !allGranted { refresh() }
        }
    }

    private func refresh() {
        hasAccessibility = AXIsProcessTrusted()
        hasMicrophone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func openSettings(_ urlString: String) {
        if let url = URL(string: urlString) { NSWorkspace.shared.open(url) }
    }
}

private struct HomeKeyCap: View {
    let symbol: String
    private var isWide: Bool { symbol.count > 1 }

    var body: some View {
        Text(symbol)
            .font(isWide ? DS.Fonts.sans(10, weight: .medium) : DS.Fonts.mono(12, weight: .medium))
            .foregroundStyle(DS.Colors.ink2)
            .frame(minWidth: isWide ? 34 : 24, minHeight: 22)
            .padding(.horizontal, isWide ? 5 : 0)
            .background(DS.Colors.paper)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(DS.Colors.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.06), radius: 0, x: 0, y: 1)
    }
}

private struct PermissionDot: View {
    let label: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(granted ? DS.Colors.moss : DS.Colors.rec)
                .frame(width: 6, height: 6)
            Text(label)
                .font(DS.Fonts.sans(12))
                .foregroundStyle(DS.Colors.ink2)
            if !granted {
                Button(String(localized: "Open")) { action() }
                    .buttonStyle(.plain)
                    .font(DS.Fonts.sans(11, weight: .semibold))
                    .foregroundStyle(DS.Colors.mossInk)
            }
        }
    }
}

// MARK: - Sparkline

private struct SparklineView: View {
    let values: [Int]

    var body: some View {
        let maxVal = values.max() ?? 1
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<values.count, id: \.self) { i in
                    let v = values[i]
                    let ratio = maxVal > 0 ? CGFloat(v) / CGFloat(maxVal) : 0
                    let barH = max(3, ratio * geo.size.height)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DS.Colors.moss.opacity(v > 0 ? 0.6 : 0.15))
                        .frame(width: max(4, (geo.size.width - CGFloat(values.count - 1) * 3) / CGFloat(values.count)),
                               height: barH)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

// MARK: - Last Transcription Card

private struct LastTranscriptionCard: View {
    let entry: TranscriptionEntry?

    var body: some View {
        if let entry {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: String(localized: "LAST TRANSCRIPTION · %@"), minutesAgo(from: entry.date)))
                    .font(DS.Fonts.mono(9, weight: .regular))
                    .foregroundStyle(DS.Colors.paper.opacity(0.5))
                    .tracking(0.3)
                    .lineLimit(1)

                Text("\u{201C}\(entry.text)\u{201D}")
                    .font(DS.Fonts.sans(13))
                    .foregroundStyle(DS.Colors.paper)
                    .lineLimit(3)
                    .italic()

                Spacer()

                HStack(spacing: 0) {
                    // Simple static waveform
                    HStack(spacing: 2) {
                        ForEach([0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.5, 0.3], id: \.self) { h in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(DS.Colors.paper.opacity(0.4))
                                .frame(width: 3, height: 12 * h)
                        }
                    }

                    Spacer()

                    if let app = entry.mode, !app.isEmpty {
                        Text("→ \(app)")
                            .font(DS.Fonts.mono(10))
                            .foregroundStyle(DS.Colors.paper.opacity(0.6))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.ink)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        } else {
            VStack {
                Spacer()
                Text("Start dictating to see your last transcription")
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.ink4)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(DS.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(DS.Colors.line, lineWidth: 1)
            )
        }
    }

    private func minutesAgo(from date: Date) -> String {
        let mins = Int(-date.timeIntervalSinceNow) / 60
        if mins < 1 { return String(localized: "JUST NOW") }
        return String(format: String(localized: "%d MIN AGO"), mins)
    }
}

// MARK: - Claude Code Footer Banner

private struct ClaudeCodeFooterBanner: View {
    let onDisable: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11))
                .foregroundStyle(DS.Colors.accent)

            Text("Claude Code active")
                .font(DS.Fonts.sans(11, weight: .semibold))
                .foregroundStyle(DS.Colors.ink2)

            Text("·")
                .foregroundStyle(DS.Colors.ink4)
                .font(DS.Fonts.sans(11))

            Text("If macOS requests system permissions, you can decline.")
                .font(DS.Fonts.sans(11))
                .foregroundStyle(DS.Colors.ink3)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Button("Disable") {
                onDisable()
            }
            .buttonStyle(.plain)
            .font(DS.Fonts.sans(11, weight: .medium))
            .foregroundStyle(DS.Colors.ink3)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(DS.Colors.accent.opacity(0.12))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .background(DS.Colors.accentSoft)
        .overlay(
            Rectangle()
                .fill(DS.Colors.accent.opacity(0.15))
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let label: String
    let value: String
    let unit: String
    let sub: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(DS.Fonts.mono(9, weight: .regular))
                .foregroundStyle(DS.Colors.ink4)
                .tracking(0.3)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DS.Colors.ink)
                if !unit.isEmpty {
                    Text(unit)
                        .font(DS.Fonts.sans(13))
                        .foregroundStyle(DS.Colors.ink3)
                }
            }

            if let sub, !sub.isEmpty {
                Text(sub)
                    .font(DS.Fonts.sans(11))
                    .foregroundStyle(DS.Colors.ink4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(DS.Colors.line, lineWidth: 1)
        )
    }
}
