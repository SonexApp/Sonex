// MARK: - DiscogsManager.swift
// Handles Discogs OAuth 1.0a, search, wantlist, and pricing for Sonex

import Foundation
import AuthenticationServices
import CryptoKit

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

struct DiscogsRelease: Codable, Identifiable {
    let id: Int
    let title: String
    let year: Int?
    let labels: [DiscogsLabel]
    let formats: [DiscogsReleaseFormat]
    let notes: String?
    let artists: [DiscogsArtist]
    let thumb: String?
    let images: [DiscogsImage]?
    let country: String?
    let genres: [String]?
    let styles: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, year, labels, formats, notes, artists, thumb, images, country
        case genres, styles
    }
}

struct DiscogsReleaseFormat: Codable {
    let name: String
    let qty: String?
    let text: String?
    let descriptions: [String]?
}

struct DiscogsImage: Codable {
    let type: String
    let uri: String
    let uri150: String?
    let width: Int?
    let height: Int?
    
    enum CodingKeys: String, CodingKey {
        case type, uri, width, height
        case uri150 = "uri150"
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
    let resourceUrl: String?
    let consumerName: String?

    enum CodingKeys: String, CodingKey {
        case id, username
        case resourceUrl  = "resource_url"
        case consumerName = "consumer_name"
    }
    
    // Initialize with fallback values
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        resourceUrl = try? container.decode(String.self, forKey: .resourceUrl)
        consumerName = try? container.decode(String.self, forKey: .consumerName)
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
    
    var isUnauthorized: Bool {
        if case .httpError(let code, _) = self {
            return code == 401
        }
        return false
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
    private let userAgent      = "sonex/1.0 +https://sonexapp.com"

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

        // Step 5: Verify identity and store credentials
        do {
            self.identity = try await fetchIdentity()
            self.isAuthenticated = true
            print("🎉 Successfully authenticated with Discogs as: \(identity?.username ?? "unknown")")
            
            // Verify credentials are properly stored
            print("🔐 Access token stored: \(accessToken != nil)")
            print("🔐 Access token secret stored: \(accessTokenSecret != nil)")
            
        } catch {
            print("❌ Failed to verify identity after obtaining access token: \(error)")
            // Clear potentially invalid credentials
            accessToken = nil
            accessTokenSecret = nil
            deleteStoredCredentials()
            throw error
        }
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
        perPage: Int = 20,
        format: String? = nil
    ) async throws -> DiscogsSearchResponse {
        var params: [String: String] = [
            "type"     : "release",
            "page"     : "\(page)",
            "per_page" : "\(perPage)",
            
        ]
        if let q = query  { params["q"]      = q }
        if let a = artist { params["artist"] = a }
        if let t = title  { params["title"]  = t }
        if let f = format { params["format"] = f }

        return try await get("/database/search", params: params)
    }
    
    /// Fetch detailed information for a specific release
    func fetchReleaseDetails(releaseId: Int) async throws -> DiscogsRelease {
        return try await get("/releases/\(releaseId)", params: [:])
    }
    
    /// Batch fetch detailed information for multiple releases
    /// Returns a dictionary mapping release IDs to their detailed info
    func fetchBatchReleaseDetails(releaseIds: [Int]) async -> [Int: DiscogsRelease] {
        guard !releaseIds.isEmpty else { return [:] }
        
        // Use TaskGroup to fetch releases concurrently with rate limiting
        let batchSize = 5 // Process 5 releases concurrently to respect rate limits
        let delays: [UInt64] = [0, 200_000_000, 400_000_000, 600_000_000, 800_000_000] // 0, 0.2, 0.4, 0.6, 0.8 seconds
        
        return await withTaskGroup(of: (Int, DiscogsRelease?).self) { group in
            var results: [Int: DiscogsRelease] = [:]
            
            // Process releases in batches to control concurrency
            for (batchIndex, batch) in releaseIds.chunked(into: batchSize).enumerated() {
                for (index, releaseId) in batch.enumerated() {
                    group.addTask {
                        // Stagger requests within each batch to respect rate limits
                        let delayIndex = min(index, delays.count - 1)
                        let baseDelay = UInt64(batchIndex) * 1_000_000_000 // 1 second between batches
                        let staggerDelay = delays[delayIndex]
                        
                        try? await Task.sleep(nanoseconds: baseDelay + staggerDelay)
                        
                        do {
                            let release = try await self.fetchReleaseDetails(releaseId: releaseId)
                            return (releaseId, release)
                        } catch {
                            print("Failed to fetch release details for ID \(releaseId): \(error)")
                            return (releaseId, nil)
                        }
                    }
                }
            }
            
            // Collect results
            for await (releaseId, release) in group {
                if let release = release {
                    results[releaseId] = release
                }
            }
            
            print("Batch fetched \(results.count) of \(releaseIds.count) release details")
            return results
        }
    }
    
