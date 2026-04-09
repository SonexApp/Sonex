import Foundation


// MARK: - Message

struct Message: Codable, Identifiable {
    let id: String
    let threadId: String
    let exchangeId: String
    let senderId: String
    var body: String?
    var offerAmount: Double?
    var offerStatus: OfferStatus?
    var recordId: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, body
        case threadId     = "thread_id"
        case exchangeId   = "exchange_id"
        case senderId     = "sender_id"
        case offerAmount  = "offer_amount"
        case offerStatus  = "offer_status"
        case recordId     = "record_id"
        case createdAt    = "created_at"
    }
}
