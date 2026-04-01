
import SwiftUI

public enum SonexTab: String, CaseIterable, Identifiable {
    case collection
    case scan
    case discover
    case exchange
    case profile

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .collection: return "square.stack.3d.up.fill"
        case .scan:       return "wave.3.right.circle.fill"
        case .discover:   return "map.fill"
        case .exchange:   return "arrow.left.arrow.right.circle.fill"
        case .profile:    return "person.crop.circle.fill"
        }
    }

    public var label: String {
        switch self {
        case .collection: return "Crates"
        case .scan:       return "Tap"
        case .discover:   return "Discover"
        case .exchange:   return "Exchange"
        case .profile:    return "Profile"
        }
    }


    public init() { self = .collection }
}
