import SwiftUI

struct ActionItemsList: View {
    let actionItems: [ActionItem]
    var onToggle: ((ActionItem) -> Void)?

    var body: some View {
        if actionItems.isEmpty {
            emptyState
        } else {
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(actionItems) { item in
                    actionItemRow(item)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.success)

            Text("All caught up!")
                .font(AppFonts.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text("No action items due today.")
                .font(AppFonts.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.lg)
        .cardStyle()
    }

    // MARK: - Action Item Row

    private func actionItemRow(_ item: ActionItem) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            // Checkbox
            Button {
                onToggle?(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? AppTheme.success : AppTheme.textTertiary)
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(item.title)
                    .font(AppFonts.body)
                    .foregroundStyle(item.isCompleted ? AppTheme.textTertiary : AppTheme.textPrimary)
                    .strikethrough(item.isCompleted)

                if !item.description.isEmpty {
                    Text(item.description)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }

                if let dueDate = item.dueDate {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: item.isOverdue ? "exclamationmark.circle.fill" : "calendar")
                            .font(AppFonts.caption2)

                        Text(dueDateText(for: dueDate, isOverdue: item.isOverdue))
                            .font(AppFonts.caption2)
                    }
                    .foregroundStyle(item.isOverdue ? AppTheme.error : AppTheme.textTertiary)
                }
            }

            Spacer()
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm))
    }

    // MARK: - Helpers

    private func dueDateText(for date: Date, isOverdue: Bool) -> String {
        if isOverdue {
            return "Overdue - \(date.shortDisplay)"
        } else if date.isToday {
            return "Due today"
        } else {
            return "Due \(date.relativeDisplay)"
        }
    }
}

#Preview {
    VStack {
        ActionItemsList(
            actionItems: [
                ActionItem(
                    sessionId: "s1",
                    userId: "u1",
                    title: "Schedule meeting with VP",
                    description: "Discuss Q2 roadmap alignment",
                    dueDate: Date()
                ),
                ActionItem(
                    sessionId: "s1",
                    userId: "u1",
                    title: "Review presentation draft",
                    dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())
                ),
                ActionItem(
                    sessionId: "s2",
                    userId: "u1",
                    title: "Completed task",
                    isCompleted: true,
                    dueDate: Date()
                )
            ],
            onToggle: { _ in }
        )

        Divider()

        ActionItemsList(actionItems: [], onToggle: { _ in })
    }
    .padding()
}
