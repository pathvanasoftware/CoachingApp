import Foundation

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isBlank: Bool {
        trimmed.isEmpty
    }

    var initials: String {
        let parts = split(separator: " ")
        let mapped = parts.prefix(2).compactMap { $0.first }
        return String(mapped).uppercased()
    }

    func removingFillerWords() -> String {
        let fillers = ["um", "uh", "like", "you know", "so basically", "I mean"]
        var result = self
        for filler in fillers {
            result = result.replacingOccurrences(
                of: "\\b\(filler)\\b",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return result
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .trimmed
    }
}
