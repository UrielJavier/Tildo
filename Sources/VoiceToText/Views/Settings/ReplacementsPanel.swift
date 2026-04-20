import SwiftUI

struct ReplacementsPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    @State private var searchText = ""
    @State private var filterCategory: String? = nil
    @State private var editingRule: ReplacementRule? = nil
    @State private var isCreating = false
    @State private var showNewCategory = false
    @State private var newCategoryName = ""

    private var allCategoryNames: [String] {
        let builtIn = ReplacementCategory.allCases.map { $0.rawValue }
        return (builtIn + state.customReplacementCategories).filter { name in
            state.replacementRules.contains { $0.categoryName == name }
        }
    }

    private func categoryInfo(_ name: String) -> CategoryInfo {
        let customIdx = state.customReplacementCategories.firstIndex(of: name) ?? 0
        return CategoryInfo.from(name, customIndex: customIdx)
    }

    private var filtered: [ReplacementRule] {
        state.replacementRules.filter { rule in
            let matchesSearch = searchText.isEmpty
                || rule.find.localizedCaseInsensitiveContains(searchText)
                || rule.replace.localizedCaseInsensitiveContains(searchText)
            let matchesCat = filterCategory == nil || rule.categoryName == filterCategory
            return matchesSearch && matchesCat
        }
    }

    private var grouped: [(cat: String, info: CategoryInfo, items: [ReplacementRule])] {
        allCategoryNames.compactMap { name in
            let items = filtered.filter { $0.categoryName == name }
            return items.isEmpty ? nil : (name, categoryInfo(name), items)
        }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(alignment: .leading, spacing: 0) {
                // ── Top bar ────────────────────────────────
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(state.replacementRules.count) ENTRADAS · \(allCategoryNames.count) CATEGORÍAS")
                            .font(DS.Fonts.mono(10, weight: .medium))
                            .foregroundStyle(DS.Colors.ink4).tracking(0.4)
                        Text("Dictionary")
                            .font(DS.Fonts.display(28))
                            .foregroundStyle(DS.Colors.ink).tracking(-0.4)
                    }
                    Spacer()
                    Button { isCreating = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                            Text("New entry").font(DS.Fonts.sans(13, weight: .semibold))
                        }
                        .foregroundStyle(DS.Colors.paper)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(DS.Colors.ink)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 16)

                Rectangle().fill(DS.Colors.line).frame(height: 1)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        searchBar
                        categoryChips
                        dictList
                        footerRow
                        Spacer().frame(height: 16)
                    }
                    .padding(.horizontal, 28).padding(.top, 16)
                }
            }
            .background(DS.Colors.paper)
            .onChange(of: state.replacementRules) { onSave() }

            // ── Side panel ────────────────────────────────
            if isCreating || editingRule != nil {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .onTapGesture { isCreating = false; editingRule = nil }

                ReplacementSidePanel(
                    rule: editingRule,
                    defaultCategory: filterCategory ?? "General",
                    allCategories: (ReplacementCategory.allCases.map { $0.rawValue } + state.customReplacementCategories),
                    customCategories: state.customReplacementCategories,
                    onClose: { isCreating = false; editingRule = nil },
                    onAddCategory: { name in
                        if !state.customReplacementCategories.contains(name) {
                            state.customReplacementCategories.append(name)
                            onSave()
                        }
                    },
                    onSave: { saved in
                        if let editing = editingRule,
                           let idx = state.replacementRules.firstIndex(where: { $0.id == editing.id }) {
                            state.replacementRules[idx] = saved
                        } else {
                            state.replacementRules.append(saved)
                        }
                        onSave()
                        isCreating = false
                        editingRule = nil
                    },
                    onDelete: {
                        if let editing = editingRule {
                            state.replacementRules.removeAll { $0.id == editing.id }
                            onSave()
                        }
                        isCreating = false
                        editingRule = nil
                    }
                )
                .id(editingRule?.id ?? UUID())
                .frame(width: 460)
                .frame(maxHeight: .infinity)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(duration: 0.28), value: isCreating || editingRule != nil)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(DS.Colors.ink3)
            TextField("Search entries…", text: $searchText)
                .textFieldStyle(.plain).font(DS.Fonts.sans(13))
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(DS.Colors.panel)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.line, lineWidth: 1))
    }

    // MARK: - Category chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                catChip(label: String(localized: "All"), color: DS.Colors.ink,
                        count: state.replacementRules.count, selected: filterCategory == nil,
                        onSelect: { filterCategory = nil }, onDelete: nil)
                ForEach(allCategoryNames, id: \.self) { name in
                    let count = state.replacementRules.filter { $0.categoryName == name }.count
                    let info = categoryInfo(name)
                    catChip(label: name, color: info.color, count: count,
                            selected: filterCategory == name,
                            onSelect: { filterCategory = filterCategory == name ? nil : name },
                            onDelete: name == "General" ? nil : {
                                state.customReplacementCategories.removeAll { $0 == name }
                                for i in state.replacementRules.indices where state.replacementRules[i].categoryName == name {
                                    state.replacementRules[i].categoryName = "General"
                                }
                                if filterCategory == name { filterCategory = nil }
                                onSave()
                            })
                }
            }
        }
    }

    private func catChip(label: String, color: Color, count: Int, selected: Bool,
                         onSelect: @escaping () -> Void, onDelete: (() -> Void)?) -> some View {
        HStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: 4) {
                    if label != String(localized: "All") { Circle().fill(selected ? Color.white : color).frame(width: 6, height: 6) }
                    Text(label).font(DS.Fonts.sans(11.5, weight: .medium))
                    Text("\(count)").font(DS.Fonts.sans(10.5))
                        .foregroundStyle(selected ? Color.white.opacity(0.6) : DS.Colors.ink3)
                }
                .padding(.leading, 10).padding(.trailing, onDelete != nil ? 4 : 10).padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .foregroundStyle(selected ? Color.white : DS.Colors.ink2)

            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark").font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(selected ? Color.white.opacity(0.7) : DS.Colors.ink3)
                        .padding(.trailing, 8).padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
        }
        .background(RoundedRectangle(cornerRadius: 999).fill(selected ? DS.Colors.ink : DS.Colors.card))
        .overlay(RoundedRectangle(cornerRadius: 999).strokeBorder(selected ? DS.Colors.ink : DS.Colors.line, lineWidth: 1))
    }

    // MARK: - Dict list

    private var dictList: some View {
        VStack(spacing: 0) {
            if grouped.isEmpty {
                Text(searchText.isEmpty ? "No entries yet." : "No entries match.")
                    .font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink3)
                    .frame(maxWidth: .infinity).padding(24)
            }
            ForEach(Array(grouped.enumerated()), id: \.element.cat) { gi, group in
                if gi > 0 { DSDivider() }
                HStack(spacing: 8) {
                    Circle().fill(group.info.color).frame(width: 6, height: 6)
                    Text(group.cat.uppercased())
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(DS.Colors.ink2).tracking(0.8)
                    Spacer()
                    Text("\(group.items.count)").font(DS.Fonts.sans(10.5)).foregroundStyle(DS.Colors.ink3)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(DS.Colors.panel)
                DSDivider()
                ForEach(Array(group.items.enumerated()), id: \.element.id) { i, rule in
                    if let idx = state.replacementRules.firstIndex(where: { $0.id == rule.id }) {
                        DictRow(
                            rule: $state.replacementRules[idx],
                            onTap: { editingRule = rule }
                        )
                        if i < group.items.count - 1 { DSDivider() }
                    }
                }
            }
        }
        .background(DS.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.line, lineWidth: 1))
    }

    private var footerRow: some View {
        HStack {
            Text("~/.voicetotext/replacements.json")
                .font(DS.Fonts.mono(10.5)).foregroundStyle(DS.Colors.ink4)
            Spacer()
            Button("Import…") { }.buttonStyle(.dsSecondary)
            Button("Export") { }.buttonStyle(.dsSecondary)
        }
    }
}

