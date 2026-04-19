import SwiftUI
import AppKit

struct MenuContent: View {
    let appDelegate: AppDelegate

    var body: some View {
        @Bindable var state = appDelegate.appState

        VStack(spacing: 0) {
            headerRow
            DSDivider()

            if state.isDownloading {
                DownloadRow(state: state, onCancel: appDelegate.cancelDownload)
                DSDivider()
            }

            if let err = state.lastError, state.status == .error {
                ErrorRow(message: err)
                DSDivider()
            }

            RecordCTARow(state: state, onToggle: {
                Task { await appDelegate.toggleRecording() }
            })
            DSDivider()

            if !state.history.isEmpty {
                recentSection(state: state)
                DSDivider()
            }

            statsStrip(state: state)
            DSDivider()

            footerRow
        }
        .frame(width: 380)
        .background(DS.Colors.card)
        .animation(.easeInOut(duration: 0.18), value: state.status)
        .animation(.easeInOut(duration: 0.18), value: state.isDownloading)
    }

    // MARK: - Header (44 pt)

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text("∼")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DS.Colors.moss)
            Text("Tildo")
                .font(DS.Fonts.sans(15, weight: .semibold))
                .foregroundStyle(DS.Colors.ink)

            Spacer()

            Button { appDelegate.openHistory() } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14))
            }
            .buttonStyle(.dsGhost)

            Button { appDelegate.openSettings() } label: {
                Image(systemName: "gear")
                    .font(.system(size: 14))
            }
            .buttonStyle(.dsGhost)
        }
        .frame(height: 44)
        .padding(.horizontal, 14)
    }

    // MARK: - Recent section

    private func recentSection(state: AppState) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("RECENT")
                    .font(DS.Fonts.mono(10.5, weight: .medium))
                    .foregroundStyle(DS.Colors.ink3)
                    .tracking(0.6)
                Spacer()
                Text("\(state.history.count)")
                    .font(DS.Fonts.mono(10.5))
                    .foregroundStyle(DS.Colors.ink4)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)

            ForEach(Array(state.history.prefix(5).enumerated()), id: \.element.id) { idx, entry in
                if idx > 0 {
                    Rectangle()
                        .fill(DS.Colors.lineSoft)
                        .frame(height: 1)
                        .padding(.leading, 14)
                }
                RecentItemRow(entry: entry)
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Stats strip (36 pt)

    private func statsStrip(state: AppState) -> some View {
        let todayWords = state.history
            .filter { Calendar.current.isDateInToday($0.date) }
            .compactMap(\.wordCount).reduce(0, +)
        let todayDictations = state.history
            .filter { Calendar.current.isDateInToday($0.date) }
            .count

        return HStack(spacing: 6) {
            Text("∼")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.Colors.moss)
            Text("Today: \(todayWords) words · \(todayDictations) dictations")
                .font(DS.Fonts.sans(11.5))
                .foregroundStyle(DS.Colors.ink3)
            Spacer()
        }
        .frame(height: 36)
        .padding(.horizontal, 14)
        .background(DS.Colors.panel)
    }

    // MARK: - Footer (32 pt)

    private var footerRow: some View {
        HStack(spacing: 0) {
            FooterLink("Settings") { appDelegate.openSettings() }
            midDot
            FooterLink("History") { appDelegate.openHistory() }
            midDot
            FooterLink("Quit") { NSApplication.shared.terminate(nil) }
            Spacer()
        }
        .frame(height: 32)
        .padding(.horizontal, 14)
    }

    private var midDot: some View {
        Text("·")
            .font(DS.Fonts.sans(12))
            .foregroundStyle(DS.Colors.ink4)
            .padding(.horizontal, 6)
    }
}

// MARK: - Record CTA row (52 pt)

