import Foundation

// MARK: Friendship
struct Friendship: Codable, Identifiable {
    let id: UUID
    let requesterID: UserID?
    let addresseeID: UserID?
    let status: FriendshipStatus
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
        case status
        case createdAt   = "created_at"
    }
}
