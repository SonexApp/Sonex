import Foundation

// MARK: - UserID Typealias (if not already defined)
//public typealias UserID = String

// MARK: Friendship
public struct Friendship: Codable, Identifiable {
    public let id: UUID
    public let requesterID: UserID?
    public let addresseeID: UserID?
    public let status: FriendshipStatus
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
        case status
        case createdAt   = "created_at"
    }
    
    // Helper properties for following system
    var isFollowing: Bool {
        return status == .following || status == .accepted
    }
    
    var isPending: Bool {
        return status == .pending
    }
    
    var isBlocked: Bool {
        return status == .blocked
    }
}