private struct RecordCTARow: View {
    let state: AppState
    let onToggle: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 0) {
                leftContent
                Spacer()
                recordCircle
            }
            .frame(height: 52)
            .padding(.horizontal, 14)
            .background(isHovered && !isDisabled ? DS.Colors.panel : Color.clear)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var leftContent: some View {
        if state.isRecording {
            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    Capsule().fill(DS.Colors.line).frame(height: 3)
                    Capsule()
                        .fill(DS.Colors.rec)
                        .frame(width: max(4, CGFloat(min(1, state.audioLevel * 1.2)) * 120), height: 3)
                }
                .frame(width: 120)
                .animation(.linear(duration: 0.08), value: state.audioLevel)

                let s = state.recordingSeconds
                Text(String(format: "%02d:%02d", s / 60, s % 60))
                    .font(DS.Fonts.mono(12))
                    .foregroundStyle(DS.Colors.ink2)
            }
        } else if state.isTranscribing || state.isProcessing {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(state.status.rawValue)
                    .font(DS.Fonts.sans(13))
                    .foregroundStyle(DS.Colors.ink2)
            }
        } else if state.isLoadingModel {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Loading model…")
                    .font(DS.Fonts.sans(13))
                    .foregroundStyle(DS.Colors.ink2)
            }
        } else if !state.isModelLoaded {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Colors.ink3)
                Text("No model loaded — open Settings")
                    .font(DS.Fonts.sans(13))
                    .foregroundStyle(DS.Colors.ink3)
            }
        } else {
            HStack(spacing: 6) {
                Text("Hold")
                    .font(DS.Fonts.sans(13))
                    .foregroundStyle(DS.Colors.ink2)
                KeyCapView(label: state.hotkeyLabel)
                Text("to record")
                    .font(DS.Fonts.sans(13))
                    .foregroundStyle(DS.Colors.ink2)
            }
        }
    }

    private var recordCircle: some View {
        ZStack {
            Circle()
                .fill(state.isRecording ? DS.Colors.rec : DS.Colors.moss)
                .frame(width: 32, height: 32)
            if state.isRecording {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.Colors.paper)
                    .frame(width: 10, height: 10)
            } else {
                Text("∼")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.Colors.paper)
            }
        }
    }

    private var isDisabled: Bool {
        state.isTranscribing || state.isProcessing || state.isLoadingModel
            || state.isDownloading || !state.isModelLoaded && !state.isRecording
    }
}

// MARK: - Download row

private struct DownloadRow: View {
    let state: AppState
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                if let model = state.downloadingModel {
                    Text("Downloading \(model.rawValue)…")
                        .font(DS.Fonts.sans(13, weight: .medium))
                        .foregroundStyle(DS.Colors.ink)
                }
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(DS.Colors.line).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DS.Colors.moss)
                        .frame(width: CGFloat(state.downloadProgress) * 260, height: 4)
                }
            }
            Spacer()
            Text("\(Int(state.downloadProgress * 100))%")
                .font(DS.Fonts.mono(12))
                .foregroundStyle(DS.Colors.ink3)
                .frame(width: 38, alignment: .trailing)
            Button("Cancel", action: onCancel)
                .buttonStyle(.dsDestructive)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Error row

private struct ErrorRow: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(DS.Colors.rec)
            Text(message)
                .font(DS.Fonts.sans(11))
                .foregroundStyle(DS.Colors.rec)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// MARK: - RecentItemRow

private struct RecentItemRow: View {
    let entry: TranscriptionEntry
    @State private var copied = false
    @State private var isHovered = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.text, forType: .string)
            withAnimation(DS.Motion.snappy) { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation(DS.Motion.snappy) { copied = false }
            }
        } label: {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.text)
                        .font(DS.Fonts.sans(13))
                        .foregroundStyle(DS.Colors.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(metaLine)
                        .font(DS.Fonts.sans(11))
                        .foregroundStyle(DS.Colors.ink3)
                }
                Spacer(minLength: 0)
                if copied {
                    Text("Copied")
                        .font(DS.Fonts.mono(10))
                        .foregroundStyle(DS.Colors.mossInk)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(DS.Colors.mossSoft))
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .frame(height: 56)
            .padding(.horizontal, 14)
            .background(isHovered ? DS.Colors.panel : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var metaLine: String {
        let rel = relativeTime(from: entry.date)
        let mode = entry.mode?.isEmpty == false ? entry.mode! : nil
        return [rel, mode].compactMap { $0 }.joined(separator: " · ")
    }

    private func relativeTime(from date: Date) -> String {
        let secs = Int(-date.timeIntervalSinceNow)
        if secs < 60 { return "just now" }
        if secs < 3600 { return "\(secs / 60) min ago" }
        if secs < 86400 { return "\(secs / 3600) hr ago" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

// MARK: - KeyCapView

private struct KeyCapView: View {
    let label: String

    var body: some View {
        Text(label)
            .font(DS.Fonts.mono(11, weight: .medium))
            .foregroundStyle(DS.Colors.ink2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(DS.Colors.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(DS.Colors.line, lineWidth: 1)
                    )
            )
    }
}

// MARK: - FooterLink

private struct FooterLink: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Fonts.sans(12))
                .foregroundStyle(isHovered ? DS.Colors.ink : DS.Colors.ink3)
                .underline(isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
