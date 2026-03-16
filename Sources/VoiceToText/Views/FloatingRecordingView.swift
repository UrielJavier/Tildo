import SwiftUI

struct FloatingRecordingView: View {
    @State var appState: AppState

    private var theme: ThemeColors { appState.appTheme.colors }

    private var timerText: String {
        let m = appState.recordingSeconds / 60
        let s = appState.recordingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        HStack(spacing: 10) {
            statusIndicator
            centerContent
            trailingContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.floatingBackground)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        }
        .animation(.easeInOut(duration: 0.3), value: appState.status)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch appState.status {
        case .recording:
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .shadow(color: .red.opacity(0.5), radius: 6)
                .modifier(PulseModifier())
        case .transcribing:
            Image(systemName: "waveform")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.accent)
                .modifier(PulseModifier())
        case .processing:
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.accent)
                .modifier(PulseModifier())
        default:
            Circle()
                .fill(theme.floatingSecondary.opacity(0.4))
                .frame(width: 10, height: 10)
        }
    }

    @ViewBuilder
    private var centerContent: some View {
        switch appState.status {
        case .recording:
            WaveformView(level: appState.audioLevel, theme: theme)
        case .transcribing:
            Text("Transcribing")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.floatingSecondary)
        case .processing:
            Text("Enhancing")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.floatingSecondary)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch appState.status {
        case .recording:
            Text(timerText)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(theme.floatingSecondary)
                .fixedSize()
        case .transcribing, .processing:
            ProgressView()
                .controlSize(.small)
                .tint(theme.floatingSecondary)
        default:
            EmptyView()
        }
    }
}

private struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 0.9)
            .opacity(isPulsing ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

private struct WaveformView: View {
    let level: Float
    let theme: ThemeColors
    private static let barCount = 20
    private let barWidth: CGFloat = 2.5
    private let spacing: CGFloat = 1.5
    private let maxHeight: CGFloat = 18

    @State private var samples: [CGFloat] = Array(repeating: 0, count: Self.barCount)

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(0..<Self.barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(barColor(for: samples[i]))
                    .frame(width: barWidth, height: max(2, samples[i] * maxHeight))
            }
        }
        .frame(height: maxHeight)
        .onChange(of: level) {
            samples.removeFirst()
            samples.append(min(1, CGFloat(sqrt(max(0, level))) * 2.5))
        }
    }

    private func barColor(for value: CGFloat) -> Color {
        if value > 0.7 { return theme.waveformHigh }
        if value > 0.4 { return theme.waveformMid }
        return theme.waveformLow
    }
}
