import SwiftUI

// Menu bar icon — three visual states per §4.6:
//   .idle        → static tilde glyph
//   .recording   → 3-bar equalizer, staggered sine, 1.0 s cycle
//   .transcribing / .processing → tilde rotating one full revolution per 2.4 s
//
// Never tint with moss or rec — always Color.primary so macOS handles
// light / dark menu bar appearances automatically.

struct MenuBarEqualizer: View {
    let status: AppState.Status
    let level: Float

    var body: some View {
        switch status {
        case .idle:
            TildeGlyph()
        case .recording:
            RecordingBars(level: level)
        case .transcribing, .processing:
            RotatingTilde()
        case .error:
            TildeGlyph()
        }
    }
}

// MARK: - Idle: static tilde

private struct TildeGlyph: View {
    var body: some View {
        Text("∼")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.primary)
    }
}

// MARK: - Recording: 3 animated bars

private struct RecordingBars: View {
    let level: Float

    private let barCount = 3
    private let barWidth: CGFloat = 2
    private let spacing: CGFloat = 2.5

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let levelBoost = CGFloat(max(0.25, sqrt(max(0, level))))
            HStack(spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { i in
                    let phase = Double(i) * (1.0 / 3.0)
                    let osc = CGFloat((sin((t + phase) * 2 * .pi / 1.0) + 1) / 2)
                    let h = 3 + (10 - 3) * osc * levelBoost
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.primary)
                        .frame(width: barWidth, height: max(3, h))
                }
            }
            .frame(height: 14)
        }
    }
}

// MARK: - Transcribing / Enhancing: rotating tilde

private struct RotatingTilde: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let angle = (t / 2.4).truncatingRemainder(dividingBy: 1.0) * 360.0
            Text("∼")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.primary)
                .rotationEffect(.degrees(angle))
        }
    }
}
