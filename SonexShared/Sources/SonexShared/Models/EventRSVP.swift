// MARK: - Event RSVP

public struct EventRSVP: Codable, Identifiable {
    public let id: String
    public let eventId: String
    public let userId: String
    public var status: RSVPStatus
    public let createdAt: String?

    public enum CodingKeys: String, CodingKey {
        case id, status
        case eventId   = "event_id"
        case userId    = "user_id"
        case createdAt = "created_at"
    }
    
    /// Public initializer for creating EventRSVP instances
    public init(
        id: String,
        eventId: String,
        userId: String,
        status: RSVPStatus,
        createdAt: String? = nil
    ) {
        self.id = id
        self.eventId = eventId
        self.userId = userId
        self.status = status
        self.createdAt = createdAt
    }
}
