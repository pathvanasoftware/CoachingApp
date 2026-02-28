import Foundation

// MARK: - App Configuration

/// Centralized configuration for the app.
/// Contains all hardcoded values, constants, and environment-specific settings.
enum Configuration {

    // MARK: - API Configuration

    enum API {
        static let defaultTimeout: TimeInterval = 30.0
        static let streamingTimeout: TimeInterval = 60.0
        static let maxRetryAttempts = 3
        static let retryDelay: TimeInterval = 1.0
    }

    // MARK: - Mock/User Configuration

    enum Users {
        static let defaultMockUserId = "mock-user-001"
        static let testUserId = "test-user-001"
    }

    // MARK: - Timing Configuration

    enum Timing {
        static let mockResponseDelay: UInt64 = 500_000_000
        static let amplitudeUpdateInterval: TimeInterval = 0.15
        static let websocketHeartbeatInterval: TimeInterval = 30.0
        static let silenceThreshold: TimeInterval = 2.0
        static let typingIndicatorDelay: TimeInterval = 0.5
    }

    // MARK: - UI Configuration

    enum UI {
        static let maxMessageLength = 5000
        static let quickReplyLimit = 4
        static let sessionHistoryPageSize = 20
    }

    // MARK: - Feature Flags

    enum Features {
        static let enableVoiceInput = true
        static let enableHumanCoachHandoff = true
        static let enableCrisisResources = true
        static let enableGoalTracking = true
    }

    // MARK: - Debug Configuration

    enum Debug {
        static let isDebugMode: Bool = {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }()

        static let logNetworkRequests = isDebugMode
        static let logStreamingEvents = isDebugMode
    }
}
