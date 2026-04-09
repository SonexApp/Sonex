import Foundation

// MARK: - Exchange

struct Exchange: Codable, Identifiable {
    let id: String
    let sellerId: String
    let buyerId: String
    var recordIds: [String]
    var totalPrice: Double?
    var status: ExchangeStatus
    var qrSession: String?
    var completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case sellerId    = "seller_id"
        case buyerId     = "buyer_id"
        case recordIds   = "record_ids"
        case totalPrice  = "total_price"
        case qrSession   = "qr_session"
        case completedAt = "completed_at"
    }
}