// MARK: - Dict row

private struct DictRow: View {
    @Binding var rule: ReplacementRule
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(rule.find.isEmpty ? "—" : rule.find)
                    .font(DS.Fonts.sans(13)).italic()
                    .foregroundStyle(DS.Colors.ink).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("→").font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink3)
                Text(rule.replace.isEmpty ? "—" : rule.replace)
                    .font(DS.Fonts.sans(13, weight: .semibold))
                    .foregroundStyle(DS.Colors.ink).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                DSToggleTrack(isOn: $rule.enabled).scaleEffect(0.75).frame(width: 28, height: 16)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .contentShape(Rectangle())
            .opacity(rule.enabled ? 1 : 0.55)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Side Panel

private struct ReplacementSidePanel: View {
    let rule: ReplacementRule?
    let defaultCategory: String
    let allCategories: [String]
    let customCategories: [String]
    let onClose: () -> Void
    let onAddCategory: (String) -> Void
    let onSave: (ReplacementRule) -> Void
    let onDelete: () -> Void

    @State private var find: String
    @State private var replace: String
    @State private var categoryName: String
    @State private var caseSensitive: Bool
    @State private var wholeWord: Bool
    @State private var showNewCatField = false
    @State private var newCatInput = ""

    init(rule: ReplacementRule?, defaultCategory: String, allCategories: [String],
         customCategories: [String], onClose: @escaping () -> Void,
         onAddCategory: @escaping (String) -> Void,
         onSave: @escaping (ReplacementRule) -> Void, onDelete: @escaping () -> Void) {
        self.rule = rule
        self.defaultCategory = defaultCategory
        self.allCategories = allCategories
        self.customCategories = customCategories
        self.onClose = onClose
        self.onAddCategory = onAddCategory
        self.onSave = onSave
        self.onDelete = onDelete
        _find = State(initialValue: rule?.find ?? "")
        _replace = State(initialValue: rule?.replace ?? "")
        _categoryName = State(initialValue: rule?.categoryName ?? defaultCategory)
        _caseSensitive = State(initialValue: rule?.caseSensitive ?? false)
        _wholeWord = State(initialValue: rule?.wholeWord ?? false)
    }

