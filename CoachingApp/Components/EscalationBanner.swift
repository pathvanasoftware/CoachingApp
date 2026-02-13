import SwiftUI

struct EscalationBanner: View {
    var action: () -> Void

    private let warmAccent = Color(red: 0.90, green: 0.55, blue: 0.25)

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 28))
                    .foregroundStyle(warmAccent)
                    .frame(width: 36, alignment: .center)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text("Want to talk to a human coach?")
                        .font(AppFonts.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Get matched with a certified executive coach.")
                        .font(AppFonts.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AppFonts.footnote)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(AppTheme.Spacing.md)
            .background(warmAccent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .stroke(warmAccent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        EscalationBanner {
            print("Escalation tapped")
        }
    }
    .padding()
}
