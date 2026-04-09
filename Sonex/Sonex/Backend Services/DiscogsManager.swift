// MARK: - DiscogsManager.swift
// Handles Discogs OAuth 1.0a, search, wantlist, and pricing for Sonex

import Foundation
import AuthenticationServices

// MARK: - Discogs Models

struct DiscogsSearchResult: Codable, Identifiable {
    let id: Int
    let title: String
    let type: String
    let year: String?
    let label: [String]?
    let format: [String]?
    let coverImage: String?
    let thumb: String?
    let country: String?
    let genre: [String]?
    let style: [String]?
    let uri: String?
    let masterId: Int?
    let masterUrl: String?
    let resourceUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, title, type, year, label, format, country, genre, style, uri
        case coverImage  = "cover_image"
        case thumb
        case masterId    = "master_id"
        case masterUrl   = "master_url"
        case resourceUrl = "resource_url"
    }
}

struct DiscogsSearchResponse: Codable {
    let results: [DiscogsSearchResult]
    let pagination: DiscogsPagination
}

struct DiscogsPagination: Codable {
    let page: Int
    let pages: Int
    let perPage: Int
    let items: Int

    enum CodingKeys: String, CodingKey {
        case page, pages, items
        case perPage = "per_page"
    }
}

struct DiscogsPriceSuggestion: Codable {
    let veryGoodPlus: PriceEntry?
    let nearMint: PriceEntry?
    let veryGood: PriceEntry?
    let good: PriceEntry?

    enum CodingKeys: String, CodingKey {
        case veryGoodPlus = "Very Good Plus (VG+)"
        case nearMint     = "Near Mint (NM or M-)"
        case veryGood     = "Very Good (VG)"
        case good         = "Good (G)"
    }
}

struct PriceEntry: Codable {
    let currency: String
    let value: Double
}

struct DiscogsWantlistItem: Codable, Identifiable {
    let id: Int
    let rating: Int
    let notes: String?
    let basicInformation: DiscogsBasicInfo

    enum CodingKeys: String, CodingKey {
        case id, rating, notes
        case basicInformation = "basic_information"
    }
}

struct DiscogsBasicInfo: Codable {
    let id: Int
    let title: String
    let year: Int
    let thumb: String?
    let coverImage: String?
    let labels: [DiscogsLabel]
    let artists: [DiscogsArtist]
    let formats: [DiscogsFormat]

    enum CodingKeys: String, CodingKey {
        case id, title, year, thumb, labels, artists, formats
        case coverImage = "cover_image"
    }
}

struct DiscogsLabel: Codable {
    let name: String
    let catno: String?
}

struct DiscogsArtist: Codable {
    let name: String
    let id: Int
}

struct DiscogsFormat: Codable {
    let name: String
    let qty: String?
    let descriptions: [String]?
}

struct DiscogsWantlistResponse: Codable {
    let wants: [DiscogsWantlistItem]
    let pagination: DiscogsPagination
}

struct DiscogsIdentity: Codable {
    let id: Int
    let username: String
    let resourceUrl: String
    let consumerName: String

    enum CodingKeys: String, CodingKey {
        case id, username
        case resourceUrl  = "resource_url"
        case consumerName = "consumer_name"
    }
}

// MARK: - Discogs Error

enum DiscogsError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case httpError(Int, String)
    case oauthFailed(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:        return "Please connect your Discogs account."
        case .invalidResponse:         return "Unexpected response from Discogs."
        case .httpError(let c, let m): return "Discogs error \(c): \(m)"
        case .oauthFailed(let m):      return "OAuth failed: \(m)"
        case .decodingFailed(let m):   return "Could not parse response: \(m)"
        }
    }
}

// MARK: - DiscogsManager

@MainActor
@Observable
class DiscogsManager: NSObject {

    static let shared = DiscogsManager()

    // MARK: - Config
    // Register your app at https://www.discogs.com/settings/developers
    private let consumerKey    = "LsNnsEsXoBQiMHSAyenU"
    private let consumerSecret = "aQSGgrDBNhTxKmTiXgXhyYusnYCjbyVP"
    private let callbackScheme = "sonex"                          // must match URL scheme in Info.plist
    private let callbackURL    = "sonex://discogs/callback"

