// MARK: VinylFormat
enum VinylFormat: String, Codable, CaseIterable, Identifiable {
    case single  = "7\""
    case twelveInch = "12\""
    case tenInch = "10\""

    var id: String { rawValue }
}
