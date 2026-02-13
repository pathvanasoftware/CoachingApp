import Foundation
import Supabase

// MARK: - Supabase Service

/// Singleton wrapper around the Supabase Swift client.
/// Provides centralized access to authentication, database queries,
/// and realtime subscriptions.
final class SupabaseService: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = SupabaseService()

    // MARK: - Configuration

    // TODO: Replace with your actual Supabase project URL
    private static let supabaseURL = URL(string: "https://your-project-ref.supabase.co")!

    // TODO: Replace with your actual Supabase anon key
    private static let supabaseAnonKey = "your-supabase-anon-key"

    // MARK: - Client

    let client: SupabaseClient

    // MARK: - Init

    private init() {
        client = SupabaseClient(
            supabaseURL: Self.supabaseURL,
            supabaseKey: Self.supabaseAnonKey
        )
    }

    /// Initialize with custom URL and key (useful for testing).
    init(url: URL, key: String) {
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key
        )
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
