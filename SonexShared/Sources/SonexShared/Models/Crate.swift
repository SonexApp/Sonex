import Foundation


// MARK: Crate
struct Crate: Codable, Identifiable, Hashable {
    let id: UUID
    let ownerID: UserID?
    let name: String
    let sortOrder: Int
    let createdAt: Date

    /// Populated client-side after fetching associated vinyl entries
    var records: [VinylEntry]?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID    = "owner_id"
        case name
        case sortOrder  = "sort_order"
        case createdAt  = "created_at"
    }
}
