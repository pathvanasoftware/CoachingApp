import SwiftUI

struct GoalsListView: View {
    @State private var viewModel = GoalsViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Picker
                filterPicker
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)

                // Goals List
                if viewModel.isLoading && viewModel.goals.isEmpty {
                    LoadingView(message: "Loading goals...")
                } else if viewModel.filteredGoals.isEmpty {
                    emptyState
                } else {
                    goalsList
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showingAddGoal = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddGoal) {
                AddGoalView { title, description, targetDate, milestones in
                    Task {
                        await viewModel.addGoal(
                            title: title,
                            description: description,
                            targetDate: targetDate,
                            milestones: milestones
                        )
                    }
                }
            }
            .task {
                await viewModel.loadGoals()
            }
            .refreshable {
                await viewModel.loadGoals()
            }
        }
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        Picker("Filter", selection: $viewModel.selectedFilter) {
            Text("Active").tag(GoalStatus?.some(.active))
            Text("Completed").tag(GoalStatus?.some(.completed))
            Text("All").tag(GoalStatus?.none)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Goals List

    private var goalsList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.md) {
                ForEach(viewModel.filteredGoals) { goal in
                    NavigationLink(value: goal.id) {
                        goalRow(goal)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationDestination(for: String.self) { goalId in
            if let goal = viewModel.goals.first(where: { $0.id == goalId }) {
                GoalDetailView(goal: goal, viewModel: viewModel)
            }
        }
    }

    // MARK: - Goal Row

    private func goalRow(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: goal.status.icon)
                    .foregroundStyle(statusColor(for: goal.status))

                Text(goal.title)
                    .font(AppFonts.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }

            if !goal.description.isEmpty {
                Text(goal.description)
                    .font(AppFonts.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }

            GoalProgressBar(progress: goal.progress, style: .linear)

            HStack {
                if !goal.milestones.isEmpty {
                    Label(
                        "\(goal.completedMilestones)/\(goal.milestones.count) milestones",
                        systemImage: "flag.fill"
                    )
                    .font(AppFonts.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                }

                Spacer()

                if let targetDate = goal.targetDate {
                    Label(targetDate.shortDisplay, systemImage: "calendar")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "target",
            title: emptyStateTitle,
            message: emptyStateMessage,
            buttonTitle: viewModel.selectedFilter == nil || viewModel.selectedFilter == .active ? "Add Goal" : nil,
            buttonAction: viewModel.selectedFilter == nil || viewModel.selectedFilter == .active ? { viewModel.showingAddGoal = true } : nil
        )
    }

    private var emptyStateTitle: String {
        switch viewModel.selectedFilter {
        case .active: return "No Active Goals"
        case .completed: return "No Completed Goals"
        case .paused: return "No Paused Goals"
        case .archived: return "No Archived Goals"
        case .none: return "No Goals Yet"
        }
    }

    private var emptyStateMessage: String {
        switch viewModel.selectedFilter {
        case .active: return "Set a new goal to start tracking your progress."
        case .completed: return "Complete your first goal to see it here."
        default: return "Create your first goal to begin your coaching journey."
        }
    }

    // MARK: - Helpers

    private func statusColor(for status: GoalStatus) -> Color {
        switch status {
        case .active: return AppTheme.primary
        case .completed: return AppTheme.success
        case .paused: return AppTheme.warning
        case .archived: return AppTheme.textTertiary
        }
    }
}

#Preview {
    GoalsListView()
}
