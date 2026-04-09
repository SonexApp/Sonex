
// Models.swift
// Sonex
//
// Shared models and enums generated from Supabase schema.
// All types conform to Codable for Supabase client serialization
// and Identifiable for SwiftUI list rendering.

import Foundation

// MARK: - Shared Typealiases

public typealias RecordID = UUID
public typealias UserID   = UUID

// MARK: - SUPPORTING TYPES

// MARK: PostGISPoint
// Supabase returns PostGIS geography as GeoJSON from .select()
// Use ST_AsGeoJSON() or the geography column directly depending on client config
public struct PostGISPoint: Codable, Hashable {
    let longitude: Double
    let latitude: Double

    // Decodes from GeoJSON: { "type": "Point", "coordinates": [lng, lat] }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: GeoJSONCodingKeys.self)
        let coordinates = try container.decode([Double].self, forKey: .coordinates)
        guard coordinates.count >= 2 else {
            throw DecodingError.dataCorruptedError(
                forKey: .coordinates,
                in: container,
                debugDescription: "Expected [longitude, latitude]"
            )
        }
        self.longitude = coordinates[0]
        self.latitude  = coordinates[1]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: GeoJSONCodingKeys.self)
        try container.encode("Point", forKey: .type)
        try container.encode([longitude, latitude], forKey: .coordinates)
    }

    private enum GeoJSONCodingKeys: String, CodingKey {
        case type, coordinates
    }
}

// MARK: AnyCodable
// Lightweight type-erased wrapper for jsonb metadata fields
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int    = try? container.decode(Int.self)    { value = int; return }
        if let double = try? container.decode(Double.self) { value = double; return }
        if let bool   = try? container.decode(Bool.self)   { value = bool; return }
        if let string = try? container.decode(String.self) { value = string; return }
        if let array  = try? container.decode([AnyCodable].self) { value = array.map(\.value); return }
        if let dict   = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value); return
        }
        value = NSNull()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Int:              try container.encode(v)
        case let v as Double:           try container.encode(v)
        case let v as Bool:             try container.encode(v)
        case let v as String:           try container.encode(v)
        case let v as [Any]:            try container.encode(v.map { AnyCodable($0) })
        case let v as [String: Any]:    try container.encode(v.mapValues { AnyCodable($0) })
        default:                        try container.encodeNil()
        }
    }
}


//payload structs

// MARK: - Payload Structs

struct UserProfilePayload: Encodable {
    var username: String
    var displayName: String?

    enum CodingKeys: String, CodingKey {
        case username
        case displayName = "display_name"
    }
}

struct ProfileUpdatePayload: Encodable {
    var username: String?
    var displayName: String?
    var avatarUrl: String?
    var bio: String?

    enum CodingKeys: String, CodingKey {
        case username
        case displayName = "display_name"
        case avatarUrl  = "avatar_url"
        case bio
    }
}

struct VinylEntryPayload: Encodable {
    var ownerId: String
    var title: String
    var artist: String
    var crateId: String
    var discogsId: String?
    var nfcTagHash: String?
    var label: String?
    var year: Int?
    var pressing: String?
    var format: String?
    var grade: String?
    var gradeNotes: String?
    var coverArtUrl: String?
    var audioNoteUrl: String?
    var forSale: Bool = false
    var askingPrice: Double?

    enum CodingKeys: String, CodingKey {
        case ownerId      = "owner_id"
        case title, artist
        case crateId      = "crate_id"
        case discogsId    = "discogs_id"
        case nfcTagHash   = "nfc_tag_hash"
        case label, year, pressing, format, grade
        case gradeNotes   = "grade_notes"
        case coverArtUrl  = "cover_art_url"
        case audioNoteUrl = "audio_note_url"
        case forSale      = "for_sale"
        case askingPrice  = "asking_price"
    }
}

