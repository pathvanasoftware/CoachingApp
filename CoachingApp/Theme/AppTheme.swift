import SwiftUI

enum AppTheme {
    // MARK: - Colors

    static let primary = Color("AccentColor")
    static let primaryDark = Color(red: 0.1, green: 0.2, blue: 0.45)
    static let secondary = Color(red: 0.38, green: 0.55, blue: 0.82)

    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)

    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)

    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red

    static let coachBubble = Color(red: 0.93, green: 0.95, blue: 1.0)
    static let userBubble = Color(red: 0.18, green: 0.35, blue: 0.72)

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 999
    }

    // MARK: - Shadows

    static func cardShadow() -> some ViewModifier {
        CardShadow()
    }
}

struct CardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}
