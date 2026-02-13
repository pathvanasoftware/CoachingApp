import SwiftUI

extension View {
    func cardStyle() -> some View {
        self
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
            .modifier(CardShadow())
    }

    func primaryButtonStyle() -> some View {
        self
            .font(AppFonts.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(AppTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
    }

    func secondaryButtonStyle() -> some View {
        self
            .font(AppFonts.headline)
            .foregroundStyle(AppTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(AppTheme.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
