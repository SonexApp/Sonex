import Foundation
// MARK: - Discover Post

public struct DiscoverPost: Codable, Identifiable, Equatable {
    public let id: String
    public let authorId: String?
    public var type: DiscoverPostType
    public var title: String?
    public var description: String?
    public var location: SonexLocation?
    public var address: String?
    public var metadata: [String: AnyCodable]?
    public var active: Bool
    public var expiresAt: String?
    public let createdAt: String?
    public let latitude: Double?
    public let longitude: Double?
    public let crateId: String?
    public let recordId: String?

    enum CodingKeys: String, CodingKey {
        case id, type, title, description, location, address, metadata, active, latitude, longitude
        case authorId  = "author_id"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case crateId = "crate_id"
        case recordId = "record_id"
    }
}


