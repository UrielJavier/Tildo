import SwiftUI

struct ReplacementsPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    @State private var searchText = ""
    @State private var filterCategory: ReplacementCategory? = nil
    @State private var selectedId: UUID? = nil

    private var filtered: [ReplacementRule] {
        state.replacementRules.filter { rule in
            let matchesSearch = searchText.isEmpty
                || rule.find.localizedCaseInsensitiveContains(searchText)
                || rule.replace.localizedCaseInsensitiveContains(searchText)
            let matchesCat = filterCategory == nil || rule.category == filterCategory
            return matchesSearch && matchesCat
        }
    }

    private var grouped: [(cat: ReplacementCategory, items: [ReplacementRule])] {
        ReplacementCategory.allCases.compactMap { cat in
            let items = filtered.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHero(icon: "arrow.2.squarepath", title: "Replacements",
                      subtitle: "Text substitutions applied after each transcription.")
                .padding(.horizontal, 32)
                .padding(.top, 28)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    statStrip
                    searchAndAdd
                    categoryChips
                    HStack(alignment: .top, spacing: 12) {
                        dictList
                        inspector
                    }
                    footerRow
                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
        }
        .onChange(of: state.replacementRules) { onSave() }
    }

    // MARK: - Stat strip

    private var statStrip: some View {
        HStack(spacing: 0) {
            statCell("\(state.replacementRules.count)", label: "Entries")
            Divider().frame(height: 28)
            statCell("\(state.replacementRules.filter { $0.enabled }.count)", label: "Active")
            Divider().frame(height: 28)
            statCell("\(Set(state.replacementRules.map { $0.category.rawValue }).count)", label: "Categories")
        }
        .background(DS.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.line, lineWidth: 1))
    }

    private func statCell(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .semibold)).foregroundStyle(DS.Colors.ink)
            Text(label).font(DS.Fonts.sans(11)).foregroundStyle(DS.Colors.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Search + add

    private var searchAndAdd: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(DS.Colors.ink3)
                TextField("Search entries…", text: $searchText)
                    .textFieldStyle(.plain).font(DS.Fonts.sans(13))
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(DS.Colors.panel)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.line, lineWidth: 1))

            Button {
                let newRule = ReplacementRule(find: "", replace: "", category: filterCategory ?? .general)
                state.replacementRules.append(newRule)
                selectedId = newRule.id
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                    Text("New entry").font(DS.Fonts.sans(12.5, weight: .medium))
                }
            }
            .buttonStyle(.dsPrimary)
        }
    }

    // MARK: - Category filter chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                catChip(label: "All", color: DS.Colors.ink,
                        count: state.replacementRules.count,
                        selected: filterCategory == nil) { filterCategory = nil }
                ForEach(ReplacementCategory.allCases) { cat in
                    let count = state.replacementRules.filter { $0.category == cat }.count
                    if count > 0 {
                        catChip(label: cat.rawValue, color: cat.color, count: count,
                                selected: filterCategory == cat) {
                            filterCategory = filterCategory == cat ? nil : cat
                        }
                    }
                }
            }
        }
    }

    private func catChip(label: String, color: Color, count: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if label != "All" { Circle().fill(color).frame(width: 6, height: 6) }
                Text(label).font(DS.Fonts.sans(11.5, weight: .medium))
                Text("\(count)").font(DS.Fonts.sans(10.5))
                    .foregroundStyle(selected ? Color.white.opacity(0.6) : DS.Colors.ink3)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 999).fill(selected ? DS.Colors.ink : DS.Colors.card))
            .overlay(RoundedRectangle(cornerRadius: 999).strokeBorder(selected ? DS.Colors.ink : DS.Colors.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color.white : DS.Colors.ink2)
    }

    // MARK: - Dictionary list

    private var dictList: some View {
        VStack(spacing: 0) {
            if grouped.isEmpty {
                Text(searchText.isEmpty ? "No entries yet." : "No entries match your search.")
                    .font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink3)
                    .frame(maxWidth: .infinity).padding(24)
            }
            ForEach(Array(grouped.enumerated()), id: \.element.cat.rawValue) { gi, group in
                if gi > 0 { DSDivider() }
                // Category header
                HStack(spacing: 8) {
                    Circle().fill(group.cat.color).frame(width: 6, height: 6)
                    Text(group.cat.rawValue.uppercased())
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(DS.Colors.ink2).tracking(0.8)
                    Spacer()
                    Text("\(group.items.count)").font(DS.Fonts.sans(10.5)).foregroundStyle(DS.Colors.ink3)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(DS.Colors.panel)
                DSDivider()
                // Rows
                ForEach(Array(group.items.enumerated()), id: \.element.id) { i, rule in
                    if let idx = state.replacementRules.firstIndex(where: { $0.id == rule.id }) {
                        DictRow(
                            rule: $state.replacementRules[idx],
                            isSelected: rule.id == selectedId,
                            onTap: { selectedId = rule.id }
                        )
                        if i < group.items.count - 1 { DSDivider() }
                    }
                }
            }
        }
        .background(DS.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.line, lineWidth: 1))
        .frame(maxWidth: .infinity)
    }

    // MARK: - Inspector

    @ViewBuilder
    private var inspector: some View {
        if let id = selectedId,
           let idx = state.replacementRules.firstIndex(where: { $0.id == id }) {
            EntryInspector(
                rule: $state.replacementRules[idx],
                onDelete: {
                    state.replacementRules.removeAll { $0.id == id }
                    selectedId = nil
                }
            )
            .frame(maxWidth: .infinity)
        } else {
            VStack {
                Spacer()
                Text("Select an entry to edit")
                    .font(DS.Fonts.sans(12)).foregroundStyle(DS.Colors.ink3)
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 200)
            .background(DS.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.line, lineWidth: 1))
        }
    }

    // MARK: - Footer

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
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(rule.find.isEmpty ? "—" : rule.find)
                    .font(DS.Fonts.sans(13))
                    .italic()
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
            .background(isSelected ? DS.Colors.mossSoft : Color.clear)
            .contentShape(Rectangle())
            .opacity(rule.enabled ? 1 : 0.55)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Entry inspector

