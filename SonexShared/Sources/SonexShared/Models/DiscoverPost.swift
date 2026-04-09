import Foundation
// MARK: - Discover Post

struct DiscoverPost: Codable, Identifiable {
    let id: String
    let authorId: String
    var type: DiscoverPostType
    var title: String?
    var description: String?
    var location: SonexLocation?
    var address: String?
    var metadata: [String: AnyCodable]?
    var active: Bool
    var expiresAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, type, title, description, location, address, metadata, active
        case authorId  = "author_id"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}


