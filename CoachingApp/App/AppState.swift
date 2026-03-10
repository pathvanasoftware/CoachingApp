import SwiftUI
import StoreKit

// MARK: - API Environment

enum APIEnvironment: String, CaseIterable {
    case localhost = "Local"
    case production = "Production"
    case staging = "Staging"

    var baseURL: String {
        switch self {
        case .localhost:
            return "http://localhost:8000/api/v1"
        case .production:
            return "https://coachingapp-backend-production.up.railway.app/api/v1"
        case .staging:
            return "https://staging-coachingapp.railway.app/api/v1"
        }
    }

    /// Full URL for the SSE chat-stream endpoint (not under /api/v1)
    var chatStreamURL: String {
        switch self {
        case .localhost:
            return "http://localhost:8000/api/chat/chat-stream"
        case .production:
            return "https://coachingapp-backend-production.up.railway.app/api/chat/chat-stream"
        case .staging:
            return "https://staging-coachingapp.railway.app/api/chat/chat-stream"
        }
    }

    var description: String {
        switch self {
        case .localhost:
            return "Local Development (localhost:8000)"
        case .production:
            return "Production"
        case .staging:
            return "Staging"
        }
    }
}

@Observable
final class AppState {
    private enum DefaultsKey {
        static let apiEnvironment = "com.coachingapp.apiEnvironment"
        static let coachingStyle = "com.pathvana.ascendra.coachingStyle"
        static let subscriptionPlan = "com.pathvana.ascendra.subscriptionPlan"
    }

    private enum StoreProductID {
        static let monthly = "com.pathvana.ascendra.pro.monthly"
        static let yearly = "com.pathvana.ascendra.pro.yearly"

        static let all = [monthly, yearly]
    }

    private struct SubscriptionSeatTierUpdate: Encodable {
        let seatTier: String

        enum CodingKeys: String, CodingKey {
            case seatTier = "seat_tier"
        }
    }

    private let subscriptionClient = APIClient()
    private let analytics = AnalyticsService.shared
    private var transactionUpdatesTask: Task<Void, Never>?

    var isAuthenticated: Bool = false
    var isLoading: Bool = true   // start loading so splash doesn't flash SignInView
    var hasCompletedOnboarding: Bool = true
    var currentUserId: String? = nil
    var currentUserEmail: String? = nil
    var currentUserName: String? = nil
    var serverSeatTier: SeatTier = .starter {
        didSet {
            if !subscriptionPlan.supports(persona: selectedPersona) {
                selectedPersona = .directChallenger
            }
        }
    }
    var hasActiveStoreSubscription: Bool = false {
        didSet {
            let cachedPlan: SubscriptionPlan = hasActiveStoreSubscription ? .pro : .free
            UserDefaults.standard.set(cachedPlan.rawValue, forKey: DefaultsKey.subscriptionPlan)
            if !subscriptionPlan.supports(persona: selectedPersona) {
                selectedPersona = .directChallenger
            }
        }
    }
    var selectedPersona: CoachingPersonaType = .directChallenger
    var selectedCoachingStyle: CoachingStyle = .auto {
        didSet {
            UserDefaults.standard.set(selectedCoachingStyle.rawValue, forKey: DefaultsKey.coachingStyle)
        }
    }
    var availableSubscriptionProducts: [Product] = []
    var isLoadingSubscriptionProducts: Bool = false
    var isPurchasingSubscription: Bool = false
    var isRestoringPurchases: Bool = false
    var subscriptionErrorMessage: String?
    var activeSubscriptionProductID: String?
    var entitlementSnapshot: EntitlementSnapshot?
    var showDebugDiagnostics: Bool = false
    
    // Use mock services (no real API calls). Defaults to false — real Railway backend.
    var useMockServices: Bool = false
    
    var apiEnvironment: APIEnvironment = {
        if let saved = UserDefaults.standard.string(forKey: DefaultsKey.apiEnvironment),
           let env = APIEnvironment(rawValue: saved) {
            return env
        }
        return .production
    }()
    var preferredInputMode: InputMode = .text
    var engagementStreak: Int = 0

    // Active session state (persists across tab switches)
    var activeSession: CoachingSession?
    var activeSessionMessages: [ChatMessage] = []

    var subscriptionPlan: SubscriptionPlan {
        if hasActiveStoreSubscription || serverSeatTier.subscriptionPlan == .pro {
            return .pro
        }
        return .free
    }

    var hasProAccess: Bool {
        subscriptionPlan == .pro
    }

    var remainingSessionsToday: Int? {
        entitlementSnapshot?.remainingSessionsToday
    }

    var dailySessionLimit: Int? {
        entitlementSnapshot?.dailySessionLimit
    }

