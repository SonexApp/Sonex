import Foundation

public struct SonexUser: Codable, Identifiable {
    public let id: String
    public var username: String
    public var displayName: String?
    public var avatarUrl: String?
    public var bio: String?
    public var location: SonexLocation?
    public let createdAt: String?
    
    public init(
        id: String,
        username: String,
        displayName: String? = nil,
        avatarUrl: String? = nil,
        bio: String? = nil,
        location: SonexLocation? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.location = location
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, username, bio, location
        case displayName = "display_name"
        case avatarUrl   = "avatar_url"
        case createdAt   = "created_at"
    }
}

public struct SonexLocation: Codable {
    public var latitude: Double
    public var longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