    private let baseURL        = "https://api.discogs.com"
    private let requestTokenURL = "https://api.discogs.com/oauth/request_token"
    private let authorizeURL   = "https://www.discogs.com/oauth/authorize"
    private let accessTokenURL  = "https://api.discogs.com/oauth/access_token"
    private let userAgent      = "Sonex/1.0 +https://sonexapp.com"

    // MARK: - State

    private(set) var isAuthenticated: Bool = false
    private(set) var identity: DiscogsIdentity?

    private var oauthToken: String?
    private var oauthTokenSecret: String?
    private var accessToken: String?
    private var accessTokenSecret: String?

    // Keychain keys
    private let keychainAccessToken       = "discogs_access_token"
    private let keychainAccessTokenSecret = "discogs_access_token_secret"

    // ASWebAuthentication session — must be held strongly
    private var authSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
        loadStoredCredentials()
    }

    // MARK: - OAuth 1.0a Sign In

    func signIn() async throws {
        // Step 1: Get request token
        let requestTokenResponse = try await fetchRequestToken()
        guard
            let token  = extractParam("oauth_token", from: requestTokenResponse),
            let secret = extractParam("oauth_token_secret", from: requestTokenResponse)
        else {
            throw DiscogsError.oauthFailed("Could not parse request token.")
        }

        self.oauthToken       = token
        self.oauthTokenSecret = secret

        // Step 2: Open Discogs authorization page
        let authorizeURLWithToken = "\(authorizeURL)?oauth_token=\(token)"
        guard let url = URL(string: authorizeURLWithToken) else {
            throw DiscogsError.oauthFailed("Invalid authorize URL.")
        }

        let callbackFull = try await openAuthSession(url: url)

        // Step 3: Extract verifier from callback
        guard
            let components = URLComponents(url: callbackFull, resolvingAgainstBaseURL: false),
            let verifier   = components.queryItems?.first(where: { $0.name == "oauth_verifier" })?.value
        else {
            throw DiscogsError.oauthFailed("No verifier in callback.")
        }

        // Step 4: Exchange verifier for access token
        try await fetchAccessToken(verifier: verifier)

        // Step 5: Verify identity
        self.identity         = try await fetchIdentity()
        self.isAuthenticated  = true
    }

    func signOut() {
        accessToken       = nil
        accessTokenSecret = nil
        oauthToken        = nil
        oauthTokenSecret  = nil
        identity          = nil
        isAuthenticated   = false
        deleteStoredCredentials()
    }

    // MARK: - Search

    /// Search by album title, artist name, or both.
    func search(
        query: String? = nil,
        artist: String? = nil,
        title: String? = nil,
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> DiscogsSearchResponse {
        var params: [String: String] = [
            "type"     : "release",
            "page"     : "\(page)",
            "per_page" : "\(perPage)"
        ]
        if let q = query  { params["q"]      = q }
        if let a = artist { params["artist"] = a }
        if let t = title  { params["title"]  = t }

        return try await get("/database/search", params: params)
    }

    // MARK: - Wantlist

    func fetchWantlist(page: Int = 1, perPage: Int = 50) async throws -> DiscogsWantlistResponse {
        guard let username = identity?.username else { throw DiscogsError.notAuthenticated }
        return try await get("/users/\(username)/wants",
                             params: ["page": "\(page)", "per_page": "\(perPage)"])
    }

    func addToWantlist(releaseId: Int, notes: String? = nil, rating: Int = 0) async throws {
        guard let username = identity?.username else { throw DiscogsError.notAuthenticated }

        struct WantlistPayload: Encodable {
            let notes: String?
            let rating: Int
        }

        try await put(
            "/users/\(username)/wants/\(releaseId)",
            body: WantlistPayload(notes: notes, rating: rating)
        )
    }

    func removeFromWantlist(releaseId: Int) async throws {
        guard let username = identity?.username else { throw DiscogsError.notAuthenticated }
        try await delete("/users/\(username)/wants/\(releaseId)")
    }

    // MARK: - Price Suggestions

    /// Requires Discogs authentication. Returns suggested prices per condition grade.
    func fetchPriceSuggestions(releaseId: Int) async throws -> DiscogsPriceSuggestion {
        return try await get("/marketplace/price_suggestions/\(releaseId)", params: [:])
    }

    // MARK: - Identity

    func fetchIdentity() async throws -> DiscogsIdentity {
        return try await get("/oauth/identity", params: [:])
    }
}

// MARK: - Private OAuth Helpers

private extension DiscogsManager {

