import Foundation

public struct SonexUser: Codable, Identifiable {
    public let id: String
    public let userId: String
    public var username: String
    public var displayName: String?
    public var avatarUrl: String?
    public var bio: String?
    public var address: String?
    public var isSignature: Bool
    public let createdAt: String?
    
    public init(
        id: String,
        userId: String,
        username: String,
        displayName: String? = nil,
        avatarUrl: String? = nil,
        bio: String? = nil,
        address: String? = nil,
        isSignature: Bool = false,
        createdAt: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.address = address
        self.isSignature = isSignature
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, username, bio, address
        case userId = "user_id"
        case displayName = "display_name"
        case avatarUrl   = "avatar_url"
        case isSignature = "is_signature"
        case createdAt   = "created_at"
    }
}
//
//public struct SonexLocation: Codable {
//    public var latitude: Double
//    public var longitude: Double
//    
//    public init(latitude: Double, longitude: Double) {
//        self.latitude = latitude
//        self.longitude = longitude
//    }
//}
