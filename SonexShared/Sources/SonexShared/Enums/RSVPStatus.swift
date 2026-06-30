//
//  RSVPStatus.swift
//  SonexShared
//
//  Created by Ricardo Payares on 4/3/26.
//

import SwiftUI

public enum RSVPStatus: String, Codable, CaseIterable {
    case interested
    case going
    case notGoing = "not_going"
}

// MARK: - RSVPStatus Extensions
extension RSVPStatus {
    public var displayName: String {
        switch self {
        case .interested:
            return "Interested"
        case .going:
            return "Going"
        case .notGoing:
            return "Not Going"
        }
    }
    
    public var icon: String {
        switch self {
        case .interested:
            return "star"
        case .going:
            return "checkmark.circle.fill"
        case .notGoing:
            return "xmark.circle"
        }
    }
    
    public var color: Color {
        switch self {
        case .interested:
            return .blue
        case .going:
            return .green
        case .notGoing:
            return .red
        }
    }
}