    init() {
        subscriptionClient.authTokenProvider = {
            KeychainService.loadAccessToken()
        }

        if let savedStyle = UserDefaults.standard.string(forKey: DefaultsKey.coachingStyle),
           let style = CoachingStyle(rawValue: savedStyle) {
            selectedCoachingStyle = style
        }
        if let savedPlan = UserDefaults.standard.string(forKey: DefaultsKey.subscriptionPlan),
           let plan = SubscriptionPlan(rawValue: savedPlan) {
            hasActiveStoreSubscription = plan == .pro
        }

        let args = ProcessInfo.processInfo.arguments
        if args.contains("--force-onboarding") {
            hasCompletedOnboarding = false
        }
        if args.contains("--debug-diagnostics") {
            showDebugDiagnostics = true
        }
        if args.contains("--use-mock-api") {
            useMockServices = true
        }
        if args.contains("--use-real-api") {
            useMockServices = false
        }
        if args.contains("--auto-login") {
            isAuthenticated = true
            hasCompletedOnboarding = true
            isLoading = false
            currentUserId = "screenshot-user"
            currentUserEmail = "screenshot@ascendra.app"
            currentUserName = "Demo User"
            useMockServices = true
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func signIn(userId: String, email: String, name: String, seatTier: SeatTier = .starter) {
        currentUserId = userId
        currentUserEmail = email
        currentUserName = name
        serverSeatTier = seatTier
        isAuthenticated = true

        Task {
            await syncStoreSubscriptionToBackendIfNeeded()
            await refreshEntitlements()
        }
    }

    func applyAuthenticatedUser(_ user: User) {
        currentUserId = user.id
        currentUserEmail = user.email
        currentUserName = user.fullName
        serverSeatTier = user.seatTier
        preferredInputMode = user.preferredInputMode
        hasCompletedOnboarding = user.hasCompletedOnboarding
        selectedPersona = subscriptionPlan.supports(persona: user.preferredPersona)
            ? user.preferredPersona
            : .directChallenger
        isAuthenticated = true

        Task {
            await syncStoreSubscriptionToBackendIfNeeded()
            await refreshEntitlements()
        }
    }

    func signOut() {
        currentUserId = nil
        currentUserEmail = nil
        currentUserName = nil
        serverSeatTier = .starter
        entitlementSnapshot = nil
        isAuthenticated = false
        hasCompletedOnboarding = false
    }

    func completeOnboarding() {
        hasCompletedOnboarding = false
    }

    func switchAPIEnvironment(_ environment: APIEnvironment) {
        apiEnvironment = environment
        UserDefaults.standard.set(environment.rawValue, forKey: DefaultsKey.apiEnvironment)
    }

    func upgradeToProPreview() {
        hasActiveStoreSubscription = true
        activeSubscriptionProductID = StoreProductID.monthly
    }

    func resetSubscriptionPreview() {
        hasActiveStoreSubscription = false
        activeSubscriptionProductID = nil
    }

    @MainActor
    func prepareSubscriptionStorefront() async {
        analytics.track("paywall_opened", properties: [
            "current_plan": subscriptionPlan.rawValue,
            "seat_tier": serverSeatTier.rawValue,
        ])
        startTransactionListenerIfNeeded()
        await loadSubscriptionProducts()
        await refreshSubscriptionStatusFromStoreKit()
    }

    @MainActor
    func loadSubscriptionProducts() async {
        isLoadingSubscriptionProducts = true
        defer { isLoadingSubscriptionProducts = false }

        do {
            let products = try await Product.products(for: StoreProductID.all)
            availableSubscriptionProducts = products.sorted(by: Self.compareProducts)
            if availableSubscriptionProducts.isEmpty {
                subscriptionErrorMessage = "Subscription products are not available yet."
                analytics.track("subscription_products_empty")
            } else {
                analytics.track("subscription_products_loaded", properties: [
                    "count": products.count,
                ])
            }
        } catch {
            subscriptionErrorMessage = "Could not load subscription products right now."
            analytics.track("subscription_products_failed", properties: [
                "error": error.localizedDescription,
            ])
        }
    }

    @MainActor
    func purchaseSubscription(_ product: Product) async {
        subscriptionErrorMessage = nil
        isPurchasingSubscription = true
        defer { isPurchasingSubscription = false }
        analytics.track("subscription_purchase_started", properties: [
            "product_id": product.id,
            "display_price": product.displayPrice,
        ])

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.verifiedTransaction(from: verification)
                activeSubscriptionProductID = transaction.productID
                await transaction.finish()
                analytics.track("subscription_purchase_succeeded", properties: [
                    "product_id": transaction.productID,
                ])
                await refreshSubscriptionStatusFromStoreKit()
            case .userCancelled:
                analytics.track("subscription_purchase_cancelled", properties: [
                    "product_id": product.id,
                ])
                break
            case .pending:
                subscriptionErrorMessage = "Purchase is pending approval."
                analytics.track("subscription_purchase_pending", properties: [
                    "product_id": product.id,
                ])
            @unknown default:
                subscriptionErrorMessage = "Purchase could not be completed."
                analytics.track("subscription_purchase_unknown_result", properties: [
                    "product_id": product.id,
                ])
            }
        } catch {
            subscriptionErrorMessage = "Purchase failed: \(error.localizedDescription)"
            analytics.track("subscription_purchase_failed", properties: [
                "product_id": product.id,
                "error": error.localizedDescription,
            ])
        }
    }

