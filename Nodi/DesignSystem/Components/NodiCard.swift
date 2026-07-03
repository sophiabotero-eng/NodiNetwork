import SwiftUI

struct NodiCard<Content: View>: View {
    var padding: CGFloat = NodiSpacing.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(NodiColor.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: NodiRadius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: NodiSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(NodiColor.tertiaryText)
            Text(title)
                .font(NodiFont.title2())
                .foregroundStyle(NodiColor.primaryText)
            Text(message)
                .font(NodiFont.body())
                .foregroundStyle(NodiColor.secondaryText)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                NodiButton(title: actionTitle, kind: .secondary, action: action)
                    .padding(.top, NodiSpacing.xs)
            }
        }
        .padding(NodiSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: NodiSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(NodiFont.subheadline())
        }
        .foregroundStyle(.white)
        .padding(.vertical, 10)
        .padding(.horizontal, NodiSpacing.md)
        .background(NodiColor.danger)
        .clipShape(RoundedRectangle(cornerRadius: NodiRadius.sm, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