    func fetchRequestToken() async throws -> String {
        var request = URLRequest(url: URL(string: requestTokenURL)!)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(
            buildOAuthHeader(token: nil, secret: nil, verifier: nil, callback: callbackURL),
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return String(data: data, encoding: .utf8) ?? ""
    }

    func fetchAccessToken(verifier: String) async throws {
        var request = URLRequest(url: URL(string: accessTokenURL)!)
        request.httpMethod  = "POST"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(
            buildOAuthHeader(token: oauthToken, secret: oauthTokenSecret, verifier: verifier, callback: nil),
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)

        let body = String(data: data, encoding: .utf8) ?? ""
        guard
            let token  = extractParam("oauth_token", from: body),
            let secret = extractParam("oauth_token_secret", from: body)
        else {
            throw DiscogsError.oauthFailed("Could not parse access token.")
        }

        accessToken       = token
        accessTokenSecret = secret
        storeCredentials(token: token, secret: secret)
    }

    func openAuthSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: DiscogsError.oauthFailed(error.localizedDescription))
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: DiscogsError.oauthFailed("No callback URL received."))
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session
            session.start()
        }
    }

    // MARK: - Request Builders

    func get<T: Decodable>(_ path: String, params: [String: String]) async throws -> T {
        var components = URLComponents(string: baseURL + path)!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if isAuthenticated {
            request.setValue(
                buildOAuthHeader(token: accessToken, secret: accessTokenSecret, verifier: nil, callback: nil),
                forHTTPHeaderField: "Authorization"
            )
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try decode(data)
    }

    func put<B: Encodable>(_ path: String, body: B) async throws {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod   = "PUT"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            buildOAuthHeader(token: accessToken, secret: accessTokenSecret, verifier: nil, callback: nil),
            forHTTPHeaderField: "Authorization"
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response)
    }

    func delete(_ path: String) async throws {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "DELETE"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(
            buildOAuthHeader(token: accessToken, secret: accessTokenSecret, verifier: nil, callback: nil),
            forHTTPHeaderField: "Authorization"
        )

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response)
    }

    // MARK: - OAuth 1.0a Header Builder

    func buildOAuthHeader(
        token: String?,
        secret: String?,
        verifier: String?,
        callback: String?
    ) -> String {
        let nonce     = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let timestamp = "\(Int(Date().timeIntervalSince1970))"

        var params: [String: String] = [
            "oauth_consumer_key"     : consumerKey,
            "oauth_nonce"            : nonce,
            "oauth_signature_method" : "PLAINTEXT",
            "oauth_timestamp"        : timestamp,
            "oauth_version"          : "1.0"
        ]
        if let token    = token    { params["oauth_token"]    = token    }
        if let verifier = verifier { params["oauth_verifier"] = verifier }
        if let callback = callback { params["oauth_callback"] = callback }

        // PLAINTEXT signature: consumerSecret&tokenSecret
        let tokenSecret = secret ?? ""
        params["oauth_signature"] = "\(consumerSecret)&\(tokenSecret)"

        let header = params
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\"\(percentEncode($0.value))\"" }
            .joined(separator: ", ")

        return "OAuth \(header)"
    }

    // MARK: - Utilities

    func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw DiscogsError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw DiscogsError.httpError(http.statusCode, HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }
    }

    func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw DiscogsError.decodingFailed(error.localizedDescription)
        }
    }

    func extractParam(_ key: String, from body: String) -> String? {
        body.components(separatedBy: "&")
            .first { $0.hasPrefix("\(key)=") }
            .flatMap { $0.components(separatedBy: "=").last }
    }

    func percentEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .init(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")) ?? string
    }

    // MARK: - Keychain Persistence

    func storeCredentials(token: String, secret: String) {
        KeychainHelper.save(key: keychainAccessToken,       value: token)
        KeychainHelper.save(key: keychainAccessTokenSecret, value: secret)
    }

    func loadStoredCredentials() {
        guard
            let token  = KeychainHelper.load(key: keychainAccessToken),
            let secret = KeychainHelper.load(key: keychainAccessTokenSecret)
        else { return }
        accessToken       = token
        accessTokenSecret = secret
        isAuthenticated   = true
        Task { self.identity = try? await fetchIdentity() }
    }

    func deleteStoredCredentials() {
        KeychainHelper.delete(key: keychainAccessToken)
        KeychainHelper.delete(key: keychainAccessTokenSecret)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension DiscogsManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}

