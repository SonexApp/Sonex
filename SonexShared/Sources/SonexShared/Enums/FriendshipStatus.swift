// MARK: FriendshipStatus
enum FriendshipStatus: String, Codable, CaseIterable {
    case pending  = "pending"
    case accepted = "accepted"
    case blocked  = "blocked"
}
