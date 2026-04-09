//
//  RSVPStatus.swift
//  SonexShared
//
//  Created by Ricardo Payares on 4/3/26.
//

enum RSVPStatus: String, Codable, CaseIterable {
    case interested
    case going
    case notGoing = "not_going"
}
