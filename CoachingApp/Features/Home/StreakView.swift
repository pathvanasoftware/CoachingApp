import SwiftUI

struct StreakView: View {
    let streak: Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Flame Badge
            ZStack {
                Circle()
                    .fill(streakColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: "flame.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(streakColor)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text("\(streak) day streak")
                    .font(AppFonts.title3)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(encouragingMessage)
                    .font(AppFonts.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            // Streak number badge
            Text("\(streak)")
                .font(AppFonts.largeTitle)
                .foregroundStyle(streakColor)
                .frame(width: 56)
        }
        .cardStyle()
    }

    // MARK: - Streak Color

    private var streakColor: Color {
        switch streak {
        case 1...3:
            return AppTheme.warning
        case 4...7:
            return .orange
        case 8...14:
            return AppTheme.error
        case 15...29:
            return Color(red: 0.85, green: 0.2, blue: 0.1)
        default:
            return Color(red: 0.9, green: 0.15, blue: 0.05)
        }
    }

    // MARK: - Encouraging Message

    private var encouragingMessage: String {
        switch streak {
        case 1:
            return "Great start! Keep the momentum going."
        case 2...3:
            return "Building a habit. Nice work!"
        case 4...7:
            return "Solid consistency this week!"
        case 8...14:
            return "Impressive dedication. You're on fire!"
        case 15...29:
            return "Two weeks strong. Remarkable commitment!"
        case 30...59:
            return "A full month! Your growth is showing."
        case 60...89:
            return "Two months of consistency. Outstanding!"
        case 90...364:
            return "A true coaching champion!"
        default:
            return "Legendary! Over a year of daily engagement."
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StreakView(streak: 1)
        StreakView(streak: 7)
        StreakView(streak: 15)
        StreakView(streak: 42)
    }
    .padding()
}
