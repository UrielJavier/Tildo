import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @Bindable var state: AppState
    var onSave: (() -> Void)?

    @State private var searchText = ""
    @State private var filter: HistoryFilter = .all

    private enum HistoryFilter: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case week = "This week"

        func matches(_ entry: TranscriptionEntry) -> Bool {
            switch self {
            case .all: return true
            case .today: return Calendar.current.isDateInToday(entry.date)
            case .week:
                let start = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!
                return entry.date >= start
            }
        }
    }

    private var filtered: [TranscriptionEntry] {
        state.history.filter { entry in
            filter.matches(entry) &&
            (searchText.isEmpty || entry.text.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar

            if state.history.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { entry in
                            HistoryEntryCard(entry: entry) {
                                state.history.removeAll { $0.id == entry.id }
                                onSave?()
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.ink3)
                    TextField("Search transcriptions…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(DS.Fonts.sans(13))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(DS.Colors.panel)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.line, lineWidth: 1))
                .frame(maxWidth: .infinity)

                // Export
                Button { exportHistory() } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13))
                }
                .buttonStyle(.dsGhost)
                .help("Export to file")

                // Clear all
                Button("Clear All") {
                    state.history.removeAll()
                    onSave?()
                }
                .buttonStyle(.dsDestructive)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(HistoryFilter.allCases, id: \.rawValue) { f in
                        let count = state.history.filter { f.matches($0) }.count
                        FilterChip(label: f.rawValue, count: count, isActive: filter == f) {
                            filter = f
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            DSDivider()
        }
        .background(DS.Colors.paper)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("∼")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(DS.Colors.ink.opacity(0.12))
            Text("No transcriptions yet")
                .font(DS.Fonts.sans(14, weight: .medium))
                .foregroundStyle(DS.Colors.ink2)
            Text("Hold your shortcut and start speaking.")
                .font(DS.Fonts.sans(12))
                .foregroundStyle(DS.Colors.ink3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Export

    private func exportHistory() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let content = state.history.map { entry in
            "[\(formatter.string(from: entry.date))]\n\(entry.text)"
        }.joined(separator: "\n\n---\n\n")
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "transcriptions.txt"
        panel.allowedContentTypes = [.plainText]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Filter chip

private struct FilterChip: View {
    let label: String
    let count: Int
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(DS.Fonts.sans(12, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? DS.Colors.paper : DS.Colors.ink2)
                Text("\(count)")
                    .font(DS.Fonts.mono(10.5))
                    .foregroundStyle(isActive ? DS.Colors.paper.opacity(0.65) : DS.Colors.ink4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(isActive ? DS.Colors.ink : Color.clear))
            .overlay(Capsule().strokeBorder(isActive ? Color.clear : DS.Colors.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History entry card

private struct HistoryEntryCard: View {
    let entry: TranscriptionEntry
    let onDelete: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: relative time + mode chip
            HStack(spacing: 6) {
                Text(relativeTime(from: entry.date))
                    .font(DS.Fonts.mono(11.5))
                    .foregroundStyle(DS.Colors.ink3)
                if let mode = entry.mode, !mode.isEmpty {
                    Text(mode)
                        .font(DS.Fonts.mono(10.5))
                        .foregroundStyle(DS.Colors.ink3)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(DS.Colors.panel))
                        .overlay(Capsule().strokeBorder(DS.Colors.line, lineWidth: 1))
                }
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Colors.ink4)
                }
                .buttonStyle(.plain)
            }

            // Body: processed text
            Text(entry.text)
                .font(DS.Fonts.sans(13))
                .foregroundStyle(DS.Colors.ink)
                .lineSpacing(entry.text.count > 80 ? 3 : 0)
                .lineLimit(4)
                .textSelection(.enabled)

            // Raw transcript (only when LLM modified it)
            if let raw = entry.rawText {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text("RAW")
                            .font(DS.Fonts.mono(9.5, weight: .medium))
                            .foregroundStyle(DS.Colors.ink4)
                            .tracking(0.4)
                        Rectangle()
                            .fill(DS.Colors.lineSoft)
                            .frame(height: 1)
                    }
                    Text(raw)
                        .font(DS.Fonts.sans(12))
                        .foregroundStyle(DS.Colors.ink4)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                .padding(.top, 2)
            }

            // Footer: stats + copy
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    if let wc = entry.wordCount {
                        Text("\(wc) words")
                            .font(DS.Fonts.sans(11))
                            .foregroundStyle(DS.Colors.ink4)
                    }
                    if let dur = entry.durationSeconds, dur > 0 {
                        Text("\(dur)s")
                            .font(DS.Fonts.mono(11))
                            .foregroundStyle(DS.Colors.ink4)
                    }
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.text, forType: .string)
                    withAnimation(DS.Motion.snappy) { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(DS.Motion.snappy) { copied = false }
                    }
                } label: {
                    Text(copied ? "Copied" : "Copy")
                        .font(DS.Fonts.sans(11.5, weight: .medium))
                        .foregroundStyle(copied ? DS.Colors.mossInk : DS.Colors.moss)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(DS.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(DS.Colors.line, lineWidth: 1)
        )
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
