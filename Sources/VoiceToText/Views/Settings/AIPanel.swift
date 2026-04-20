import SwiftUI

struct AIPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    @State private var selectedTab: AITab = .enhance

    enum AITab: String, CaseIterable, Identifiable {
        case enhance = "Enhance"
        case tones = "Tones"
        case appRules = "App Rules"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                DSSegmentedControl(
                    options: AITab.allCases,
                    label: \.rawValue,
                    selection: $selectedTab
                )
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 4)

            switch selectedTab {
            case .enhance:
                LLMPanel(state: state, onSave: onSave)
            case .tones:
                TonesPanel(state: state, onSave: onSave)
            case .appRules:
                AppRulesPanel(state: state, onSave: onSave)
            }
        }
    }
}
