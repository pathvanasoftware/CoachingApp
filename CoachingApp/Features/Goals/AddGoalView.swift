import SwiftUI

struct AddGoalView: View {
    var onSave: (String, String, Date?, [String]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var hasTargetDate = false
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var milestones: [String] = []
    @State private var newMilestoneText = ""

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Goal Info
                goalInfoSection

                // Target Date
                targetDateSection

                // Milestones
                milestonesSection
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGoal()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Goal Info Section

    private var goalInfoSection: some View {
        Section {
            TextField("Goal title", text: $title)
                .font(AppFonts.body)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Description")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                TextEditor(text: $description)
                    .font(AppFonts.body)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
            }
        } header: {
            Text("Goal Details")
        }
    }

    // MARK: - Target Date Section

    private var targetDateSection: some View {
        Section {
            Toggle("Set target date", isOn: $hasTargetDate.animation())

            if hasTargetDate {
                DatePicker(
                    "Target date",
                    selection: $targetDate,
                    in: Date()...,
                    displayedComponents: .date
                )
            }
        } header: {
            Text("Timeline")
        }
    }

    // MARK: - Milestones Section

    private var milestonesSection: some View {
        Section {
            ForEach(milestones.indices, id: \.self) { index in
                HStack {
                    Image(systemName: "circle")
                        .foregroundStyle(AppTheme.textTertiary)

                    Text(milestones[index])
                        .font(AppFonts.body)

                    Spacer()

                    Button {
                        milestones.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(AppTheme.error)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("Add a milestone", text: $newMilestoneText)
                    .font(AppFonts.body)
                    .onSubmit {
                        addMilestone()
                    }

                Button {
                    addMilestone()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppTheme.primary)
                }
                .buttonStyle(.plain)
                .disabled(newMilestoneText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("Milestones")
        } footer: {
            Text("Break your goal into smaller steps to track progress.")
        }
    }

    // MARK: - Actions

    private func addMilestone() {
        let trimmed = newMilestoneText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        milestones.append(trimmed)
        newMilestoneText = ""
    }

    private func saveGoal() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)
        let date = hasTargetDate ? targetDate : nil

        onSave(trimmedTitle, trimmedDescription, date, milestones)
        dismiss()
    }
}

#Preview {
    AddGoalView { title, description, date, milestones in
        print("Saved: \(title), \(description), \(String(describing: date)), \(milestones)")
    }
}