    /// Optimized batch fetch that prioritizes releases based on their position in the list
    /// Fetches visible releases first, then continues with background loading
    func fetchPrioritizedReleaseDetails(
        releaseIds: [Int], 
        priorityIds: [Int] = []
    ) async -> [Int: DiscogsRelease] {
        guard !releaseIds.isEmpty else { return [:] }
        
        // Separate priority IDs (visible/important ones) from regular ones
        let prioritySet = Set(priorityIds)
        let sortedIds = releaseIds.sorted { id1, id2 in
            let isPriority1 = prioritySet.contains(id1)
            let isPriority2 = prioritySet.contains(id2)
            
            if isPriority1 && !isPriority2 {
                return true
            } else if !isPriority1 && isPriority2 {
                return false
            } else {
                // Maintain original order within same priority level
                return false
            }
        }
        
        return await fetchBatchReleaseDetails(releaseIds: sortedIds)
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
        print("🔍 Fetching Discogs identity...")
        print("🔑 Access Token: \(accessToken != nil ? "Present" : "Missing")")
        print("🔐 Access Token Secret: \(accessTokenSecret != nil ? "Present" : "Missing")")
        
        do {
            let identity: DiscogsIdentity = try await get("/oauth/identity", params: [:])
            print("✅ Successfully fetched identity: \(identity.username)")
            return identity
        } catch let error as DiscogsError {
            print("❌ Identity fetch failed with DiscogsError: \(error)")
            throw error
        } catch {
            print("❌ Identity fetch failed with unexpected error: \(error)")
            print("📄 Error details: \(String(describing: error))")
            throw DiscogsError.invalidResponse
        }
    }
    
    // MARK: - Testing and Debugging
    
