import SwiftUI

/// Nodi's color system. Values are defined as dynamic colors so the same
/// token automatically resolves correctly in light and dark mode without
/// call sites needing to branch on color scheme.
enum NodiColor {
    static let accent = Color("AccentColor", bundle: .main)
    static let background = Color("Background", bundle: .main)
    static let secondaryBackground = Color("SecondaryBackground", bundle: .main)
    static let elevatedSurface = Color("ElevatedSurface", bundle: .main)
    static let primaryText = Color("PrimaryText", bundle: .main)
    static let secondaryText = Color("SecondaryText", bundle: .main)
    static let tertiaryText = Color("TertiaryText", bundle: .main)
    static let divider = Color("Divider", bundle: .main)
    static let success = Color("Success", bundle: .main)
    static let warning = Color("Warning", bundle: .main)
    static let danger = Color("Danger", bundle: .main)

    // Relationship-edge colors for the graph, kept static (not scheme
    // dependent) so edges read consistently against the graph canvas.
    static let edgeWorkedTogether = Color(hex: 0x5AC8FA)
    static let edgeSchool = Color(hex: 0xFFD60A)
    static let edgeMentor = Color(hex: 0xBF5AF2)
    static let edgeFriend = Color(hex: 0x30D158)
    static let edgeClient = Color(hex: 0xFF9F0A)
    static let edgeStudio = Color(hex: 0x64D2FF)
    static let edgeEvent = Color(hex: 0xFF375F)
    static let edgeMutualGlow = Color(hex: 0xFFFFFF)
}

enum NodiFont {
    static func largeTitle(_ weight: Font.Weight = .bold) -> Font { .system(size: 34, weight: weight, design: .rounded) }
    static func title(_ weight: Font.Weight = .semibold) -> Font { .system(size: 24, weight: weight, design: .rounded) }
    static func title2(_ weight: Font.Weight = .semibold) -> Font { .system(size: 20, weight: weight, design: .rounded) }
    static func headline(_ weight: Font.Weight = .semibold) -> Font { .system(size: 17, weight: weight, design: .default) }
    static func body(_ weight: Font.Weight = .regular) -> Font { .system(size: 16, weight: weight, design: .default) }
    static func subheadline(_ weight: Font.Weight = .regular) -> Font { .system(size: 14, weight: weight, design: .default) }
    static func caption(_ weight: Font.Weight = .medium) -> Font { .system(size: 12, weight: weight, design: .default) }
}

enum NodiSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum NodiRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let pill: CGFloat = 999
}

enum NodiAnimation {
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0.2)
    static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.85)
    static let graphTransition = Animation.spring(response: 0.6, dampingFraction: 0.78, blendDuration: 0.25)
}

enum ColorSchemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Drives dark/light mode across the app. Backed by `AppStorage` so the
/// preference persists across launches. Defaults to dark mode per the
/// design system's "dark mode first" direction.
@MainActor
final class ThemeManager: ObservableObject {
    @AppStorage("nodi.colorSchemePreference") private var storedPreference: String = ColorSchemePreference.system.rawValue

    var preference: ColorSchemePreference {
        get { ColorSchemePreference(rawValue: storedPreference) ?? .system }
        set {
            objectWillChange.send()
            storedPreference = newValue.rawValue
        }
    }

    var colorScheme: ColorScheme? { preference.colorScheme }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
