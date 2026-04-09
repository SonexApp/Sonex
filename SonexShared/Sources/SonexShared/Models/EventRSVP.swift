// MARK: - Event RSVP

struct EventRSVP: Codable, Identifiable {
    let id: String
    let eventId: String
    let userId: String
    var status: RSVPStatus
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case eventId   = "event_id"
        case userId    = "user_id"
        case createdAt = "created_at"
    }
}
