import SwiftUI

struct MenuBarEqualizer: View {
    let status: AppState.Status
    let level: Float

    var body: some View {
        switch status {
        case .idle, .done, .error:
            TildeGlyph()
        case .recording:
            RecordingBars(level: level)
        case .transcribing, .processing:
            RotatingTilde()
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

// MARK: - Recording: 3 bars driven by @State + repeatForever animation
// No TimelineView — animations run in Core Animation, not in SwiftUI render passes,
// so they don't trigger NSStatusBarButton setImage on every display frame.

private struct RecordingBars: View {
    let level: Float

    @State private var phase: Double = 0

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<3, id: \.self) { i in
                AnimatedBar(phase: phase + Double(i) * (1.0 / 3.0), level: level)
            }
        }
        .frame(height: 14)
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                phase = 1.0
            }
        }
    }
}

private struct AnimatedBar: View {
    let phase: Double
    let level: Float

    var body: some View {
        let levelBoost = CGFloat(max(0.25, sqrt(max(0, level))))
        let osc = CGFloat((sin(phase * 2 * .pi) + 1) / 2)
        let h = max(3, 3 + 7 * osc * levelBoost)
        return RoundedRectangle(cornerRadius: 1)
            .fill(Color.primary)
            .frame(width: 2, height: h)
    }
}

// MARK: - Transcribing / Enhancing: rotating tilde

private struct RotatingTilde: View {
    @State private var angle: Double = 0

    var body: some View {
        Text("∼")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.primary)
            .rotationEffect(.degrees(angle))
            .onAppear {
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}
