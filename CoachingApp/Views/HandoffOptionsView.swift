//
//  HandoffOptionsView.swift
//  AI Coaching App
//
//  Created by 刘亦菲 on 2026-02-13.
//

import SwiftUI
import StoreKit

// MARK: - Subscription Prompt View
struct SubscriptionPrompt: View {
    let onSubscribe: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(.systemYellow).opacity(0.1))
                    .frame(width: 60, height: 60)

                Image(systemName: "crown.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.yellow)
            }

            // Text
            VStack(spacing: 8) {
                Text("Premium Required")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Human coaching requires an active subscription")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Subscribe button
            Button(action: onSubscribe) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                    Text("Subscribe Now")
                        .fontWeight(.semibold)
                }
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }

            // Features list
            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "person.circle", text: "1-on-1 coaching sessions")
                featureRow(icon: "calendar", text: "Flexible scheduling")
                featureRow(icon: "message.circle", text: "Direct chat access")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding()
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

// MARK: - Handoff Options View
struct HandoffOptionsView: View {
    @State var hasSubscription: Bool = false
    @Binding var isPresented: Bool
    let onSubscribe: () -> Void
    let onOpenCoachChat: () -> Void
    let onScheduleCall: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connect with a Career Coach")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Get personalized guidance from an expert")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 20))
                }
                .accessibilityLabel("Dismiss")
            }

            Divider()

            // Content based on subscription status
            if !hasSubscription {
                SubscriptionPrompt(onSubscribe: onSubscribe)
            } else {
                coachingOptions
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
    }

    // MARK: - Coaching Options (for subscribed users)
    private var coachingOptions: some View {
        VStack(spacing: 12) {
            // In-app chat button
            Button(action: onOpenCoachChat) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 50, height: 50)

                        Image(systemName: "message.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chat with Coach")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("Start a conversation instantly")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())

            // Scheduling button
            Button(action: onScheduleCall) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 50, height: 50)

                        Image(systemName: "calendar")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.green.opacity(0.2), lineWidth: 2)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Schedule a Call")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("Book a time that works for you")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())

            // Note
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundColor(.blue)

                Text("Your coach typically responds within 24 hours")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }
}

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let highlightedFeature: String?

    private let premiumTint = Color(red: 0.83, green: 0.47, blue: 0.14)
    private let premiumAccent = Color(red: 0.09, green: 0.24, blue: 0.47)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    heroSection
                    comparisonSection
                    premiumFocusSection
                    actionSection
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(
                LinearGradient(
                    colors: [
                        premiumTint.opacity(0.12),
                        premiumAccent.opacity(0.08),
                        Color(.systemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .task {
                await appState.prepareSubscriptionStorefront()
            }
            .navigationTitle("Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Ascendra Pro")
                .font(AppFonts.caption)
                .foregroundStyle(premiumTint)
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(premiumTint.opacity(0.14))
                .clipShape(Capsule())

            Text("Structured executive coaching,\nwith the full premium toolkit.")
                .font(AppFonts.largeTitle)
                .foregroundStyle(AppTheme.textPrimary)

            Text(highlightedFeatureLine)
                .font(AppFonts.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            HStack(alignment: .lastTextBaseline, spacing: AppTheme.Spacing.sm) {
                Text(SubscriptionPlan.pro.priceLine)
                    .font(AppFonts.title3)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Premium access to voice, summaries, and both coaching personas.")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.92),
                            premiumTint.opacity(0.16),
                            premiumAccent.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .modifier(CardShadow())
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("What changes when you upgrade")
                .font(AppFonts.headline)
                .foregroundStyle(AppTheme.textPrimary)

            VStack(spacing: AppTheme.Spacing.sm) {
                planCard(for: .free)
                planCard(for: .pro)
            }
        }
    }

    private var premiumFocusSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Why people upgrade")
                .font(AppFonts.headline)
                .foregroundStyle(AppTheme.textPrimary)

            VStack(spacing: AppTheme.Spacing.sm) {
                premiumBullet(
                    icon: "mic.fill",
                    title: "Talk through high-stakes situations",
                    copy: "Voice access makes the app feel like a live executive thinking partner."
                )
                premiumBullet(
                    icon: "doc.text.magnifyingglass",
                    title: "Leave with a sharper takeaway",
                    copy: "Session summaries turn a coaching conversation into something you can revisit and act on."
                )
                premiumBullet(
                    icon: "person.2.fill",
                    title: "Choose the coaching voice you need",
                    copy: "Switch between a direct challenger and a supportive strategist as the situation changes."
                )
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if appState.isLoadingSubscriptionProducts && appState.availableSubscriptionProducts.isEmpty {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ProgressView()
                    Text("Loading subscription options...")
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            } else if !appState.availableSubscriptionProducts.isEmpty {
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(appState.availableSubscriptionProducts, id: \.id) { product in
                        purchaseButton(for: product)
                    }
                }
            } else {
                unavailableProductsState
            }

            Button {
                Task {
                    await appState.restorePurchases()
                    if appState.hasProAccess {
                        dismiss()
                    }
                }
            } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    if appState.isRestoringPurchases {
                        ProgressView()
                            .tint(AppTheme.textSecondary)
                    }
                    Text("Restore Purchases")
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.sm)
            }
            .disabled(appState.isPurchasingSubscription || appState.isRestoringPurchases)

            if let subscriptionErrorMessage = appState.subscriptionErrorMessage {
                Text(subscriptionErrorMessage)
                    .font(AppFonts.caption)
                    .foregroundStyle(AppTheme.warning)
            }

            Text("StoreKit is live in this screen. Products must exist in App Store Connect or a StoreKit config for purchases to complete.")
                .font(AppFonts.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var unavailableProductsState: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Subscription products are not available.")
                .font(AppFonts.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Configure the monthly and yearly Pro products in App Store Connect or attach a StoreKit configuration file for local purchase testing.")
                .font(AppFonts.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

#if DEBUG
            Button {
                appState.upgradeToProPreview()
                dismiss()
            } label: {
                Text(appState.subscriptionPlan == .pro ? "You're on Ascendra Pro" : "Unlock Pro Preview")
                    .font(AppFonts.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .foregroundStyle(.white)
                    .background(appState.subscriptionPlan == .pro ? AppTheme.success : premiumAccent)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
            }
            .disabled(appState.subscriptionPlan == .pro)

            if appState.subscriptionPlan == .pro {
                Button {
                    appState.resetSubscriptionPreview()
                } label: {
                    Text("Reset to Free Preview")
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
#endif
        }
    }

    private func planCard(for plan: SubscriptionPlan) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(plan.displayName)
                        .font(AppFonts.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(plan.priceLine)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Text(plan.badgeTitle)
                    .font(AppFonts.caption)
                    .foregroundStyle(plan == .pro ? premiumTint : AppTheme.textSecondary)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background((plan == .pro ? premiumTint : AppTheme.textTertiary).opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(plan.summary)
                .font(AppFonts.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                ForEach(plan.featureHighlights, id: \.self) { feature in
                    Label(feature, systemImage: "checkmark.circle.fill")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func premiumBullet(icon: String, title: String, copy: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(premiumAccent)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(copy)
                    .font(AppFonts.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                .fill(Color(.secondarySystemBackground).opacity(0.92))
        )
    }

    private func purchaseButton(for product: Product) -> some View {
        Button {
            Task {
                await appState.purchaseSubscription(product)
                if appState.hasProAccess {
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(productTitle(for: product))
                        .font(AppFonts.headline)
                        .foregroundStyle(.white)
                    Text(product.displayPrice)
                        .font(AppFonts.caption)
                        .foregroundStyle(Color.white.opacity(0.84))
                }

                Spacer()

                if appState.activeSubscriptionProductID == product.id && appState.hasProAccess {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                } else if appState.isPurchasingSubscription {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.md)
            .padding(.horizontal, AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .fill(appState.activeSubscriptionProductID == product.id && appState.hasProAccess ? AppTheme.success : premiumAccent)
            )
        }
        .disabled(appState.isPurchasingSubscription || appState.isRestoringPurchases)
    }

    private func productTitle(for product: Product) -> String {
        switch product.id {
        case "com.pathvana.ascendra.pro.monthly":
            return "Ascendra Pro Monthly"
        case "com.pathvana.ascendra.pro.yearly":
            return "Ascendra Pro Yearly"
        default:
            return product.displayName
        }
    }

    private var highlightedFeatureLine: String {
        if let highlightedFeature, !highlightedFeature.isEmpty {
            return "Unlock \(highlightedFeature) and the rest of the premium executive coaching experience."
        }
        return "Upgrade when you want richer guidance, deeper reflection, and a more flexible coaching experience."
    }
}

// MARK: - Preview
#Preview("No Subscription") {
    HandoffOptionsView(
        hasSubscription: false,
        isPresented: .constant(true),
        onSubscribe: { print("Subscribe tapped") },
        onOpenCoachChat: { print("Open coach chat tapped") },
        onScheduleCall: { print("Schedule call tapped") }
    )
    .padding()
}

#Preview("Subscription View") {
    SubscriptionView(highlightedFeature: "voice coaching")
        .environment(AppState())
}

#Preview("With Subscription") {
    HandoffOptionsView(
        hasSubscription: true,
        isPresented: .constant(true),
        onSubscribe: { print("Subscribe tapped") },
        onOpenCoachChat: { print("Open coach chat tapped") },
        onScheduleCall: { print("Schedule call tapped") }
    )
    .padding()
}
