
// MARK: VinylGrade (Goldmine standard)
public enum VinylGrade: String, Codable, CaseIterable, Identifiable {
    case mint            = "M"
    case nearMint        = "NM"
    case veryGoodPlus    = "VG+"
    case veryGood        = "VG"
    case goodPlus        = "G+"
    case good            = "G"
    case fair            = "F"
    case poor            = "P"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mint:         return "Mint"
        case .nearMint:     return "Near Mint"
        case .veryGoodPlus: return "Very Good Plus"
        case .veryGood:     return "Very Good"
        case .goodPlus:     return "Good Plus"
        case .good:         return "Good"
        case .fair:         return "Fair"
        case .poor:         return "Poor"
        }
    }

    /// Approximate condition multiplier for valuation engine
    var conditionMultiplier: Double {
        switch self {
        case .mint:         return 1.0
        case .nearMint:     return 0.90
        case .veryGoodPlus: return 0.75
        case .veryGood:     return 0.55
        case .goodPlus:     return 0.35
        case .good:         return 0.20
        case .fair:         return 0.10
        case .poor:         return 0.05
        }
    }
}
