import Foundation

// MARK: - Chat History Storage

actor ChatHistoryStorage {
    static let shared = ChatHistoryStorage()

    private let fileManager = FileManager.default
    private let storageDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Initialization

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        storageDirectory = appSupport.appendingPathComponent("ChatHistory", isDirectory: true)

        try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Save Session

    func saveSession(_ session: CoachingSession, messages: [ChatMessage]) async throws {
        let sessionData = SessionData(session: session, messages: messages, savedAt: Date())
        let data = try encoder.encode(sessionData)
        let fileURL = storageDirectory.appendingPathComponent("\(session.id).json")
        try data.write(to: fileURL)
    }

    // MARK: - Load Session

    func loadSession(id: String) async throws -> (CoachingSession, [ChatMessage])? {
        let fileURL = storageDirectory.appendingPathComponent("\(id).json")
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        let sessionData = try decoder.decode(SessionData.self, from: data)
        return (sessionData.session, sessionData.messages)
    }

    // MARK: - List Sessions

    func listSessions() async throws -> [SessionSummary] {
        let contents = try fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )

        var summaries: [SessionSummary] = []
        for fileURL in contents where fileURL.pathExtension == "json" {
            if let data = try? Data(contentsOf: fileURL),
               let sessionData = try? decoder.decode(SessionData.self, from: data) {
                let summary = SessionSummary(
                    id: sessionData.session.id,
                    sessionType: sessionData.session.sessionType,
                    startedAt: sessionData.session.startedAt,
                    lastMessageAt: sessionData.savedAt,
                    messageCount: sessionData.messages.count
                )
                summaries.append(summary)
            }
        }

        return summaries.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    // MARK: - Delete Session

    func deleteSession(id: String) async throws {
        let fileURL = storageDirectory.appendingPathComponent("\(id).json")
        try fileManager.removeItem(at: fileURL)
    }

    // MARK: - Clear All

    func clearAll() async throws {
        let contents = try fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil
        )
        for fileURL in contents {
            try fileManager.removeItem(at: fileURL)
        }
    }
}

// MARK: - Session Data Model (private to this file)

private struct SessionData: Codable {
    let session: CoachingSession
    let messages: [ChatMessage]
    let savedAt: Date
}

// MARK: - Session Summary

struct SessionSummary: Identifiable, Codable {
    let id: String
    let sessionType: SessionType
    let startedAt: Date
    let lastMessageAt: Date
    let messageCount: Int
}
