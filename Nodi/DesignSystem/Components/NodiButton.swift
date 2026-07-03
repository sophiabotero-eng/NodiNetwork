import SwiftUI

enum NodiButtonStyleKind {
    case primary
    case secondary
    case destructive
    case plain
}

struct NodiButton: View {
    let title: String
    var kind: NodiButtonStyleKind = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NodiSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else {
                    if let icon {
                        Image(systemName: icon)
                    }
                    Text(title)
                        .font(NodiFont.headline())
                }
            }
            .frame(maxWidth: kind == .plain ? nil : .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, NodiSpacing.md)
            .background(background)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: NodiRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NodiRadius.md, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: kind == .secondary ? 1 : 0)
            )
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
        .animation(NodiAnimation.quickSpring, value: isLoading)
        .buttonStyle(NodiPressableStyle())
    }

    private var background: Color {
        switch kind {
        case .primary: return NodiColor.accent
        case .secondary: return .clear
        case .destructive: return NodiColor.danger
        case .plain: return .clear
        }
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary, .destructive: return .white
        case .secondary: return NodiColor.primaryText
        case .plain: return NodiColor.accent
        }
    }

    private var borderColor: Color {
        kind == .secondary ? NodiColor.divider : .clear
    }
}

/// Subtle scale-down on press, used everywhere instead of the default
/// button style so every tap target in the app feels consistently "alive."
struct NodiPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        NodiButton(title: "Continue", action: {})
        NodiButton(title: "Secondary", kind: .secondary, action: {})
        NodiButton(title: "Delete", kind: .destructive, action: {})
        NodiButton(title: "Loading", isLoading: true, action: {})
    }
    .padding()
}
