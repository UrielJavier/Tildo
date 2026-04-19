import SwiftUI

struct FloatingRecordingView: View {
    @State var appState: AppState

    // §4.5 — background driven by AppTheme, not system colorScheme
    private var pillBg: Color {
        appState.appTheme == .light ? DS.Colors.ink : DS.Colors.panelDark
    }

    private var timerText: String {
        let m = appState.recordingSeconds / 60
        let s = appState.recordingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var modelShortName: String { appState.model.rawValue }

    private var activeToneName: String {
        guard let id = appState.defaultToneId else { return "Tone" }
        return appState.tones.first(where: { $0.id == id })?.name ?? "Tone"
    }

    var body: some View {
        Group {
            switch appState.status {
            case .idle, .error:
                idlePill
            case .recording:
                recordingPill
            case .transcribing:
                processingPill(
                    spinnerColor: DS.Colors.moss,
                    label: "Transcribing…",
                    chipText: modelShortName
                )
            case .processing:
                processingPill(
                    spinnerColor: DS.Colors.paper.opacity(0.45),
                    label: "Polishing with \(activeToneName)…",
                    chipText: activeToneName
                )
            }
        }
        .animation(DS.Motion.snappy, value: appState.status)
    }

    // MARK: - Idle / armed (§4.4)

    private var idlePill: some View {
        ZStack {
            Circle().fill(DS.Colors.panel).frame(width: 48, height: 48)
            Text("∼")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.Colors.moss)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    // MARK: - Recording (§4.1)

    private var recordingPill: some View {
        HStack(spacing: 10) {
            RecordingDot()                                          // 1. dot
            WaveformBars(level: appState.audioLevel)               // 2. bars
            Text(timerText)                                         // 3. timer
                .font(DS.Fonts.mono(11))
                .foregroundStyle(DS.Colors.paper.opacity(0.6))
                .monospacedDigit()
                .fixedSize()
            Rectangle()                                             // 4. divider
                .fill(DS.Colors.paper.opacity(0.15))
                .frame(width: 1, height: 14)
                .padding(.horizontal, 2)
            Text("∼")                                               // 5. tilde
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.Colors.paper.opacity(0.85))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 280, height: 48)
        .pillChrome(bg: pillBg)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    // MARK: - Transcribing / enhancing (§4.2 / §4.3)

    private func processingPill(spinnerColor: Color, label: String, chipText: String) -> some View {
        HStack(spacing: 10) {
            PillSpinner(color: spinnerColor)
            Text(label)
                .font(.system(size: 12.5))
                .foregroundStyle(DS.Colors.paper)
                .lineLimit(1)
            Spacer()
            Text(chipText)
                .font(DS.Fonts.mono(10))
                .foregroundStyle(DS.Colors.paper.opacity(0.6))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(DS.Colors.paper.opacity(0.1)))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 280, height: 48)
        .pillChrome(bg: pillBg)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}

// MARK: - Pill chrome

private extension View {
    func pillChrome(bg: Color) -> some View {
        self
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .strokeBorder(DS.Colors.paper.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: DS.Shadow.pill.color,
                    radius: DS.Shadow.pill.radius,
                    x: DS.Shadow.pill.x,
                    y: DS.Shadow.pill.y)
    }
}

// MARK: - Recording dot (§4.1 — 22 pt circle, 8 pt stop square, pulse 1.2 s)

private struct RecordingDot: View {
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(DS.Colors.rec.opacity(0.25))
                .frame(width: 22, height: 22)
                .scaleEffect(pulsing ? 1.0 : 0.6)
                .opacity(pulsing ? 1.0 : 0.6)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: pulsing
                )
            RoundedRectangle(cornerRadius: 2)
                .fill(DS.Colors.rec)
                .frame(width: 8, height: 8)
        }
        .frame(width: 22, height: 22)
        .onAppear { pulsing = true }
    }
}

// MARK: - Waveform bars (§4.1 — 14 bars, 1.8 pt wide, 2 pt gap, 3–14 pt tall)

private struct WaveformBars: View {
    let level: Float
    private let count = 14
    private let barWidth: CGFloat = 1.8
    private let gap: CGFloat = 2.0

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let amp = CGFloat(max(0.15, level))
            HStack(spacing: gap) {
                ForEach(0..<count, id: \.self) { i in
                    let phase = Double(i) / Double(count) * .pi * 2
                    let osc = CGFloat((sin(t * 8 + phase) + 1) / 2)
                    let h = 3 + (14 - 3) * osc * amp
                    RoundedRectangle(cornerRadius: 1)
                        .fill(DS.Colors.paper.opacity(0.95))
                        .frame(width: barWidth, height: max(3, h))
                }
            }
        }
        .frame(height: 14)
    }
}

// MARK: - Indeterminate spinner (§4.2 — 14 pt, 1.6 pt stroke, 0.9 s rotation)

private struct PillSpinner: View {
    let color: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let angle = (t / 0.9).truncatingRemainder(dividingBy: 1.0) * 360.0
            Canvas { ctx, size in
                var path = Path()
                path.addArc(
                    center: CGPoint(x: size.width / 2, y: size.height / 2),
                    radius: size.width / 2 - 0.8,
                    startAngle: .degrees(angle),
                    endAngle: .degrees(angle + 270),
                    clockwise: false
                )
                ctx.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        }
        .frame(width: 14, height: 14)
    }
}