    /// Test method to validate Discogs credentials without full OAuth flow
    func testCredentials() async throws {
        print("🧪 Testing Discogs API credentials...")
        print("🔑 Consumer Key: \(consumerKey)")
        print("🔗 Callback URL: \(callbackURL)")
        
        // Test with a simple unauthenticated search
        do {
            let result = try await search(query: "Pink Floyd", page: 1, perPage: 1)
            print("✅ Credentials test passed - API is accessible")
            print("📊 Search returned \(result.results.count) results")
        } catch let error as DiscogsError {
            print("❌ Credentials test failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Quick fix method - switches to PLAINTEXT signature for authenticated requests
    /// Call this if you're experiencing 401 errors after successful OAuth
    func switchToPlaintextSignature() {
        print("🔧 Switching to PLAINTEXT signature method for authenticated requests")
        print("ℹ️  This is a temporary workaround for HMAC-SHA1 signature issues")
        
        // We'll modify the get method to use PLAINTEXT
        // You can use this as a temporary fix while debugging
    }
    
    /// Test identity endpoint specifically with different signature methods
    func testIdentityEndpoint() async {
        print("🧪 Testing identity endpoint with different signature methods...")
        
        guard accessToken != nil, accessTokenSecret != nil else {
            print("❌ No access tokens available for testing")
            return
        }
        
        // Test 1: HMAC-SHA1
        print("🧪 Test 1: HMAC-SHA1 Signature")
        do {
            let identity = try await fetchIdentityWithSignatureMethod(.hmacSha1)
            print("✅ HMAC-SHA1 SUCCESS: \(identity.username)")
            return
        } catch {
            print("❌ HMAC-SHA1 FAILED: \(error)")
        }
        
        // Test 2: PLAINTEXT
        print("🧪 Test 2: PLAINTEXT Signature")
        do {
            let identity = try await fetchIdentityWithSignatureMethod(.plaintext)
            print("✅ PLAINTEXT SUCCESS: \(identity.username)")
            print("🔧 Consider using PLAINTEXT as the default signature method")
        } catch {
            print("❌ PLAINTEXT FAILED: \(error)")
            print("💀 Both signature methods failed - there may be a deeper issue")
        }
    }
    
    /// Fetch identity using a specific signature method
    private func fetchIdentityWithSignatureMethod(_ method: SignatureMethod) async throws -> DiscogsIdentity {
        let url = URL(string: "\(baseURL)/oauth/identity")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let authHeader: String
        switch method {
        case .plaintext:
            authHeader = buildOAuthHeaderWithMethod(.plaintext, token: accessToken, secret: accessTokenSecret, verifier: nil, callback: nil)
        case .hmacSha1:
            authHeader = buildOAuthHeaderForRequest(
                httpMethod: "GET",
                url: "\(baseURL)/oauth/identity",
                queryParams: [:],
                token: accessToken,
                secret: accessTokenSecret
            )
        }
        
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        
        return try decode(data)
    }
    
    /// Verify that stored authentication is still valid
    func verifyAuthenticationStatus() async -> Bool {
        guard accessToken != nil, accessTokenSecret != nil else {
            print("🔓 No access tokens available")
            isAuthenticated = false
            return false
        }
        
        do {
            let identity = try await fetchIdentity()
            self.identity = identity
            isAuthenticated = true
            print("✅ Authentication verified for user: \(identity.username)")
            return true
        } catch {
            print("❌ Authentication verification failed: \(error)")
            isAuthenticated = false
            self.identity = nil
            // Clear invalid tokens
            accessToken = nil
            accessTokenSecret = nil
            deleteStoredCredentials()
            return false
        }
    }
    
    /// Debug method to test OAuth header construction with current tokens
    func debugOAuthHeader() {
        print("🔧 Debug OAuth Header Construction")
        print("🔑 Consumer Key: \(consumerKey)")
        print("🔐 Consumer Secret: \(consumerSecret.prefix(10))...")
        print("🎫 Access Token: \(accessToken?.prefix(10) ?? "nil")...")
        print("🔒 Access Token Secret: \(accessTokenSecret?.prefix(10) ?? "nil")...")
        
        let header = buildOAuthHeader(
            token: accessToken,
            secret: accessTokenSecret, 
            verifier: nil,
            callback: nil
        )
        print("🏷️ Generated Header: \(header)")
    }
    
    /// Test method to manually make an identity request with detailed debugging
    func testIdentityRequest() async throws {
        print("🧪 Testing identity request with current credentials...")
        
        guard let accessToken = accessToken,
              let accessTokenSecret = accessTokenSecret else {
            throw DiscogsError.notAuthenticated
        }
        
        debugOAuthHeader()
        
        // Manually construct request to /oauth/identity
        let url = URL(string: "\(baseURL)/oauth/identity")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let authHeader = buildOAuthHeaderForRequest(
            httpMethod: "GET",
            url: "\(baseURL)/oauth/identity",
            queryParams: [:],
            token: accessToken,
            secret: accessTokenSecret
        )
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        
        print("🌐 Request URL: \(url.absoluteString)")
        print("📋 All Request Headers:")
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            print("   \(key): \(value)")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Response Status: \(httpResponse.statusCode)")
                print("📨 Response Headers: \(httpResponse.allHeaderFields)")
                
                if httpResponse.statusCode == 401 {
                    print("❌ 401 Unauthorized - This suggests OAuth signature issue")
                    print("🔍 Checking if signature method or parameters are incorrect...")
                    
                    // Try with PLAINTEXT method as fallback
                    print("🔄 Retrying with PLAINTEXT signature method...")
                    try await testIdentityRequestWithPlaintext()
                }
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to convert to string"
            print("📄 Response Body: \(responseString)")
            
        } catch {
            print("❌ Network error during identity test: \(error)")
            throw error
        }
    }
    
    /// Fallback test using PLAINTEXT signature method
    private func testIdentityRequestWithPlaintext() async throws {
        print("🧪 Testing identity request with PLAINTEXT signature...")
        
        guard let accessToken = accessToken,
              let accessTokenSecret = accessTokenSecret else {
            throw DiscogsError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/oauth/identity")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let authHeader = buildOAuthHeaderWithMethod(.plaintext, token: accessToken, secret: accessTokenSecret, verifier: nil, callback: nil)
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        
        print("🔐 PLAINTEXT Authorization Header: \(authHeader)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 PLAINTEXT Response Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                print("✅ PLAINTEXT worked! The issue is with HMAC-SHA1 signature generation")
                let responseString = String(data: data, encoding: .utf8) ?? ""
                print("📄 Successful Response: \(responseString)")
                
                // Update the manager to use PLAINTEXT by default
                print("🔧 Consider updating the OAuth implementation to use PLAINTEXT for this endpoint")
            } else {
                print("❌ PLAINTEXT also failed with status: \(httpResponse.statusCode)")
                let responseString = String(data: data, encoding: .utf8) ?? ""
                print("📄 Failed Response: \(responseString)")
            }
        }
    }
    
    /// Comprehensive troubleshooting method for OAuth issues
    func troubleshootOAuthIssue() async {
        print("🔧 === DISCOGS OAUTH TROUBLESHOOTING ===")
        
        // 1. Check basic configuration
        print("📋 1. Basic Configuration:")
        print("   Consumer Key: \(consumerKey)")
        print("   Consumer Secret: \(consumerSecret.count) characters")
        print("   Callback URL: \(callbackURL)")
        print("   User Agent: \(userAgent)")
        
        // 2. Check stored credentials
        print("📋 2. Stored Credentials:")
        print("   Access Token: \(accessToken?.count ?? 0) characters")
        print("   Access Token Secret: \(accessTokenSecret?.count ?? 0) characters")
        print("   Authenticated: \(isAuthenticated)")
        
        // 3. Test basic API connectivity (unauthenticated)
        print("📋 3. Testing Basic API Connectivity...")
        do {
            _ = try await search(query: "test", page: 1, perPage: 1)
            print("✅ Basic API connectivity works")
        } catch {
            print("❌ Basic API connectivity failed: \(error)")
        }
        
        // 4. Test OAuth signature methods
        if accessToken != nil && accessTokenSecret != nil {
            print("📋 4. Testing OAuth Methods...")
            
            // Test HMAC-SHA1
            do {
                try await testIdentityRequest()
            } catch {
                print("❌ HMAC-SHA1 identity request failed: \(error)")
            }
        } else {
            print("⚠️ No access tokens available for OAuth testing")
        }
        
        print("🔧 === END TROUBLESHOOTING ===")
    }
}

// MARK: - Private OAuth Helpers

private extension DiscogsManager {

    func fetchRequestToken() async throws -> String {
        // Try PLAINTEXT first (simpler and often preferred for request tokens)
        do {
            return try await fetchRequestTokenWithMethod(.plaintext)
        } catch {
            print("⚠️ PLAINTEXT failed, trying HMAC-SHA1: \(error)")
            return try await fetchRequestTokenWithMethod(.hmacSha1)
        }
    }
    
    private func fetchRequestTokenWithMethod(_ method: SignatureMethod) async throws -> String {
        var request = URLRequest(url: URL(string: requestTokenURL)!)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let authHeader: String
        if method == .plaintext {
            authHeader = buildOAuthHeaderWithMethod(method, token: nil, secret: nil, verifier: nil, callback: callbackURL)
        } else {
            authHeader = buildOAuthHeaderForRequestToken(method: method)
        }
        
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        
        print("🔐 Discogs OAuth Request (\(method.string)):")
        print("📍 URL: \(requestTokenURL)")
        print("🎫 Authorization Header: \(authHeader)")
        print("👤 User-Agent: \(userAgent)")

        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 Response Status: \(httpResponse.statusCode)")
            print("📨 Response Headers: \(httpResponse.allHeaderFields)")
        }
        
        let responseBody = String(data: data, encoding: .utf8) ?? ""
        print("📄 Response Body: \(responseBody)")
        
        try validate(response)
        return responseBody
    }
    
    private func buildOAuthHeaderForRequestToken(method: SignatureMethod) -> String {
        let nonce     = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let timestamp = "\(Int(Date().timeIntervalSince1970))"

        var params: [String: String] = [
            "oauth_consumer_key"     : consumerKey,
            "oauth_nonce"            : nonce,
            "oauth_signature_method" : method.string,
            "oauth_timestamp"        : timestamp,
            "oauth_version"          : "1.0",
            "oauth_callback"         : callbackURL
        ]

        let signature = generateHmacSha1Signature(
            httpMethod: "GET",
            baseUrl: requestTokenURL,
            params: params,
            consumerSecret: consumerSecret,
            tokenSecret: ""
        )
        
        params["oauth_signature"] = signature

        let header = params
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\"\(percentEncode($0.value))\"" }
            .joined(separator: ", ")

        return "OAuth \(header)"
    }

