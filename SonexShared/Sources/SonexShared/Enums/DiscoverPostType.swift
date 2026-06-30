// MARK: DiscoverPostType
import SwiftUI

public enum DiscoverPostType: String, Codable, CaseIterable, Equatable {
    case crateDrop      = "crate_drop"
    case recordSwap     = "record_swap"
    case collectionSale = "collection_sale"
    case scouting       = "scouting"
    case djSet          = "dj_set"
    case recordStore    = "record_store"
    case dancingBar     = "dancing_bar"
    case listeningBar   = "listening_bar"
    case event          = "event"
}

// MARK: - DiscoverPostType Extensions
extension DiscoverPostType {
    public var displayName: String {
        switch self {
        case .crateDrop: return "Crate Drop"
        case .recordSwap: return "Record Swap"
        case .collectionSale: return "Collection Sale"
        case .scouting: return "Scouting"
        case .djSet: return "DJ Set"
        case .recordStore: return "Record Store"
        case .dancingBar: return "Dancing Bar"
        case .listeningBar: return "Listening Bar"
        case .event: return "Event"
        }
    }
    
    public var color: Color {
        switch self {
        case .crateDrop: return .orange
        case .recordSwap: return .yellow
        case .collectionSale: return .green
        case .scouting: return .blue
        case .djSet: return .purple
        case .recordStore: return .red
        case .dancingBar: return .pink
        case .listeningBar: return .cyan
        case .event: return .indigo
        }
    }
}
