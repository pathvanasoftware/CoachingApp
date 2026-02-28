import Foundation
import Supabase

// MARK: - Supabase Configuration Error

enum SupabaseConfigError: Error, LocalizedError {
    case missingURL
    case missingAnonKey
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .missingURL:
            return "SUPABASE_URL is not configured. Add it to Info.plist or environment variables."
        case .missingAnonKey:
            return "SUPABASE_ANON_KEY is not configured. Add it to Info.plist or environment variables."
        case .invalidURL(let urlString):
            return "Invalid SUPABASE_URL: \(urlString)"
        }
    }
}

// MARK: - Supabase Service

/// Singleton wrapper around the Supabase Swift client.
/// Provides centralized access to authentication, database queries,
/// and realtime subscriptions.
final class SupabaseService: @unchecked Sendable {

    // MARK: - Singleton

    static let shared: SupabaseService = {
        do {
            return try SupabaseService()
        } catch {
            print("[SupabaseService] Configuration error: \(error.localizedDescription)")
            return SupabaseService.fallback
        }
    }()

    private static let fallback = SupabaseService(
        url: URL(string: "https://placeholder.supabase.co")!,
        key: "placeholder-key",
        isUsingFallback: true
    )

    private static func loadSupabaseURL() throws -> URL {
        let urlString = ProcessInfo.processInfo.environment["SUPABASE_URL"]
            ?? (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)

        guard let urlString, !urlString.isEmpty else {
            throw SupabaseConfigError.missingURL
        }

        guard let url = URL(string: urlString) else {
            throw SupabaseConfigError.invalidURL(urlString)
        }

        return url
    }

    private static func loadSupabaseAnonKey() throws -> String {
        let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
            ?? (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String)

        guard let key, !key.isEmpty else {
            throw SupabaseConfigError.missingAnonKey
        }

        return key
    }

    // MARK: - Configuration Status

    static var isConfigured: Bool {
        do {
            _ = try loadSupabaseURL()
            _ = try loadSupabaseAnonKey()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Client

    let client: SupabaseClient
    let isUsingFallback: Bool

    // MARK: - Init

    private init() throws {
        let url = try Self.loadSupabaseURL()
        let key = try Self.loadSupabaseAnonKey()
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        self.isUsingFallback = false
    }

    /// Initialize with custom URL and key (useful for testing).
    init(url: URL, key: String, isUsingFallback: Bool = false) {
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        self.isUsingFallback = isUsingFallback
    }

    // MARK: - Auth Helpers

    /// Sign in with email and password.
    func signIn(email: String, password: String) async throws -> Session {
        try await client.auth.signIn(email: email, password: password)
    }

    /// Sign up with email and password.
    func signUp(email: String, password: String) async throws -> Session {
        let response = try await client.auth.signUp(email: email, password: password)
        guard let session = response.session else {
            throw SupabaseServiceError.noSession
        }
        return session
    }

    /// Sign out the current user.
    func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Get the current session, if available.
    var currentSession: Session? {
        get async {
            try? await client.auth.session
        }
    }

    /// Get the current user ID, if authenticated.
    var currentUserId: String? {
        get async {
            let session = await currentSession
            return session?.user.id.uuidString
        }
    }

    // MARK: - Database Helpers

    /// Fetch all records from a table with optional filters.
    func fetch<T: Decodable>(
        from table: String,
        columns: String = "*",
        filter: [String: String]? = nil
    ) async throws -> [T] {
        var query = client.from(table).select(columns)

        if let filter {
            for (key, value) in filter {
                query = query.eq(key, value: value)
            }
        }

        return try await query.execute().value
    }

    /// Fetch a single record by ID.
    func fetchById<T: Decodable>(
        from table: String,
        id: String,
        columns: String = "*"
    ) async throws -> T {
        try await client
            .from(table)
            .select(columns)
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    /// Insert a record into a table.
    func insert<T: Encodable>(
        into table: String,
        values: T
    ) async throws {
        try await client
            .from(table)
            .insert(values)
            .execute()
    }

    /// Insert a record and return the inserted row.
    func insertAndReturn<T: Encodable, R: Decodable>(
        into table: String,
        values: T
    ) async throws -> R {
        try await client
            .from(table)
            .insert(values)
            .select()
            .single()
            .execute()
            .value
    }

    /// Update a record by ID.
    func update<T: Encodable>(
        table: String,
        id: String,
        values: T
    ) async throws {
        try await client
            .from(table)
            .update(values)
            .eq("id", value: id)
            .execute()
    }

    /// Delete a record by ID.
    func delete(
        from table: String,
        id: String
    ) async throws {
        try await client
            .from(table)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Realtime Helpers

    /// Subscribe to changes on a table and receive updates through an AsyncStream.
    /// Returns a stream of change events and a subscription reference.
    func subscribeToChanges(
        table: String,
        filter: String? = nil
    ) -> AsyncStream<RealtimeChangeEvent> {
        AsyncStream { continuation in
            let channel = client.realtimeV2.channel("public:\(table)")

            // TODO: Configure channel listeners for INSERT, UPDATE, DELETE events
            // The exact API depends on the Supabase Swift SDK version.
            // Example:
            // channel.onPostgresChange(InsertAction.self, table: table) { change in
            //     continuation.yield(.inserted(change))
            // }
            // channel.onPostgresChange(UpdateAction.self, table: table) { change in
            //     continuation.yield(.updated(change))
            // }
            // channel.onPostgresChange(DeleteAction.self, table: table) { change in
            //     continuation.yield(.deleted(change))
            // }

            continuation.onTermination = { _ in
                Task {
                    await channel.unsubscribe()
                }
            }

            Task {
                await channel.subscribe()
            }
        }
    }
}

// MARK: - Realtime Change Event

enum RealtimeChangeEvent {
    case inserted(Any)
    case updated(Any)
    case deleted(Any)
}

// MARK: - Supabase Service Error

enum SupabaseServiceError: Error, LocalizedError {
    case noSession
    case noUser
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .noSession:
            return "No active session found."
        case .noUser:
            return "No authenticated user."
        case .queryFailed(let message):
            return "Database query failed: \(message)"
        }
    }
}
