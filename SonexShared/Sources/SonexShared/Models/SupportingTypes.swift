
// Models.swift
// Sonex
//
// Shared models and enums generated from Supabase schema.
// All types conform to Codable for Supabase client serialization
// and Identifiable for SwiftUI list rendering.

import Foundation
import CoreLocation

// MARK: - Shared Typealiases

public typealias RecordID = UUID
public typealias UserID   = UUID
public typealias SonexLocation = PostGISPoint

// MARK: - SUPPORTING TYPES

// MARK: PostGISPoint
// Supabase returns PostGIS geography as GeoJSON from .select()
// Use ST_AsGeoJSON() or the geography column directly depending on client config
public struct PostGISPoint: Codable, Hashable {
    public let longitude: Double
    public let latitude: Double
    
    /// Create a new PostGISPoint with latitude and longitude
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    /// Create a new PostGISPoint from a CLLocationCoordinate2D
    public init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    /// Convert to CLLocationCoordinate2D for use with MapKit and CoreLocation
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

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
public struct AnyCodable: Codable, Equatable {
    let value: Any

    public init(_ value: Any) { self.value = value }

    public init(from decoder: Decoder) throws {
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

    public func encode(to encoder: Encoder) throws {
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
    
    // MARK: - Equatable Conformance
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (let lhsValue as Int, let rhsValue as Int):
            return lhsValue == rhsValue
        case (let lhsValue as Double, let rhsValue as Double):
            return lhsValue == rhsValue
        case (let lhsValue as Bool, let rhsValue as Bool):
            return lhsValue == rhsValue
        case (let lhsValue as String, let rhsValue as String):
            return lhsValue == rhsValue
        case (let lhsValue as [AnyCodable], let rhsValue as [AnyCodable]):
            return lhsValue == rhsValue
        case (let lhsValue as [String: AnyCodable], let rhsValue as [String: AnyCodable]):
            return lhsValue == rhsValue
        case (is NSNull, is NSNull):
            return true
        default:
            return false
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
    var address: String?
    var is_signature: Bool?

    enum CodingKeys: String, CodingKey {
        case username
        case displayName = "display_name"
        case avatarUrl  = "avatar_url"
        case bio
        case is_signature = "is_signature"
        case address
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

