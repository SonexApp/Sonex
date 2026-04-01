import Foundation


// MARK: Message
struct Message: Codable, Identifiable {
    let id: UUID
    let threadID: UUID
    let senderID: UserID?
    let body: String?
    let offerAmount: Decimal?
    let offerStatus: OfferStatus?
    let recordID: RecordID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case threadID    = "thread_id"
        case senderID    = "sender_id"
        case body
        case offerAmount = "offer_amount"
        case offerStatus = "offer_status"
        case recordID    = "record_id"
        case createdAt   = "created_at"
    }
}
