import Foundation

// MARK: User
struct SonexUser: Codable, Identifiable, Hashable {
    let id: UserID
    let username: String
    let displayName: String?
    let avatarURL: String?
    let location: PostGISPoint?
    let bio: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName  = "display_name"
        case avatarURL    = "avatar_url"
        case location
        case bio
        case createdAt    = "created_at"
    }
}
