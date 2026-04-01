import Foundation


// MARK: Exchange
struct Exchange: Codable, Identifiable {
    let id: UUID
    let sellerID: UserID?
    let buyerID: UserID?
    let recordIDs: [RecordID]
    let totalPrice: Decimal?
    let status: ExchangeStatus
    let qrSession: String?
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case sellerID    = "seller_id"
        case buyerID     = "buyer_id"
        case recordIDs   = "record_ids"
        case totalPrice  = "total_price"
        case status
        case qrSession   = "qr_session"
        case completedAt = "completed_at"
    }
}
