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

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 13 { return "Buenos días" }
        if hour < 20 { return "Buenas tardes" }
        return "Buenas noches"
    }

    private var dayTimeLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEEE"
        let weekday = formatter.string(from: Date()).uppercased()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        return "\(weekday) · \(timeFormatter.string(from: Date()))"
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
                            Text("Escuchando · \(state.hotkeyLabel)")
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
                Text("\(greeting), \(firstName)")
                    .font(DS.Fonts.display(28))
                    .foregroundStyle(DS.Colors.ink)
                    .tracking(-0.4)
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
                            Text(" palabras")
                                .font(DS.Fonts.sans(13))
                                .foregroundStyle(DS.Colors.ink3)
                        }

                        Text("sobre tu media")
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
                    StatCard(label: "RACHA", value: "\(streak)", unit: "días", sub: "consecutivos")
                    StatCard(
                        label: "TIEMPO AHORRADO",
                        value: formatTimeSaved(timeSavedMinutes),
                        unit: "",
                        sub: "esta semana"
                    )
                    StatCard(
                        label: "IDIOMA",
                        value: state.language.label,
                        unit: "",
                        sub: state.language == .auto ? "+ inglés auto" : nil
                    )
                    StatCard(
                        label: "MODELO",
                        value: state.model.shortLabel,
                        unit: "",
                        sub: state.isLoadingModel ? "cargando…" : state.isModelLoaded ? "en memoria" : "sin cargar"
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // Historial reciente
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Historial reciente")
                            .font(DS.Fonts.sans(13, weight: .semibold))
                            .foregroundStyle(DS.Colors.ink)

                        Spacer()

                        Button("ver todo →") {
                            onOpenCuaderno?()
                        }
                        .buttonStyle(.plain)
                        .font(DS.Fonts.sans(12))
                        .foregroundStyle(DS.Colors.mossInk)
                    }
                    .padding(.bottom, 8)

                    let recent = Array(state.history.prefix(3))
                    if recent.isEmpty {
                        Text("Empieza a dictar para ver tu historial")
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
            ClaudeCodeFooterBanner()
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
        if secs < 60 { return "ahora" }
        if secs < 3600 { return "hace \(secs / 60) min" }
        if secs < 86400 { return "hace \(secs / 3600) h" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
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
            PermissionDot(label: "Accesibilidad", granted: hasAccessibility) {
                openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            }
            PermissionDot(label: "Micrófono", granted: hasMicrophone) {
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
                Button("Abrir") { action() }
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
                Text("ÚLTIMA TRANSCRIPCIÓN · \(minutesAgo(from: entry.date))")
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
                Text("Empieza a dictar para ver tu última transcripción")
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
        if mins < 1 { return "AHORA" }
        return "HACE \(mins) MIN"
    }
}

// MARK: - Claude Code Footer Banner

private struct ClaudeCodeFooterBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11))
                .foregroundStyle(DS.Colors.accent)

            Text("Claude Code activo como motor de IA")
                .font(DS.Fonts.sans(11, weight: .semibold))
                .foregroundStyle(DS.Colors.ink2)

            Text("·")
                .foregroundStyle(DS.Colors.ink4)
                .font(DS.Fonts.sans(11))

            Text("Si macOS solicita permisos del sistema (Fotos, Música…), puedes rechazarlos.")
                .font(DS.Fonts.sans(11))
                .foregroundStyle(DS.Colors.ink3)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
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
