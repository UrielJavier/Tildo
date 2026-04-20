import SwiftUI

func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) { content() }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(DS.Colors.line, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 1)
        .padding(.bottom, 10)
}

func panelHero(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(DS.Fonts.mono(10.5, weight: .medium))
            .foregroundStyle(DS.Colors.moss)
            .tracking(0.6)
            .textCase(.uppercase)

        Text(title)
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(DS.Colors.ink)
            .tracking(-0.5)

        if let subtitle {
            Text(subtitle)
                .font(DS.Fonts.sans(13.5))
                .foregroundStyle(DS.Colors.ink2)
                .lineSpacing(3)
        }
    }
    .padding(.bottom, 10)
}

// Simple row header used inside cards
func settingsRow(_ title: LocalizedStringKey, icon: String, trailing: String? = nil) -> some View {
    HStack(spacing: 10) {
        Image(systemName: icon)
            .font(.system(size: 13))
            .foregroundStyle(DS.Colors.ink3)
            .frame(width: 18)
        Text(title)
            .font(DS.Fonts.sans(13))
            .foregroundStyle(DS.Colors.ink)
        Spacer()
        if let trailing {
            Text(trailing)
                .font(DS.Fonts.sans(12).monospacedDigit())
                .foregroundStyle(DS.Colors.ink3)
        }
    }
}

func sectionHeader(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(DS.Colors.ink)
        if let subtitle {
            Text(subtitle)
                .font(DS.Fonts.sans(13))
                .foregroundStyle(DS.Colors.ink2)
        }
    }
    .padding(.bottom, 4)
}

/// Generic sliding side panel container.
/// Wraps the panel in a ZStack; when `isOpen`, shows a dim backdrop + slides in `sidebar` from the trailing edge.
struct PanelWithSidebar<PanelContent: View, SideContent: View>: View {
    let isOpen: Bool
    let onDismiss: () -> Void
    @ViewBuilder var panel: () -> PanelContent
    @ViewBuilder var sidebar: () -> SideContent

    var body: some View {
        ZStack(alignment: .trailing) {
            panel()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isOpen {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }

                sidebar()
                    .frame(maxHeight: .infinity)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(duration: 0.28), value: isOpen)
    }
}