    private var isValid: Bool { !find.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func infoFor(_ name: String) -> CategoryInfo {
        let idx = customCategories.firstIndex(of: name) ?? 0
        return CategoryInfo.from(name, customIndex: idx)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(rule == nil ? "New entry" : "Edit entry")
                        .font(DS.Fonts.sans(18, weight: .semibold)).foregroundStyle(DS.Colors.ink)
                    Text("Substitution applied after each transcription.")
                        .font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink3)
                }
                Spacer()
                HStack(spacing: 8) {
                    if rule != nil {
                        Button(action: onDelete) {
                            Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(DS.Colors.rec)
                                .frame(width: 22, height: 22).background(DS.Colors.panel).clipShape(Circle())
                        }.buttonStyle(.plain)
                    }
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(DS.Colors.ink3)
                            .frame(width: 22, height: 22).background(DS.Colors.panel).clipShape(Circle())
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 20)

            Rectangle().fill(DS.Colors.line).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // FIND
                    VStack(alignment: .leading, spacing: 6) {
                        Text("OÍDO").font(DS.Fonts.mono(10, weight: .medium)).foregroundStyle(DS.Colors.ink4).tracking(0.4)
                        TextField("text to detect", text: $find)
                            .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                            .padding(10).background(DS.Colors.paper)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.line, lineWidth: 1))
                    }

                    Image(systemName: "arrow.down").font(.system(size: 13)).foregroundStyle(DS.Colors.moss)
                        .frame(maxWidth: .infinity)

                    // REPLACE
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ESCRITO").font(DS.Fonts.mono(10, weight: .medium)).foregroundStyle(DS.Colors.ink4).tracking(0.4)
                        TextField("replacement", text: $replace)
                            .textFieldStyle(.plain).font(.system(size: 13, weight: .medium, design: .monospaced))
                            .padding(10).background(DS.Colors.paper)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.line, lineWidth: 1))
                    }

                    // CATEGORY
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CATEGORÍA").font(DS.Fonts.mono(10, weight: .medium)).foregroundStyle(DS.Colors.ink4).tracking(0.4)
                        FlowLayout(spacing: 6) {
                            ForEach(allCategories, id: \.self) { name in
                                let info = infoFor(name)
                                let isSel = categoryName == name
                                Button { categoryName = name } label: {
                                    HStack(spacing: 4) {
                                        Circle().fill(info.color).frame(width: 5, height: 5)
                                        Text(name).font(DS.Fonts.sans(11.5, weight: .medium))
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(isSel ? info.softColor : Color.clear))
                                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isSel ? info.color : DS.Colors.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(isSel ? info.color : DS.Colors.ink2)
                            }

                            // + Nueva categoría
                            if showNewCatField {
                                HStack(spacing: 4) {
                                    TextField("name", text: $newCatInput)
                                        .textFieldStyle(.plain).font(DS.Fonts.sans(11.5))
                                        .frame(width: 90)
                                    Button {
                                        let trimmed = newCatInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if !trimmed.isEmpty {
                                            onAddCategory(trimmed)
                                            categoryName = trimmed
                                        }
                                        showNewCatField = false
                                        newCatInput = ""
                                    } label: {
                                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                                    }
                                    .buttonStyle(.plain).foregroundStyle(DS.Colors.moss)
                                    Button {
                                        showNewCatField = false; newCatInput = ""
                                    } label: {
                                        Image(systemName: "xmark").font(.system(size: 9))
                                    }
                                    .buttonStyle(.plain).foregroundStyle(DS.Colors.ink3)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(DS.Colors.panel))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(DS.Colors.line, lineWidth: 1))
                            } else {
                                Button { showNewCatField = true } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "plus").font(.system(size: 9, weight: .semibold))
                                        Text("New").font(DS.Fonts.sans(11.5))
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.clear))
                                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(DS.Colors.line, style: StrokeStyle(lineWidth: 1, dash: [4])))
                                }
                                .buttonStyle(.plain).foregroundStyle(DS.Colors.ink3)
                            }
                        }
                    }

                    // OPTIONS
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OPCIONES").font(DS.Fonts.mono(10, weight: .medium)).foregroundStyle(DS.Colors.ink4).tracking(0.4)
                        CheckRow(label: String(localized: "Case sensitive"), isOn: $caseSensitive)
                        CheckRow(label: String(localized: "Whole word only"), isOn: $wholeWord)
                    }

                    // Save
                    Button {
                        onSave(ReplacementRule(
                            id: rule?.id ?? UUID(),
                            find: find.trimmingCharacters(in: .whitespacesAndNewlines),
                            replace: replace.trimmingCharacters(in: .whitespacesAndNewlines),
                            enabled: rule?.enabled ?? true,
                            categoryName: categoryName,
                            caseSensitive: caseSensitive,
                            wholeWord: wholeWord
                        ))
                    } label: {
                        Text("Save entry")
                            .font(DS.Fonts.sans(13, weight: .semibold))
                            .foregroundStyle(DS.Colors.paper)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(isValid ? DS.Colors.ink : DS.Colors.ink4)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                    .buttonStyle(.plain).disabled(!isValid)
                }
                .padding(28)
            }
        }
        .background(DS.Colors.paper)
        .shadow(color: .black.opacity(0.12), radius: 24, x: -4, y: 0)
    }
}

// MARK: - Flow layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing; x = 0; rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing; x = bounds.minX; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

// MARK: - Check row

private struct CheckRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(isOn ? DS.Colors.moss : Color.clear)
                    RoundedRectangle(cornerRadius: 4).strokeBorder(isOn ? DS.Colors.moss : DS.Colors.line, lineWidth: 1.5)
                    if isOn { Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.white) }
                }
                .frame(width: 15, height: 15)
                Text(label).font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink2)
            }
            .padding(.vertical, 5).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