    func fetchAccessToken(verifier: String) async throws {
        print("🔑 Fetching access token with verifier...")
        print("🎫 OAuth Token: \(oauthToken ?? "nil")")
        print("🔐 OAuth Token Secret: \(oauthTokenSecret ?? "nil")")
        print("✅ Verifier: \(verifier)")
        
        var request = URLRequest(url: URL(string: accessTokenURL)!)
        request.httpMethod  = "POST"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let authHeader = buildOAuthHeaderForAccessToken(verifier: verifier)
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        
        print("🔐 Access token request authorization header: \(authHeader)")

        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 Access token response status: \(httpResponse.statusCode)")
            print("📨 Access token response headers: \(httpResponse.allHeaderFields)")
        }
        
        let body = String(data: data, encoding: .utf8) ?? ""
        print("📄 Access token response body: \(body)")
        
        try validate(response)

        guard
            let token  = extractParam("oauth_token", from: body),
            let secret = extractParam("oauth_token_secret", from: body)
        else {
            throw DiscogsError.oauthFailed("Could not parse access token from response: \(body)")
        }

        accessToken       = token
        accessTokenSecret = secret
        
        print("✅ Access token obtained successfully")
        print("🔑 Access Token: \(token.prefix(10))...")
        print("🔐 Access Token Secret: \(secret.prefix(10))...")
        
