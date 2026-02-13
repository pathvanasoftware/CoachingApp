import SwiftUI

struct GoalDetailView: View {
    let goal: Goal
    @Bindable var viewModel: GoalsViewModel

    @State private var showingDeleteConfirmation = false
    @State private var showingAddMilestone = false
    @State private var newMilestoneTitle = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Progress Ring
                progressSection

                // Description
                if !goal.description.isEmpty {
                    descriptionSection
                }

                // Target Date
                if let targetDate = goal.targetDate {
                    targetDateSection(targetDate)
                }

                // Milestones
                milestonesSection

                // Related Sessions
                relatedSessionsSection
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.background)
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    if goal.status == .active {
                        Button {
                            Task {
                                var updated = goal
                                updated.status = .paused
                                await viewModel.updateGoal(updated)
                            }
                        } label: {
                            Label("Pause Goal", systemImage: "pause.circle")
                        }

                        Button {
                            Task {
                                var updated = goal
                                updated.status = .completed
                                updated.progress = 1.0
                                await viewModel.updateGoal(updated)
                            }
                        } label: {
                            Label("Mark Complete", systemImage: "checkmark.circle")
                        }
                    }

                    if goal.status == .paused {
                        Button {
                            Task {
                                var updated = goal
                                updated.status = .active
                                await viewModel.updateGoal(updated)
                            }
                        } label: {
                            Label("Resume Goal", systemImage: "play.circle")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Goal", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Delete Goal",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteGoal(goal)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(goal.title)\"? This action cannot be undone.")
        }
        .alert("Add Milestone", isPresented: $showingAddMilestone) {
            TextField("Milestone title", text: $newMilestoneTitle)
            Button("Add") {
                guard !newMilestoneTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                Task {
                    let milestone = Milestone(title: newMilestoneTitle)
                    var updated = goal
                    updated.milestones.append(milestone)
                    await viewModel.updateGoal(updated)
                    newMilestoneTitle = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newMilestoneTitle = ""
            }
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        HStack {
            Spacer()
            GoalProgressBar(progress: goal.progress, style: .circular)
                .frame(width: 140, height: 140)
            Spacer()
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Description")
                .font(AppFonts.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text(goal.description)
                .font(AppFonts.body)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .cardStyle()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Target Date Section

    private func targetDateSection(_ date: Date) -> some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundStyle(AppTheme.primary)

            Text("Target Date")
                .font(AppFonts.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Text(date.shortDisplay)
                .font(AppFonts.body)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .cardStyle()
    }

    // MARK: - Milestones Section

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Text("Milestones")
                    .font(AppFonts.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                if !goal.milestones.isEmpty {
                    Text("\(goal.completedMilestones)/\(goal.milestones.count)")
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Button {
                    showingAddMilestone = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.primary)
                }
            }

            if goal.milestones.isEmpty {
                Text("No milestones yet. Add one to track your progress.")
                    .font(AppFonts.subheadline)
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppTheme.Spacing.md)
            } else {
                ForEach(goal.milestones) { milestone in
                    milestoneRow(milestone)
                }
            }
        }
        .cardStyle()
    }

    private func milestoneRow(_ milestone: Milestone) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Button {
                Task {
                    await viewModel.toggleMilestone(goalId: goal.id, milestoneId: milestone.id)
                }
            } label: {
                Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(milestone.isCompleted ? AppTheme.success : AppTheme.textTertiary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(milestone.title)
                    .font(AppFonts.body)
                    .foregroundStyle(milestone.isCompleted ? AppTheme.textTertiary : AppTheme.textPrimary)
                    .strikethrough(milestone.isCompleted)

                if let completedAt = milestone.completedAt {
                    Text("Completed \(completedAt.relativeDisplay)")
                        .font(AppFonts.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    // MARK: - Related Sessions Section

    private var relatedSessionsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Related Sessions")
                .font(AppFonts.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if goal.relatedSessionIds.isEmpty {
                Text("No coaching sessions linked to this goal yet.")
                    .font(AppFonts.subheadline)
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppTheme.Spacing.md)
            } else {
                ForEach(goal.relatedSessionIds, id: \.self) { sessionId in
                    HStack {
                        Image(systemName: "bubble.left.fill")
                            .foregroundStyle(AppTheme.primary)

                        Text("Session")
                            .font(AppFonts.body)
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .padding(.vertical, AppTheme.Spacing.xs)
                }
            }
        }
        .cardStyle()
    }
}

#Preview {
    NavigationStack {
        GoalDetailView(
            goal: Goal(
                id: "preview-goal",
                userId: "user-1",
                title: "Improve Team Communication",
                description: "Develop more effective communication strategies with direct reports.",
                status: .active,
                progress: 0.4,
                targetDate: Calendar.current.date(byAdding: .month, value: 2, to: Date()),
                milestones: [
                    Milestone(id: "m1", title: "Schedule 1:1s with all reports", isCompleted: true, completedAt: Date()),
                    Milestone(id: "m2", title: "Complete active listening workshop", isCompleted: true, completedAt: Date()),
                    Milestone(id: "m3", title: "Implement weekly standup"),
                    Milestone(id: "m4", title: "Gather team feedback"),
                    Milestone(id: "m5", title: "Refine communication approach")
                ],
                relatedSessionIds: ["session-1", "session-2"]
            ),
            viewModel: GoalsViewModel()
        )
    }
}
