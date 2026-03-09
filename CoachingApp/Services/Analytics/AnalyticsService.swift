import Foundation
import os

struct AnalyticsEvent: Codable, Identifiable {
    let id: String
    let name: String
    let timestamp: Date
    let properties: [String: String]

    init(
        id: String = UUID().uuidString,
        name: String,
        timestamp: Date = Date(),
        properties: [String: String]
    ) {
        self.id = id
        self.name = name
        self.timestamp = timestamp
        self.properties = properties
    }
}

final class AnalyticsService: @unchecked Sendable {
    static let shared = AnalyticsService()

    private let logger = Logger(subsystem: "com.pathvana.ascendra", category: "analytics")
    private let queue = DispatchQueue(label: "com.pathvana.ascendra.analytics")
    private let defaults = UserDefaults.standard
    private let maxStoredEvents = 200
    private let storageKey = "com.pathvana.ascendra.analyticsEvents"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func track(_ name: String, properties: [String: Any?] = [:]) {
        let normalized = normalize(properties)
        let event = AnalyticsEvent(name: name, properties: normalized)
        logger.log("\(name, privacy: .public) \(String(describing: normalized), privacy: .public)")

        queue.async { [weak self] in
            guard let self else { return }
            var existing = self.loadStoredEvents()
            existing.append(event)
            if existing.count > self.maxStoredEvents {
                existing = Array(existing.suffix(self.maxStoredEvents))
            }

            guard let data = try? self.encoder.encode(existing) else { return }
            self.defaults.set(data, forKey: self.storageKey)
        }
    }

    func recentEvents() -> [AnalyticsEvent] {
        queue.sync {
            loadStoredEvents()
        }
    }

    private func loadStoredEvents() -> [AnalyticsEvent] {
        guard let data = defaults.data(forKey: storageKey),
              let events = try? decoder.decode([AnalyticsEvent].self, from: data) else {
            return []
        }
        return events
    }

    private func normalize(_ properties: [String: Any?]) -> [String: String] {
        var normalized: [String: String] = [:]
        for (key, value) in properties {
            guard let value else { continue }
            switch value {
            case let string as String:
                normalized[key] = string
            case let bool as Bool:
                normalized[key] = bool ? "true" : "false"
            case let int as Int:
                normalized[key] = String(int)
            case let double as Double:
                normalized[key] = String(double)
            case let date as Date:
                normalized[key] = ISO8601DateFormatter().string(from: date)
            default:
                normalized[key] = String(describing: value)
            }
        }
        return normalized
    }
}
