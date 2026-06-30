//
//  MusicBrainzAPIManager.swift
//  Sonex
//
//  Created by Assistant on 4/12/26.
//

import Foundation

@Observable
class MusicBrainzAPIManager {
    static let shared = MusicBrainzAPIManager()
    
    private let baseURL = "https://musicbrainz.org/ws/2"
    private let userAgent = "Sonex/1.0 (contact@sonexapp.com)"
    
    private init() {}
    
    // MARK: - Search Methods
    
    func searchArtists(query: String) async throws -> [MusicBrainzArtist] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/artist?query=artist:\(encodedQuery)&fmt=json&limit=10"
        
        guard let url = URL(string: urlString) else {
            throw MusicBrainzError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MusicBrainzError.networkError
        }
        
        let searchResult = try JSONDecoder().decode(MusicBrainzArtistSearchResult.self, from: data)
        return searchResult.artists
    }
    
    func searchReleases(artist: String, title: String) async throws -> [MusicBrainzRelease] {
        guard !artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/release?query=artist:\(encodedArtist)%20AND%20release:\(encodedTitle)&fmt=json&limit=10"
        
        guard let url = URL(string: urlString) else {
            throw MusicBrainzError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MusicBrainzError.networkError
        }
        
        let searchResult = try JSONDecoder().decode(MusicBrainzReleaseSearchResult.self, from: data)
        return searchResult.releases
    }
    
    func searchAlbumTitles(artist: String, titleQuery: String) async throws -> [MusicBrainzRelease] {
        guard !artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !titleQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedTitle = titleQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/release?query=artist:\(encodedArtist)%20AND%20release:\(encodedTitle)*&fmt=json&limit=8"
        
        guard let url = URL(string: urlString) else {
            throw MusicBrainzError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MusicBrainzError.networkError
        }
        
        let searchResult = try JSONDecoder().decode(MusicBrainzReleaseSearchResult.self, from: data)
        
        // Remove duplicates by title and sort by relevance
        var uniqueTitles = Set<String>()
        var uniqueReleases: [MusicBrainzRelease] = []
        
        for release in searchResult.releases {
            let title = release.title.lowercased()
            if !uniqueTitles.contains(title) {
                uniqueTitles.insert(title)
                uniqueReleases.append(release)
            }
        }
        
        return uniqueReleases
    }
    
    func getReleaseDetails(releaseId: String) async throws -> MusicBrainzReleaseDetail {
        let urlString = "\(baseURL)/release/\(releaseId)?inc=artist-credits+labels+recordings+media&fmt=json"
        
        guard let url = URL(string: urlString) else {
            throw MusicBrainzError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MusicBrainzError.networkError
        }
        
        return try JSONDecoder().decode(MusicBrainzReleaseDetail.self, from: data)
    }
    
    func getCoverArtURL(releaseId: String) async throws -> String? {
        let urlString = "https://coverartarchive.org/release/\(releaseId)/front"
        
        guard let url = URL(string: urlString) else {
            throw MusicBrainzError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 200 {
            return urlString
        }
        
        return nil
    }
}

// MARK: - Data Models

struct MusicBrainzArtist: Codable, Identifiable {
    let id: String
    let name: String
    let disambiguation: String?
    
    var displayName: String {
        if let disambiguation = disambiguation, !disambiguation.isEmpty {
            return "\(name) (\(disambiguation))"
        }
        return name
    }
}

struct MusicBrainzArtistSearchResult: Codable {
    let artists: [MusicBrainzArtist]
}

struct MusicBrainzRelease: Codable, Identifiable {
    let id: String
    let title: String
    let date: String?
    let country: String?
    let labelInfo: [MusicBrainzLabelInfo]?
    let artistCredit: [MusicBrainzArtistCredit]
    let textRepresentation: MusicBrainzTextRepresentation?
    let barcode: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, date, country, barcode
        case labelInfo = "label-info"
        case artistCredit = "artist-credit"
        case textRepresentation = "text-representation"
    }
    
    var artistName: String {
        return artistCredit.first?.name ?? "Unknown Artist"
    }
    
    var year: Int? {
        guard let date = date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let fullDate = formatter.date(from: date) {
            return Calendar.current.component(.year, from: fullDate)
        }
        // Try just year format
        if let year = Int(String(date.prefix(4))) {
            return year
        }
        return nil
    }
    
    var labelName: String? {
        return labelInfo?.first?.label?.name
    }
}

struct MusicBrainzReleaseSearchResult: Codable {
    let releases: [MusicBrainzRelease]
}

struct MusicBrainzReleaseDetail: Codable {
    let id: String
    let title: String
    let date: String?
    let country: String?
    let labelInfo: [MusicBrainzLabelInfo]?
    let artistCredit: [MusicBrainzArtistCredit]
    let textRepresentation: MusicBrainzTextRepresentation?
    let barcode: String?
    let media: [MusicBrainzMedia]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, date, country, barcode, media
        case labelInfo = "label-info"
        case artistCredit = "artist-credit"
        case textRepresentation = "text-representation"
    }
}

struct MusicBrainzArtistCredit: Codable {
    let name: String
    let artist: MusicBrainzArtist?
}

struct MusicBrainzLabelInfo: Codable {
    let label: MusicBrainzLabel?
    let catalogNumber: String?
    
    enum CodingKeys: String, CodingKey {
        case label
        case catalogNumber = "catalog-number"
    }
}

struct MusicBrainzLabel: Codable {
    let id: String
    let name: String
}

struct MusicBrainzTextRepresentation: Codable {
    let language: String?
    let script: String?
}

struct MusicBrainzMedia: Codable {
    let format: String?
    let trackCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case format
        case trackCount = "track-count"
    }
}

enum MusicBrainzError: Error, LocalizedError {
    case invalidURL
    case networkError
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network error occurred"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}
