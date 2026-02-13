import Foundation

struct HumanCoach: Identifiable, Codable {
    let id: String
    var fullName: String
    var title: String
    var bio: String
    var specialties: [String]
    var avatarURL: String?
    var isAvailable: Bool
    var nextAvailableSlot: Date?

    init(
        id: String = UUID().uuidString,
        fullName: String,
        title: String,
        bio: String = "",
        specialties: [String] = [],
        avatarURL: String? = nil,
        isAvailable: Bool = true,
        nextAvailableSlot: Date? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.title = title
        self.bio = bio
        self.specialties = specialties
        self.avatarURL = avatarURL
        self.isAvailable = isAvailable
        self.nextAvailableSlot = nextAvailableSlot
    }
}
