import Foundation

// MARK: - Exchange

public struct Exchange: Codable, Identifiable {
    public let id: String
    public let sellerId: String
    public let buyerId: String
    public var recordIds: [String]
    public var totalPrice: Double?
    public var status: ExchangeStatus
    public var qrSession: String?
    public var completedAt: String?

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
