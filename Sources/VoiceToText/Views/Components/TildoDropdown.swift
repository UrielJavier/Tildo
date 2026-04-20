import SwiftUI

/// Generic dropdown that wraps a trigger view with a floating selection list.
///
/// Handles the boilerplate that every dropdown needs:
/// - Keyboard navigation (↑ ↓ Return Escape)
/// - Hover-to-highlight synced with keyboard index
/// - Click-outside-to-close (with 50ms delay so row taps register first)
/// - Focus reset on close (via `onClose` callback)
///
/// The caller owns `isOpen` as a `@Binding` so the parent can control z-ordering
/// across sibling cards. The trigger view is responsible for its own appearance.
///
/// Example — text-only:
/// ```swift
/// TildoDropdown(items: models, isOpen: $isOpen, triggerHeight: 30, onSelect: { selected = $0 }) {
///     myTriggerView
/// } row: { item, isHighlighted in
///     TildoDropdownRow(label: item, isHighlighted: isHighlighted)
/// }
/// ```
///
/// Example — icon + label (app picker):
/// ```swift
/// TildoDropdown(items: apps, isOpen: $isOpen, triggerHeight: 38, onSelect: { chosen = $0 }) {
///     myTriggerView
/// } row: { app, isHighlighted in
///     TildoDropdownRow(icon: app.icon, label: app.name, isHighlighted: isHighlighted)
/// }
/// ```
struct TildoDropdown<Item: Hashable, Trigger: View, Row: View>: View {
    let items: [Item]
    @Binding var isOpen: Bool
    let triggerHeight: CGFloat
    let onSelect: (Item) -> Void
    var onClose: (() -> Void)? = nil
    var maxListHeight: CGFloat = 200
    /// Minimum width for the dropdown list. Use when the trigger is narrower than the content.
    var minListWidth: CGFloat = 0
    /// Edge from which the list hangs. `.top` = left-aligned, `.topTrailing` = right-aligned.
    var listAlignment: Alignment = .top
    @ViewBuilder var trigger: () -> Trigger
    @ViewBuilder var row: (Item, Bool) -> Row

    @State private var highlightedIndex = 0
    @State private var clickMonitor: Any?
    @State private var keyMonitor: Any?

    var body: some View {
        trigger()
            .overlay(alignment: listAlignment) {
                if isOpen {
                    dropdownList
                        .offset(y: triggerHeight + 2)
                        .zIndex(100)
                }
            }
            .onChange(of: isOpen) { _, open in
                if open {
                    highlightedIndex = 0
                }
            }
            .onAppear { installMonitors() }
            .onDisappear { removeMonitors() }
    }

    // MARK: - List

    private var dropdownList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { i in
                    Button {
                        onSelect(items[i])
                        close()
                    } label: {
                        row(items[i], highlightedIndex == i)
                            .frame(minWidth: minListWidth > 0 ? minListWidth : nil,
                                   maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { if $0 { highlightedIndex = i } }
                }
            }
        }
        // fixedSize(horizontal: true) makes the list ignore the trigger's narrow proposed width
        // and instead use the natural content width (at least minListWidth).
        .frame(minWidth: minListWidth > 0 ? minListWidth : nil, maxHeight: maxListHeight)
        .fixedSize(horizontal: true, vertical: true)
        .background(DS.Colors.paper)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm)
            .strokeBorder(DS.Colors.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 4)
    }

    // MARK: - Close

    private func close() {
        isOpen = false
        highlightedIndex = 0
        onClose?()
    }

    // MARK: - Monitors

    private func installMonitors() {
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            if isOpen {
                // Delay so Button actions (mouseDown+Up) complete before we close
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { close() }
            }
            return event
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isOpen else { return event }
            switch event.keyCode {
            case 125: // ↓
                highlightedIndex = min(highlightedIndex + 1, items.count - 1)
                return nil
            case 126: // ↑
                highlightedIndex = max(highlightedIndex - 1, 0)
                return nil
            case 36, 76: // Return / Enter
                if items.indices.contains(highlightedIndex) {
                    onSelect(items[highlightedIndex])
                }
                close()
                return nil
            case 53: // Escape
                close()
                return nil
            default:
                return event
            }
        }
    }

    private func removeMonitors() {
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}

// MARK: - Standard row views

/// Plain-text row. Use for most dropdowns.
struct TildoDropdownRow: View {
    let label: String
    var sublabel: String? = nil
    var icon: NSImage? = nil
    let isHighlighted: Bool
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if let img = icon {
                Image(nsImage: img)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(DS.Fonts.sans(13))
                    .foregroundStyle(DS.Colors.ink)
                    .lineLimit(1)
                if let sub = sublabel {
                    Text(sub)
                        .font(DS.Fonts.sans(11))
                        .foregroundStyle(DS.Colors.ink3)
                        .lineLimit(1)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Colors.moss)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, sublabel != nil ? 7 : 9)
        .background(isHighlighted ? DS.Colors.panel : DS.Colors.paper)
    }
}

/// Monospaced row variant — for model IDs, code values, etc.
struct TildoDropdownMonoRow: View {
    let label: String
    let isHighlighted: Bool
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(DS.Fonts.mono(12))
                .foregroundStyle(DS.Colors.ink)
                .lineLimit(1)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Colors.moss)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background(isHighlighted ? DS.Colors.panel : DS.Colors.paper)
    }
}
