// MARK: VinylFormat
public enum VinylFormat: String, Codable, CaseIterable, Identifiable {
    case single  = "7\""
    case twelveInch = "12\""
    case tenInch = "10\""

    public var id: String { rawValue }
}
