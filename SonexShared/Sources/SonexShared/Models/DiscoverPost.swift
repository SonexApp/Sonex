import Foundation

// MARK: DiscoverPost
struct DiscoverPost: Codable, Identifiable {
    let id: UUID
    let authorID: UserID?
    let type: DiscoverPostType
    let title: String?
    let description: String?
    let location: PostGISPoint?
    let address: String?
    let metadata: [String: AnyCodable]?
    let active: Bool
    let expiresAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case authorID   = "author_id"
        case type
        case title
        case description
        case location
        case address
        case metadata
        case active
        case expiresAt  = "expires_at"
        case createdAt  = "created_at"
    }
}

