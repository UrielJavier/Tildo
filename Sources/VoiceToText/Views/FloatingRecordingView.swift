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
        appState.activeToneNameForRecording
            ?? appState.tones.first(where: { $0.id == appState.defaultToneId })?.name
            ?? "Tone"
    }

    var body: some View {
        Group {
            switch appState.status {
            case .idle:
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
            case .done:
                donePill
            case .error:
                errorPill
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
        .frame(width: 220, height: 44)
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
        .frame(width: 220, height: 44)
        .pillChrome(bg: pillBg)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    // MARK: - Done (checkmark + fade)

    private var donePill: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.Colors.moss)
            Text("Listo")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.Colors.paper.opacity(0.85))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(height: 44)
        .pillChrome(bg: pillBg)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    // MARK: - Error

    private var errorPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(DS.Colors.rec)
            Text(appState.lastError.flatMap { $0.count < 40 ? $0 : nil } ?? "Error")
                .font(.system(size: 12))
                .foregroundStyle(DS.Colors.paper.opacity(0.75))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(height: 44)
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
            .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 4)
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

// MARK: - Waveform bars (§4.1 — 14 bars, standard SwiftUI animation)

private struct WaveformBars: View {
    let level: Float
    private let count = 14

    var body: some View {
        HStack(spacing: 2.0) {
            ForEach(0..<count, id: \.self) { i in
                SingleBar(index: i, level: level)
            }
        }
        .frame(height: 14)
    }
}

private struct SingleBar: View {
    let index: Int
    let level: Float
    @State private var high = false

    private var targetH: CGFloat {
        high ? max(5, 14 * CGFloat(max(0.15, level))) : 3
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(DS.Colors.paper.opacity(0.95))
            .frame(width: 1.8, height: targetH)
            .onAppear {
                let delay = Double(index) * 0.04
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeInOut(duration: 0.3 + Double(index % 4) * 0.08)
                        .repeatForever(autoreverses: true)) {
                        high = true
                    }
                }
            }
    }
}

// MARK: - Indeterminate spinner (§4.2 — 14 pt, 1.6 pt stroke, 0.9 s rotation)

private struct PillSpinner: View {
    let color: Color
    @State private var rotating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(rotating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    rotating = true
                }
            }
    }
}