private struct EntryInspector: View {
    @Binding var rule: ReplacementRule
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(rule.category.color).frame(width: 8, height: 8)
                Text("Entry").font(DS.Fonts.sans(12.5, weight: .medium)).foregroundStyle(DS.Colors.ink)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(DS.Colors.rec)
                }
                .buttonStyle(.dsGhost)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            DSDivider()

            VStack(alignment: .leading, spacing: 0) {
                fieldLabel("FIND")
                TextField("text to find", text: $rule.find)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, design: .monospaced))
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(DS.Colors.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DS.Colors.line, lineWidth: 1))

                Image(systemName: "arrow.down").font(.system(size: 13))
                    .foregroundStyle(DS.Colors.moss)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)

                fieldLabel("REPLACE WITH")
                TextField("replacement", text: $rule.replace)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(DS.Colors.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DS.Colors.line, lineWidth: 1))

                fieldLabel("CATEGORY").padding(.top, 14)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 68))], alignment: .leading, spacing: 5) {
                    ForEach(ReplacementCategory.allCases) { cat in
                        let isSel = rule.category == cat
                        Button { rule.category = cat } label: {
                            HStack(spacing: 4) {
                                Circle().fill(cat.color).frame(width: 5, height: 5)
                                Text(cat.rawValue).font(DS.Fonts.sans(11, weight: .medium))
                            }
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(isSel ? cat.softColor : Color.clear))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isSel ? cat.color : DS.Colors.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(isSel ? cat.color : DS.Colors.ink2)
                    }
                }
                .padding(.top, 5)

                fieldLabel("OPTIONS").padding(.top, 14)
                VStack(alignment: .leading, spacing: 6) {
                    CheckRow(label: "Case sensitive", isOn: $rule.caseSensitive)
                    CheckRow(label: "Whole word only", isOn: $rule.wholeWord)
                }
                .padding(.top, 6)
            }
            .padding(14)
        }
        .background(DS.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.line, lineWidth: 1))
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(DS.Fonts.mono(10.5, weight: .medium))
            .foregroundStyle(DS.Colors.ink4)
            .tracking(0.6)
            .padding(.bottom, 5)
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
