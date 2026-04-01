// MARK: OfferStatus
enum OfferStatus: String, Codable, CaseIterable {
    case pending  = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case countered = "countered"
    case withdrawn = "withdrawn"
}
