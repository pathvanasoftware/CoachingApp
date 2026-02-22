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
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        GoalsDashboardView()
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .font(.title3)
                    }
                }

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
            action: viewModel.selectedFilter == nil || viewModel.selectedFilter == .active ? { viewModel.showingAddGoal = true } : nil
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
import SwiftUI

struct GoalsDashboardView: View {
    @State private var viewModel = GoalsViewModel()
    @State private var selectedInsight: GoalInsight?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Overall Stats
                    overallStatsCard

                    // Goal Progress Overview
                    goalProgressSection

                    // Recent Activity
                    recentActivitySection

                    // Insights
                    insightsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Goals Dashboard")
            .task {
                await viewModel.loadGoals()
            }
        }
    }

    // MARK: - Overall Stats Card

    private var overallStatsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Overall Progress")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 24) {
                // Active Goals
                statItem(
                    value: "\(viewModel.activeGoalsCount)",
                    label: "Active Goals",
                    color: .blue
                )

                // Completed
                statItem(
                    value: "\(viewModel.completedGoalsCount)",
                    label: "Completed",
                    color: .green
                )

                // Progress
                statItem(
                    value: "\(overallProgress)%",
                    label: "Overall",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var overallProgress: Int {
        guard !viewModel.goals.isEmpty else { return 0 }
        let completedCount = viewModel.completedGoalsCount
        return Int((Double(completedCount) / Double(viewModel.goals.count)) * 100)
    }

    // MARK: - Goal Progress Section

    private var goalProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Goals")
                .font(.headline)

            ForEach(viewModel.goals.filter { $0.status == .active }.prefix(5)) { goal in
                goalProgressBar(goal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func goalProgressBar(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(goal.progressPercentage)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(goal.progressPercentage), total: 100)
                .tint(progressColor(for: goal.progressPercentage))
        }
    }

    private func progressColor(for percentage: Int) -> Color {
        switch percentage {
        case 0..<25: return .red
        case 25..<50: return .orange
        case 50..<75: return .yellow
        default: return .green
        }
    }

    // MARK: - Recent Activity Section

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
            }

            if viewModel.goals.isEmpty {
                Text("No recent activity")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentGoals, id: \.id) { goal in
                    HStack(spacing: 12) {
                        Image(systemName: goal.status == .completed ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(goal.status == .completed ? .green : .gray)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.title)
                                .font(.subheadline)

                            Text(goal.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var recentGoals: [Goal] {
        Array(viewModel.goals.sorted { $0.updatedAt > $1.updatedAt }.prefix(5))
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)

            if let insights = generateInsights(), !insights.isEmpty {
                ForEach(insights) { insight in
                    insightCard(insight)
                }
            } else {
                Text("Start tracking goals to see insights")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func insightCard(_ insight: GoalInsight) -> some View {
        HStack(spacing: 12) {
            Image(systemName: insight.icon)
                .font(.title3)
                .foregroundStyle(insight.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(insight.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func generateInsights() -> [GoalInsight]? {
        var insights: [GoalInsight] = []

        // Progress insight
        if overallProgress >= 70 {
            insights.append(GoalInsight(
                icon: "star.fill",
                color: .yellow,
                title: "Great Progress!",
                message: "You're \(overallProgress)% complete on all goals"
            ))
        }

        // Streak insight
        let recentCompleted = viewModel.goals.filter {
            $0.status == .completed && $0.updatedAt > Date().addingTimeInterval(-7*24*3600)
        }.count

        if recentCompleted >= 2 {
            insights.append(GoalInsight(
                icon: "flame.fill",
                color: .orange,
                title: "On Fire! 🔥",
                message: "Completed \(recentCompleted) goals this week"
            ))
        }

        return insights
    }
}

// MARK: - Goal Insight Model

struct GoalInsight: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let message: String
}

// MARK: - Preview

#Preview {
    GoalsDashboardView()
}
