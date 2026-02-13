import SwiftUI

struct AccountSettingsView: View {
    @Bindable var viewModel: ProfileViewModel

    @State private var showingDeleteConfirmation = false
    @State private var showingExportConfirmation = false
    @State private var isExporting = false

    var body: some View {
        List {
            // Display Name
            displayNameSection

            // Email (Read-Only)
            emailSection

            // Organization Info
            organizationSection

            // Seat Tier
            seatTierSection

            // Data Management
            dataManagementSection

            // Danger Zone
            dangerZoneSection
        }
        .navigationTitle("Account Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete Account",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                // In a real app, this would call an API to delete the account
                viewModel.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
        }
        .alert("Export Data", isPresented: $showingExportConfirmation) {
            Button("Export") {
                Task {
                    isExporting = true
                    await viewModel.exportData()
                    isExporting = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We will prepare an export of all your coaching data including sessions, goals, and action items.")
        }
    }

    // MARK: - Display Name Section

    private var displayNameSection: some View {
        Section("Personal Information") {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Display Name")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                TextField("Your name", text: $viewModel.userName)
                    .font(AppFonts.body)
                    .textContentType(.name)
                    .onSubmit {
                        Task { await viewModel.updateProfile() }
                    }
            }
        }
    }

    // MARK: - Email Section

    private var emailSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text("Email")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    Text(viewModel.userEmail.isEmpty ? "Not set" : viewModel.userEmail)
                        .font(AppFonts.body)
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Spacer()

                Image(systemName: "lock.fill")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
    }

    // MARK: - Organization Section

    private var organizationSection: some View {
        Section("Organization") {
            HStack {
                Label {
                    Text("Organization")
                        .font(AppFonts.body)
                } icon: {
                    Image(systemName: "building.2.fill")
                        .foregroundStyle(AppTheme.primary)
                }

                Spacer()

                Text("Individual")
                    .font(AppFonts.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Seat Tier Section

    private var seatTierSection: some View {
        Section("Subscription") {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text("Current Plan")
                            .font(AppFonts.body)
                        Text("Manage your subscription and billing")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } icon: {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }

                Spacer()

                Text(SeatTier.starter.displayName)
                    .font(AppFonts.subheadline)
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(AppTheme.primary.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        Section("Data") {
            Button {
                showingExportConfirmation = true
            } label: {
                HStack {
                    Label {
                        Text("Export My Data")
                            .font(AppFonts.body)
                            .foregroundStyle(AppTheme.textPrimary)
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(AppTheme.primary)
                    }

                    Spacer()

                    if isExporting {
                        ProgressView()
                    }
                }
            }
            .disabled(isExporting)
        }
    }

    // MARK: - Danger Zone Section

    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                            Text("Delete Account")
                                .font(AppFonts.body)
                            Text("Permanently delete your account and all data")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    } icon: {
                        Image(systemName: "trash.fill")
                    }

                    Spacer()
                }
            }
        } header: {
            Text("Danger Zone")
        }
    }
}

#Preview {
    NavigationStack {
        AccountSettingsView(
            viewModel: ProfileViewModel(appState: {
                let state = AppState()
                state.currentUserName = "Alex Johnson"
                state.currentUserEmail = "alex@company.com"
                return state
            }())
        )
    }
}
