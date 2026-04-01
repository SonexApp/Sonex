
// Models.swift
// Sonex
//
// Shared models and enums generated from Supabase schema.
// All types conform to Codable for Supabase client serialization
// and Identifiable for SwiftUI list rendering.

import Foundation

// MARK: - Shared Typealiases

typealias RecordID = UUID
typealias UserID   = UUID

// MARK: - SUPPORTING TYPES

// MARK: PostGISPoint
// Supabase returns PostGIS geography as GeoJSON from .select()
// Use ST_AsGeoJSON() or the geography column directly depending on client config
struct PostGISPoint: Codable, Hashable {
    let longitude: Double
    let latitude: Double

    // Decodes from GeoJSON: { "type": "Point", "coordinates": [lng, lat] }
    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
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
        var container = encoder.container(keyedBy: _DynamicKey.self)
        _ = container // jsonb passthrough — override as needed
    }

    private struct _DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
}