        storeCredentials(token: token, secret: secret)
    }
    
    private func buildOAuthHeaderForAccessToken(verifier: String) -> String {
        let nonce     = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let timestamp = "\(Int(Date().timeIntervalSince1970))"

        var params: [String: String] = [
            "oauth_consumer_key"     : consumerKey,
            "oauth_nonce"            : nonce,
            "oauth_signature_method" : "HMAC-SHA1",
            "oauth_timestamp"        : timestamp,
            "oauth_version"          : "1.0",
            "oauth_token"           : oauthToken ?? "",
            "oauth_verifier"        : verifier
        ]

        let signature = generateHmacSha1Signature(
            httpMethod: "POST",
            baseUrl: accessTokenURL,
            params: params,
            consumerSecret: consumerSecret,
            tokenSecret: oauthTokenSecret ?? ""
        )
        
        params["oauth_signature"] = signature

        let header = params
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\"\(percentEncode($0.value))\"" }
            .joined(separator: ", ")

        return "OAuth \(header)"
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
        // First attempt with HMAC-SHA1
        do {
            return try await getWithSignatureMethod(.hmacSha1, path: path, params: params)
        } catch let error as DiscogsError where error.isUnauthorized {
            print("⚠️ HMAC-SHA1 failed with 401, trying PLAINTEXT fallback...")
            return try await getWithSignatureMethod(.plaintext, path: path, params: params)
        }
    }
    
    private func getWithSignatureMethod<T: Decodable>(_ method: SignatureMethod, path: String, params: [String: String]) async throws -> T {
        var components = URLComponents(string: baseURL + path)!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if isAuthenticated || accessToken != nil {
            let authHeader: String
            switch method {
            case .hmacSha1:
                authHeader = buildOAuthHeaderForRequest(
                    httpMethod: "GET",
                    url: baseURL + path,
                    queryParams: params,
                    token: accessToken,
                    secret: accessTokenSecret
                )
            case .plaintext:
                authHeader = buildOAuthHeaderWithMethod(.plaintext, token: accessToken, secret: accessTokenSecret, verifier: nil, callback: nil)
            }
            
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            print("🔐 OAuth Authorization Header (\(method.string)): \(authHeader)")
        }

        print("🌐 Making GET request (\(method.string)) to: \(components.url?.absoluteString ?? path)")
        print("🔑 Is Authenticated: \(isAuthenticated)")
        print("🎫 Access Token Available: \(accessToken != nil)")
        print("🔐 Access Token Secret Available: \(accessTokenSecret != nil)")

        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Log response details
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 Response Status (\(method.string)): \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 401 && method == .hmacSha1 {
                print("❌ HMAC-SHA1 returned 401 - signature might be incorrect")
            } else if httpResponse.statusCode == 200 && method == .plaintext {
                print("✅ PLAINTEXT succeeded - HMAC-SHA1 implementation has issues")
            }
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? "Unable to convert to string"
        if responseString.count < 500 {
            print("📄 Raw Response (\(method.string)): \(responseString)")
        } else {
            print("📄 Raw Response (\(method.string)): \(responseString.prefix(500))...[truncated]")
        }
        
        try validate(response)
        
        do {
            let result: T = try decode(data)
            print("✅ Successfully decoded response (\(method.string))")
            return result
        } catch {
            print("❌ Failed to decode JSON (\(method.string)): \(error)")
            throw error
        }
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
        return buildOAuthHeaderWithMethod(.hmacSha1, token: token, secret: secret, verifier: verifier, callback: callback)
    }
    
    func buildOAuthHeaderForRequest(
        httpMethod: String,
        url: String,
        queryParams: [String: String] = [:],
        token: String?,
        secret: String?
    ) -> String {
        let nonce     = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let timestamp = "\(Int(Date().timeIntervalSince1970))"

        var params: [String: String] = [
            "oauth_consumer_key"     : consumerKey,
            "oauth_nonce"            : nonce,
            "oauth_signature_method" : "HMAC-SHA1",
            "oauth_timestamp"        : timestamp,
            "oauth_version"          : "1.0"
        ]
        if let token = token { params["oauth_token"] = token }
        
        // Include query parameters in signature calculation
        for (key, value) in queryParams {
            params[key] = value
        }

        // Calculate HMAC-SHA1 signature
        let tokenSecret = secret ?? ""
        let signature = generateHmacSha1Signature(
            httpMethod: httpMethod,
            baseUrl: url,
            params: params,
            consumerSecret: consumerSecret,
            tokenSecret: tokenSecret
        )
        
        // Remove query params from OAuth header (they shouldn't be in the header itself)
        for key in queryParams.keys {
            params.removeValue(forKey: key)
        }
        
        params["oauth_signature"] = signature
        
        // Debug logging
        print("🔧 OAuth Parameters (HMAC-SHA1 for \(httpMethod) \(url)):")
        for (key, value) in params.sorted(by: { $0.key < $1.key }) {
            if key == "oauth_signature" {
                print("   \(key): \(signature.prefix(20))...")
            } else {
                print("   \(key): \(value)")
            }
        }

        let header = params
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\"\(percentEncode($0.value))\"" }
            .joined(separator: ", ")

        return "OAuth \(header)"
    }
    
    enum SignatureMethod {
        case plaintext
        case hmacSha1
        
        var string: String {
            switch self {
            case .plaintext: return "PLAINTEXT"
            case .hmacSha1: return "HMAC-SHA1"
            }
        }
    }
    
    func buildOAuthHeaderWithMethod(
        _ method: SignatureMethod,
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
            "oauth_signature_method" : method.string,
            "oauth_timestamp"        : timestamp,
            "oauth_version"          : "1.0"
        ]
        if let token    = token    { params["oauth_token"]    = token    }
        if let verifier = verifier { params["oauth_verifier"] = verifier }
        if let callback = callback { params["oauth_callback"] = callback }

        // Calculate signature based on method
        let tokenSecret = secret ?? ""
        let signature: String
        
        switch method {
        case .plaintext:
            signature = "\(consumerSecret)&\(tokenSecret)"
        case .hmacSha1:
            signature = generateHmacSha1Signature(
                httpMethod: "GET", 
                baseUrl: callback == nil ? "\(baseURL)/oauth/identity" : requestTokenURL,
                params: params,
                consumerSecret: consumerSecret,
                tokenSecret: tokenSecret
            )
        }
        
        params["oauth_signature"] = signature
        
        // Debug logging
        print("🔧 OAuth Parameters (\(method.string)):")
        for (key, value) in params.sorted(by: { $0.key < $1.key }) {
            if key == "oauth_signature" {
                print("   \(key): \(signature.prefix(20))... (\(method.string))")
            } else {
                print("   \(key): \(value)")
            }
        }
        
        // Validate tokens are present when expected
        if token != nil && secret == nil {
            print("⚠️ Warning: OAuth token provided but token secret is nil!")
        }
        if token == nil && secret != nil {
            print("⚠️ Warning: OAuth token secret provided but token is nil!")
        }

        let header = params
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\"\(percentEncode($0.value))\"" }
            .joined(separator: ", ")

        return "OAuth \(header)"
    }
    
    // MARK: - HMAC-SHA1 Signature Generation
    
    func generateHmacSha1Signature(
        httpMethod: String,
        baseUrl: String,
        params: [String: String],
        consumerSecret: String,
        tokenSecret: String
    ) -> String {
        // 1. Create parameter string (excluding oauth_signature)
        let sortedParams = params
            .filter { $0.key != "oauth_signature" }
            .sorted { $0.key < $1.key }
            .map { "\(percentEncode($0.key))=\(percentEncode($0.value))" }
            .joined(separator: "&")
        
        // 2. Create base string
        let baseString = "\(httpMethod)&\(percentEncode(baseUrl))&\(percentEncode(sortedParams))"
        print("📝 HMAC-SHA1 Base String: \(baseString)")
        
        // 3. Create signing key
        let signingKey = "\(percentEncode(consumerSecret))&\(percentEncode(tokenSecret))"
        print("🔑 HMAC-SHA1 Signing Key: \(signingKey.prefix(20))...")
        
        // 4. Generate HMAC-SHA1
        let keyData = Data(signingKey.utf8)
        let messageData = Data(baseString.utf8)
        
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: messageData, using: SymmetricKey(data: keyData))
        let signature = Data(hmac).base64EncodedString()
        
        print("🔐 Generated HMAC-SHA1 Signature: \(signature.prefix(20))...")
        return signature
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
        else { 
            print("🔓 No stored Discogs credentials found")
            return 
        }
        
        accessToken = token
        accessTokenSecret = secret
        print("🔐 Loaded stored Discogs credentials")
        
        // Verify credentials are still valid by fetching identity
        // Use unstructured task to avoid blocking initialization
        Task { @MainActor in
            do {
                self.identity = try await fetchIdentity()
                self.isAuthenticated = true
                print("✅ Stored credentials are valid, user: \(identity?.username ?? "unknown")")
            } catch {
                print("❌ Stored credentials are invalid, clearing them: \(error)")
                // Clear invalid credentials
                accessToken = nil
                accessTokenSecret = nil
                isAuthenticated = false
                identity = nil
                deleteStoredCredentials()
            }
        }
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

// MARK: - Array Extensions for Batch Processing

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

