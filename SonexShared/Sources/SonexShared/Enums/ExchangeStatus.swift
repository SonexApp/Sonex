// MARK: ExchangeStatus
enum ExchangeStatus: String, Codable, CaseIterable {
    case pending   = "pending"
    case accepted  = "accepted"
    case countered = "countered"
    case completed = "completed"
    case cancelled = "cancelled"
    case disputed  = "disputed"
}