    @MainActor
    func restorePurchases() async {
        subscriptionErrorMessage = nil
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }
        analytics.track("subscription_restore_started")

        do {
            try await AppStore.sync()
            await refreshSubscriptionStatusFromStoreKit()
            analytics.track("subscription_restore_completed", properties: [
                "has_pro_access": hasProAccess,
            ])
        } catch {
            subscriptionErrorMessage = "Could not restore purchases right now."
            analytics.track("subscription_restore_failed", properties: [
                "error": error.localizedDescription,
            ])
        }
    }

    @MainActor
    func refreshSubscriptionStatusFromStoreKit() async {
        var hasProAccess = false
        var latestProductID: String?

        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            guard StoreProductID.all.contains(transaction.productID) else {
                continue
            }

            hasProAccess = true
            latestProductID = transaction.productID
        }

        hasActiveStoreSubscription = hasProAccess
        activeSubscriptionProductID = latestProductID
        await syncStoreSubscriptionToBackendIfNeeded()
        await refreshEntitlements()
    }

    private func startTransactionListenerIfNeeded() {
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task { [weak self] in
            guard let self else { return }
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try Self.verifiedTransaction(from: result)
                    if StoreProductID.all.contains(transaction.productID) {
                        await transaction.finish()
                        await MainActor.run {
                            self.activeSubscriptionProductID = transaction.productID
                        }
                        await self.refreshSubscriptionStatusFromStoreKit()
                    }
                } catch {
                    await MainActor.run {
                        self.subscriptionErrorMessage = "Subscription verification failed."
                    }
                }
            }
        }
    }

    @MainActor
    private func syncStoreSubscriptionToBackendIfNeeded() async {
        guard isAuthenticated, currentUserId != nil else { return }
        guard hasActiveStoreSubscription else { return }
        guard serverSeatTier == .starter else { return }

        do {
            let updatedUser: User = try await subscriptionClient.patch(
                path: "/auth/me",
                body: SubscriptionSeatTierUpdate(seatTier: SeatTier.professional.rawValue)
            )
            serverSeatTier = updatedUser.seatTier
            analytics.track("subscription_tier_synced_to_backend", properties: [
                "seat_tier": updatedUser.seatTier.rawValue,
            ])
        } catch {
            print("[AppState] Failed to sync subscription tier to backend: \(error.localizedDescription)")
            analytics.track("subscription_tier_sync_failed", properties: [
                "error": error.localizedDescription,
            ])
        }
    }

    @MainActor
    func refreshEntitlements() async {
        guard isAuthenticated else {
            entitlementSnapshot = nil
            return
        }

        do {
            let snapshot: EntitlementSnapshot = try await subscriptionClient.get(
                path: "/auth/entitlements",
                queryItems: nil
            )
            entitlementSnapshot = snapshot
            serverSeatTier = snapshot.resolvedSeatTier
            analytics.track("entitlements_refreshed", properties: [
                "seat_tier": snapshot.seatTier,
                "remaining_sessions_today": snapshot.remainingSessionsToday,
                "can_use_voice": snapshot.canUseVoice,
                "can_use_session_summary": snapshot.canUseSessionSummary,
            ])
        } catch {
            print("[AppState] Failed to refresh entitlements: \(error.localizedDescription)")
            analytics.track("entitlements_refresh_failed", properties: [
                "error": error.localizedDescription,
            ])
        }
    }

    private static func compareProducts(_ lhs: Product, _ rhs: Product) -> Bool {
        let lhsRank = productSortRank(for: lhs.id)
        let rhsRank = productSortRank(for: rhs.id)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        return lhs.displayName < rhs.displayName
    }

    private static func productSortRank(for productID: String) -> Int {
        switch productID {
        case StoreProductID.monthly:
            return 0
        case StoreProductID.yearly:
            return 1
        default:
            return 99
        }
    }

    private static func verifiedTransaction(
        from result: VerificationResult<StoreKit.Transaction>
    ) throws -> StoreKit.Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified(_, let error):
            throw error
        }
    }
}
