
import SwiftUI
import Supabase
import SonexShared
import Foundation
import Network

struct UserProfilePayload: Encodable {
    var username: String
    var displayName: String?
    var user_id: String

    enum CodingKeys: String, CodingKey {
        case username
        case displayName = "display_name"
        case user_id = "user_id"
    }
}

struct ProfileUpdatePayload: Codable {
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

// MARK: - Offline Cache Manager
@MainActor
class OfflineCacheManager {
    static let shared = OfflineCacheManager()
    
    private let userDefaults = UserDefaults.standard
    private let documentsDirectory: URL
    
    private init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // MARK: - Cache Keys
    private enum CacheKeys {
        static let userProfile = "cached_user_profile"
        static let crates = "cached_crates"
        static let cratesTimestamp = "cached_crates_timestamp"
        static let unsortedCrateId = "cached_unsorted_crate_id"
        static let forSaleCrateId = "cached_for_sale_crate_id"
        static let wishlistCrateId = "cached_wishlist_crate_id"
        static let lastSyncTimestamp = "last_sync_timestamp"
        static let pendingOperations = "pending_operations"
    }
    
    // MARK: - User Profile Cache
    func cacheUserProfile(_ profile: SonexUser) {
        if let data = try? JSONEncoder().encode(profile) {
            userDefaults.set(data, forKey: CacheKeys.userProfile)
        }
    }
    
    func getCachedUserProfile() -> SonexUser? {
        guard let data = userDefaults.data(forKey: CacheKeys.userProfile),
              let profile = try? JSONDecoder().decode(SonexUser.self, from: data) else {
            return nil
        }
        return profile
    }
    
    func clearCachedUserProfile() {
        userDefaults.removeObject(forKey: CacheKeys.userProfile)
    }
    
    // MARK: - Crates Cache
    func cacheCrates(_ crates: [Crate]) {
        if let data = try? JSONEncoder().encode(crates) {
            userDefaults.set(data, forKey: CacheKeys.crates)
            userDefaults.set(Date(), forKey: CacheKeys.cratesTimestamp)
        }
    }
    
    func getCachedCrates() -> [Crate]? {
        guard let data = userDefaults.data(forKey: CacheKeys.crates),
              let crates = try? JSONDecoder().decode([Crate].self, from: data) else {
            return nil
        }
        return crates
    }
    
    func getCratesCacheTimestamp() -> Date? {
        return userDefaults.object(forKey: CacheKeys.cratesTimestamp) as? Date
    }
    
    func clearCachedCrates() {
        userDefaults.removeObject(forKey: CacheKeys.crates)
        userDefaults.removeObject(forKey: CacheKeys.cratesTimestamp)
    }
    
    // MARK: - Special Crate IDs Cache
    func cacheSpecialCrateIds(unsorted: String? = nil, forSale: String? = nil, wishlist: String? = nil) {
        if let unsorted = unsorted {
            userDefaults.set(unsorted, forKey: CacheKeys.unsortedCrateId)
        }
        if let forSale = forSale {
            userDefaults.set(forSale, forKey: CacheKeys.forSaleCrateId)
        }
        if let wishlist = wishlist {
            userDefaults.set(wishlist, forKey: CacheKeys.wishlistCrateId)
        }
    }
    
    func getCachedUnsortedCrateId() -> String? {
        return userDefaults.string(forKey: CacheKeys.unsortedCrateId)
    }
    
    func getCachedForSaleCrateId() -> String? {
        return userDefaults.string(forKey: CacheKeys.forSaleCrateId)
    }
    
    func getCachedWishlistCrateId() -> String? {
        return userDefaults.string(forKey: CacheKeys.wishlistCrateId)
    }
    
    func clearSpecialCrateIds() {
        userDefaults.removeObject(forKey: CacheKeys.unsortedCrateId)
        userDefaults.removeObject(forKey: CacheKeys.forSaleCrateId)
        userDefaults.removeObject(forKey: CacheKeys.wishlistCrateId)
    }
    
    // MARK: - Pending Operations Queue
    func addPendingOperation(_ operation: PendingOperation) {
        var operations = getPendingOperations()
        operations.append(operation)
        if let data = try? JSONEncoder().encode(operations) {
            userDefaults.set(data, forKey: CacheKeys.pendingOperations)
        }
    }
    
    func getPendingOperations() -> [PendingOperation] {
        guard let data = userDefaults.data(forKey: CacheKeys.pendingOperations),
              let operations = try? JSONDecoder().decode([PendingOperation].self, from: data) else {
            return []
        }
        return operations
    }
    
    func removePendingOperation(_ operation: PendingOperation) {
        var operations = getPendingOperations()
        operations.removeAll { $0.id == operation.id }
        if let data = try? JSONEncoder().encode(operations) {
            userDefaults.set(data, forKey: CacheKeys.pendingOperations)
        }
    }
    
    func clearPendingOperations() {
        userDefaults.removeObject(forKey: CacheKeys.pendingOperations)
    }
    
    // MARK: - Sync Timestamp
    func updateLastSyncTimestamp() {
        userDefaults.set(Date(), forKey: CacheKeys.lastSyncTimestamp)
    }
    
    func getLastSyncTimestamp() -> Date? {
        return userDefaults.object(forKey: CacheKeys.lastSyncTimestamp) as? Date
    }
    
    // MARK: - Clear All Cache
    func clearAllCache() {
        clearCachedUserProfile()
        clearCachedCrates()
        clearSpecialCrateIds()
        clearPendingOperations()
        userDefaults.removeObject(forKey: CacheKeys.lastSyncTimestamp)
    }
}

// MARK: - Pending Operation Models
struct PendingOperation: Codable, Identifiable {
    let id = UUID()
    let type: OperationType
    let timestamp: Date
    let data: Data
    
    enum OperationType: String, Codable {
        case createCrate
        case updateProfile
        case createVinyl
        case updateVinyl
        case deleteVinyl
        case moveVinyl
    }
}

@MainActor
@Observable
class SonexDBManager {
    static let shared = SonexDBManager()
    private let supabase: SupabaseClient
    private let cacheManager = OfflineCacheManager.shared
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    // Session cache
    private(set) var currentSession: Session?
    private(set) var isAuthenticated: Bool = false
    private(set) var isOnline: Bool = false
    
    /// Resolves (and caches) the user's Unsorted crate ID.
    /// Used internally during vinyl registration.
    private var _unsortedCrateId: String?
    private var _forSaleCrateId: String?
    private var _wishlistCrateId: String?
    
    // Crates cache
    private var _cachedCrates: [Crate]?
    private var _cratesCacheTimestamp: Date?
    private let cratesCacheExpirationInterval: TimeInterval = 300 // 5 minutes
    
    // User profile cache
    private var _cachedUserProfile: SonexUser?
    private var _userProfileCacheTimestamp: Date?
    private let userProfileCacheExpirationInterval: TimeInterval = 600 // 10 minutes
    
    private init() {
        supabase = SupabaseClient(supabaseURL: URL(string: "https://bbjtznnxrreuzurgtuyz.supabase.co")!, supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJianR6bm54cnJldXp1cmd0dXl6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5ODMzMTksImV4cCI6MjA5MDU1OTMxOX0.hrHqnA_rlEc51OROgU0ALAqRCjzWcPYGEj7UaP56qYc"
        )
        print("Supabase client initialized with url")
        
        // Start network monitoring
        startNetworkMonitoring()
        
        // Load cached data on startup
        loadCachedData()
        
        // Check for existing session
        Task {
            await checkCurrentSession()
        }
        
        // Listen for auth state changes
        Task {
            await listenToAuthChanges()
        }
        
        // Process pending operations when online
        Task {
            await processPendingOperationsIfOnline()
        }
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = path.status == .satisfied
                
                // If we just came online, process pending operations
                if !wasOnline && self?.isOnline == true {
                    await self?.processPendingOperationsIfOnline()
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    // MARK: - Cache Management
    
    private func loadCachedData() {
        // Load cached special crate IDs
        _unsortedCrateId = cacheManager.getCachedUnsortedCrateId()
        _forSaleCrateId = cacheManager.getCachedForSaleCrateId()
        _wishlistCrateId = cacheManager.getCachedWishlistCrateId()
        
        // Load cached crates
        if let cachedCrates = cacheManager.getCachedCrates() {
            _cachedCrates = cachedCrates
            _cratesCacheTimestamp = cacheManager.getCratesCacheTimestamp()
        }
        
        // Load cached user profile
        if let cachedProfile = cacheManager.getCachedUserProfile() {
            _cachedUserProfile = cachedProfile
            _userProfileCacheTimestamp = Date() // Assume recent for offline access
        }
    }
    
    private func processPendingOperationsIfOnline() async {
        guard isOnline else { return }
        
        let pendingOperations = cacheManager.getPendingOperations()
        
        for operation in pendingOperations {
            do {
                try await processPendingOperation(operation)
                cacheManager.removePendingOperation(operation)
            } catch {
                print("Failed to process pending operation: \(error)")
                // Keep the operation for retry later
                break
            }
        }
        
        // Update sync timestamp if all operations processed
        if cacheManager.getPendingOperations().isEmpty {
            cacheManager.updateLastSyncTimestamp()
        }
    }
    
    private func processPendingOperation(_ operation: PendingOperation) async throws {
        switch operation.type {
        case .createCrate:
            // Decode and process create crate operation
            struct CreateCratePayload: Codable {
                let name: String
                let sortOrder: Int
                let forSale: Bool
                let tempId: String
            }
            
            if let payload = try? JSONDecoder().decode(CreateCratePayload.self, from: operation.data) {
                _ = try await createCrate(named: payload.name, sortOrder: payload.sortOrder, forSale: payload.forSale)
            }
            
        case .updateProfile:
            // Decode and process profile update operation
            if let payload = try? JSONDecoder().decode(ProfileUpdatePayload.self, from: operation.data) {
                try await updateProfileOnServer(payload)
            }
            
        case .createVinyl:
            // Decode and process create vinyl operation
            if let payload = try? JSONDecoder().decode(VinylEntry.self, from: operation.data) {
                let vinyl: VinylEntry = try await supabase
                    .from("vinyl_entries")
                    .insert(payload, returning: .representation)
                    .select()
                    .single()
                    .execute()
                    .value

                // Add to For Sale crate if marked for sale
                if payload.forSale {
                    try await addVinylToCrate(vinylId: vinyl.id, crateId: try await resolveForSaleCrateId())
                }
            }
            
        case .updateVinyl:
            // Decode and process vinyl update operations
            struct UpdateSaleStatusPayload: Codable {
                let entryId: String
                let forSale: Bool
                let askingPrice: Double?
            }
            
            if let payload = try? JSONDecoder().decode(UpdateSaleStatusPayload.self, from: operation.data) {
                try await updateVinylSaleStatus(entryId: payload.entryId, forSale: payload.forSale, askingPrice: payload.askingPrice)
            }
            
        case .deleteVinyl:
            // Decode and process vinyl deletion
            struct DeleteVinylPayload: Codable {
                let entryId: String
            }
            
            if let payload = try? JSONDecoder().decode(DeleteVinylPayload.self, from: operation.data) {
                try await supabase
                    .from("vinyl_entries")
                    .delete()
                    .eq("id", value: payload.entryId)
                    .eq("owner_id", value: try await getCurrentSonexUserId())
                    .execute()
            }
            
        case .moveVinyl:
            // Decode and process vinyl move operation
            struct MoveVinylPayload: Codable {
                let entryId: String
                let crateId: String
            }
            
            if let payload = try? JSONDecoder().decode(MoveVinylPayload.self, from: operation.data) {
                struct MovePatch: Encodable { let crate_id: String }
                
                try await supabase
                    .from("vinyl_entries")
                    .update(MovePatch(crate_id: payload.crateId))
                    .eq("id", value: payload.entryId)
                    .eq("owner_id", value: try await getCurrentSonexUserId())
                    .execute()
            }
        }
    }
    
    func signUpWithEmail(email: String, password: String) async throws -> AuthResponse {
        do {
            let authResponse = try await supabase.auth.signUp(
                email: email, 
                password: password,
                redirectTo: URL(string: "sonex://auth-callback")
            )
            if let session = authResponse.session {
                await updateSessionCache(session)
            }
            return authResponse
        } catch {
            let errorMessage = error.localizedDescription.lowercased()
            throw(NSError(domain: "Auth", code: 500, userInfo: [NSLocalizedDescriptionKey: "\(errorMessage)"]))
        }
    }
    
    func signIn(email: String, password: String) async throws -> Session {
        let session = try await supabase.auth.signIn(email: email, password: password)
        await updateSessionCache(session)
        return session
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
        await clearSessionCache()
    }
    
    // MARK: - Session Management
    
    private func updateSessionCache(_ session: Session) async {
        self.currentSession = session
        self.isAuthenticated = true
    }
    
    private func clearSessionCache() async {
        self.currentSession = nil
        self.isAuthenticated = false
        // Clear all caches when user signs out
        await clearCratesCache()
        await clearUserProfileCache()
        cacheManager.clearAllCache()
    }
    
    private func checkCurrentSession() async {
        do {
            let session = try await supabase.auth.session
            await updateSessionCache(session)
        } catch {
            await clearSessionCache()
        }
    }
    
    private func listenToAuthChanges() async {
        for await authState in supabase.auth.authStateChanges {
            switch authState.event {
            case .signedIn:
                if let session = authState.session {
                    print("Signed in")
                    await updateSessionCache(session)
                }
            case .signedOut:
                await clearSessionCache()
            case .tokenRefreshed:
                if let session = authState.session {
                    await updateSessionCache(session)
                }
            default:
                break
            }
        }
    }
    
    // MARK: - Public Session Access
    
    var userID: String? {
        return currentSession?.user.id.uuidString
    }
    
    var userEmail: String? {
        return currentSession?.user.email
    }
    
    /// Returns the SonexUser's ID (different from the auth user ID)
    private func getCurrentSonexUserId() async throws -> String {
        let currentUser = try await fetchCurrentUser()
        return currentUser.id
    }
    
    // MARK: - Public Authentication Methods
    
    func signOutFromApp() async throws {
        try await signOut()
    }
    
}
extension SonexDBManager {

    // MARK: - User Profile Management
    
    // MARK: - User Profile Cache Methods
    
    private func clearUserProfileCache() async {
        _cachedUserProfile = nil
        _userProfileCacheTimestamp = nil
        cacheManager.clearCachedUserProfile()
    }
    
    private func isUserProfileCacheValid() -> Bool {
        guard let timestamp = _userProfileCacheTimestamp else { return false }
        return Date().timeIntervalSince(timestamp) < userProfileCacheExpirationInterval
    }
    
    private func updateUserProfileCache(_ profile: SonexUser) async {
        _cachedUserProfile = profile
        _userProfileCacheTimestamp = Date()
        cacheManager.cacheUserProfile(profile)
    }

    // MARK: - User

    /// Call this immediately after signUp succeeds.
    /// Creates the public profile row and provisions the default Unsorted crate atomically.
    func createUserProfile(username: String, displayName: String? = nil) async throws -> SonexUser {
        guard userID != nil else { throw SonexDBError.notAuthenticated }
        
        // If offline, queue the operation
        guard isOnline else {
            throw SonexDBError.noNetworkConnection
        }

        let payload = UserProfilePayload(username: username, displayName: displayName, user_id: userID!)

        let user: SonexUser = try await supabase
            .from("users")
            .insert(payload, returning: .representation)  // returns the inserted row
            .select()
            .single()
            .execute()
            .value

        // Cache the created profile
        await updateUserProfileCache(user)

        // Provision the protected default crates
        _ = try await createCrate(named: "Unsorted", sortOrder: 0)
        _ = try await createCrate(named: "For Sale", sortOrder: 1, forSale: true)
        _ = try await createCrate(named: "Wishlist", sortOrder: 2)

        return user
    }

    func updateProfile(_ fields: ProfileUpdatePayload) async throws {
        guard let uid = userID else { throw SonexDBError.notAuthenticated }

        if isOnline {
            // Try to update on server first
            try await updateProfileOnServer(fields)
        } else {
            // Queue for later if offline
            if let data = try? JSONEncoder().encode(fields) {
                let operation = PendingOperation(
                    type: .updateProfile,
                    timestamp: Date(),
                    data: data
                )
                cacheManager.addPendingOperation(operation)
            }
            
            // Update local cache optimistically
            if var cachedProfile = _cachedUserProfile {
                if let username = fields.username {
                    cachedProfile.username = username
                }
                if let displayName = fields.displayName {
                    cachedProfile.displayName = displayName
                }
                if let avatarUrl = fields.avatarUrl {
                    cachedProfile.avatarUrl = avatarUrl
                }
                if let bio = fields.bio {
                    cachedProfile.bio = bio
                }
                await updateUserProfileCache(cachedProfile)
            }
        }
    }
    
    private func updateProfileOnServer(_ fields: ProfileUpdatePayload) async throws {
        guard let uid = userID else { throw SonexDBError.notAuthenticated }
        
        let updatedProfile: SonexUser = try await supabase
            .from("users")
            .update(fields, returning: .representation)
            .eq("id", value: uid)
            .select()
            .single()
            .execute()
            .value
        
        // Update cache with server response
        await updateUserProfileCache(updatedProfile)
    }

    func fetchCurrentUser(forceRefresh: Bool = false) async throws -> SonexUser {
        guard let uid = userID else { throw SonexDBError.notAuthenticated }

        // Return cached data if available and valid, unless force refresh is requested
        if !forceRefresh, isUserProfileCacheValid(), let cachedProfile = _cachedUserProfile {
            return cachedProfile
        }
        
        // If offline, return cached data if available
        if !isOnline {
            if let cachedProfile = _cachedUserProfile {
                return cachedProfile
            } else {
                throw SonexDBError.noNetworkConnection
            }
        }

        let user: SonexUser = try await supabase
            .from("users")
            .select()
            .eq("user_id", value: uid)
            .single()
            .execute()
            .value
        
        // Update cache with fresh data
        await updateUserProfileCache(user)
        
        return user
    }
    
    /// Manually refresh the user profile cache
    func refreshUserProfileCache() async throws -> SonexUser {
        return try await fetchCurrentUser(forceRefresh: true)
    }

    // MARK: - Crates
    
    // MARK: - Crates Cache Management
    
    private func clearCratesCache() async {
        _cachedCrates = nil
        _cratesCacheTimestamp = nil
        // Clear cached crate IDs as well
        _unsortedCrateId = nil
        _forSaleCrateId = nil
        _wishlistCrateId = nil
        cacheManager.clearCachedCrates()
        cacheManager.clearSpecialCrateIds()
    }
    
    private func isCratesCacheValid() -> Bool {
        guard let timestamp = _cratesCacheTimestamp else { return false }
        return Date().timeIntervalSince(timestamp) < cratesCacheExpirationInterval
    }
    
    private func updateCratesCache(_ crates: [Crate]) async {
        _cachedCrates = crates
        _cratesCacheTimestamp = Date()
        cacheManager.cacheCrates(crates)
        
        // Cache special crate IDs for quick access
        let unsortedId = crates.first(where: { $0.name == "Unsorted" })?.id
        let forSaleId = crates.first(where: { $0.for_sale == true })?.id
        let wishlistId = crates.first(where: { $0.name == "Wishlist" })?.id
        
        if let unsortedId = unsortedId {
            _unsortedCrateId = unsortedId
        }
        if let forSaleId = forSaleId {
            _forSaleCrateId = forSaleId
        }
        if let wishlistId = wishlistId {
            _wishlistCrateId = wishlistId
        }
        
        cacheManager.cacheSpecialCrateIds(
            unsorted: unsortedId,
            forSale: forSaleId,
            wishlist: wishlistId
        )
    }

    func createCrate(named name: String, sortOrder: Int = 0, forSale: Bool = false) async throws -> Crate {
        guard userID != nil else { throw SonexDBError.notAuthenticated }
        
        // If offline, queue the operation and create optimistic crate
        if !isOnline {
            let optimisticCrate = Crate(
                owner_id: try await getCurrentSonexUserId(),
                name: name,
                sortOrder: sortOrder,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                vinyl_entry_ids: [],
                for_sale: forSale
            )
            
            // Add to cache optimistically
            var currentCrates = _cachedCrates ?? []
            currentCrates.append(optimisticCrate)
            currentCrates.sort { $0.sortOrder < $1.sortOrder }
            await updateCratesCache(currentCrates)
            
            // Queue for server sync
            struct CreateCratePayload: Codable {
                let name: String
                let sortOrder: Int
                let forSale: Bool
                let tempId: String
            }
            
            if let data = try? JSONEncoder().encode(CreateCratePayload(name: name, sortOrder: sortOrder, forSale: forSale, tempId: optimisticCrate.id)) {
                let operation = PendingOperation(
                    type: .createCrate,
                    timestamp: Date(),
                    data: data
                )
                cacheManager.addPendingOperation(operation)
            }
            
            return optimisticCrate
        }
        
        let sonexUserId = try await getCurrentSonexUserId()

        struct CratePayload: Encodable {
            let owner_id: String
            let name: String
            let sort_order: Int
            let for_sale: Bool
        }

        let newCrate = try await supabase
            .from("crates")
            .insert(CratePayload(owner_id: sonexUserId, name: name, sort_order: sortOrder, for_sale: forSale),
                    returning: .representation)
            .select()
            .single()
            .execute()
            .value as Crate
        
        // Invalidate cache when a new crate is created
        await clearCratesCache()
        
        return newCrate
    }

    func fetchCrates(forceRefresh: Bool = false) async throws -> [Crate] {
        guard userID != nil else { throw SonexDBError.notAuthenticated }
        
        // Return cached data if available and valid, unless force refresh is requested
        if !forceRefresh, isCratesCacheValid(), let cachedCrates = _cachedCrates {
            return cachedCrates
        }
        
        // If offline, return cached data if available
        if !isOnline {
            if let cachedCrates = _cachedCrates {
                return cachedCrates
            } else {
                throw SonexDBError.noNetworkConnection
            }
        }
        
        let sonexUserId = try await getCurrentSonexUserId()

        let crates: [Crate] = try await supabase
            .from("crates")
            .select()
            .eq("owner_id", value: sonexUserId)
            .order("sort_order", ascending: true)
            .execute()
            .value
        
        // Update cache with fresh data
        await updateCratesCache(crates)
        
        return crates
    }
    
    /// Manually refresh the crates cache
    func refreshCratesCache() async throws -> [Crate] {
        return try await fetchCrates(forceRefresh: true)
    }

    /// Resolves (and caches) the user's Unsorted crate ID.
    /// Used internally during vinyl registration.
    func resolveUnsortedCrateId() async throws -> String {
        if let cached = _unsortedCrateId { return cached }

        guard userID != nil else { throw SonexDBError.notAuthenticated }

        // First try to find it in the cached crates
        if let cachedCrates = _cachedCrates, isCratesCacheValid() {
            if let unsorted = cachedCrates.first(where: { $0.name == "Unsorted" }) {
                _unsortedCrateId = unsorted.id
                return unsorted.id
            }
        }
        
        // If offline and no cached data, throw error
        if !isOnline {
            throw SonexDBError.noNetworkConnection
        }
        
        let sonexUserId = try await getCurrentSonexUserId()

        let crates: [Crate] = try await supabase
            .from("crates")
            .select()
            .eq("owner_id", value: sonexUserId)
            .eq("name", value: "Unsorted")
            .limit(1)
            .execute()
            .value

        guard let unsorted = crates.first else {
            // Crate missing — provision it
            let created = try await createCrate(named: "Unsorted", sortOrder: 0)
            _unsortedCrateId = created.id
            return created.id
        }

        _unsortedCrateId = unsorted.id
        cacheManager.cacheSpecialCrateIds(unsorted: unsorted.id)
        return unsorted.id
    }
    
    
    func resolveForSaleCrateId() async throws -> String {
        if let cached = _forSaleCrateId { return cached }

        guard userID != nil else { throw SonexDBError.notAuthenticated }

        // First try to find it in the cached crates
        if let cachedCrates = _cachedCrates, isCratesCacheValid() {
            if let forSale = cachedCrates.first(where: { $0.for_sale == true }) {
                _forSaleCrateId = forSale.id
                return forSale.id
            }
        }
        
        // If offline and no cached data, throw error
        if !isOnline {
            throw SonexDBError.noNetworkConnection
        }
        
        let sonexUserId = try await getCurrentSonexUserId()

        let crates: [Crate] = try await supabase
            .from("crates")
            .select()
            .eq("owner_id", value: sonexUserId)
            .eq("for_sale", value: "true")
            .limit(1)
            .execute()
            .value

        guard let forSale = crates.first else {
            // Crate missing — provision it
            let created = try await createCrate(named: "For Sale", sortOrder: 1, forSale: true)
            _forSaleCrateId = created.id
            return created.id
        }

        _forSaleCrateId = forSale.id
        cacheManager.cacheSpecialCrateIds(forSale: forSale.id)
        return forSale.id
    }
    
    func resolveWishlistCrateId() async throws -> String {
        if let cached = _wishlistCrateId { return cached }

        guard userID != nil else { throw SonexDBError.notAuthenticated }

        // First try to find it in the cached crates
        if let cachedCrates = _cachedCrates, isCratesCacheValid() {
            if let wishlist = cachedCrates.first(where: { $0.name == "Wishlist" }) {
                _wishlistCrateId = wishlist.id
                return wishlist.id
            }
        }
        
        // If offline and no cached data, throw error
        if !isOnline {
            throw SonexDBError.noNetworkConnection
        }
        
        let sonexUserId = try await getCurrentSonexUserId()

        let crates: [Crate] = try await supabase
            .from("crates")
            .select()
            .eq("owner_id", value: sonexUserId)
            .eq("name", value: "Wishlist")
            .limit(1)
            .execute()
            .value

        guard let wishlist = crates.first else {
            // Crate missing — provision it
            let created = try await createCrate(named: "Wishlist", sortOrder: 2)
            _wishlistCrateId = created.id
            return created.id
        }

        _wishlistCrateId = wishlist.id
        cacheManager.cacheSpecialCrateIds(wishlist: wishlist.id)
        return wishlist.id
    }
    
    // MARK: - Offline Support Methods
    
    /// Returns true if the app can function with cached data while offline
    var canWorkOffline: Bool {
        return _cachedUserProfile != nil && _cachedCrates != nil
    }
    
    /// Forces a complete refresh of all cached data when online
    func syncAllData() async throws {
        guard isOnline else { throw SonexDBError.noNetworkConnection }
        
        // Refresh all caches
        _ = try await refreshUserProfileCache()
        _ = try await refreshCratesCache()
        
        // Process any pending operations
        await processPendingOperationsIfOnline()
        
        // Update sync timestamp
        cacheManager.updateLastSyncTimestamp()
    }
    
    /// Returns the last time data was synced with the server
    var lastSyncDate: Date? {
        return cacheManager.getLastSyncTimestamp()
    }
    
    /// Returns the number of pending operations waiting to sync
    var pendingOperationsCount: Int {
        return cacheManager.getPendingOperations().count
    }

    // MARK: - Vinyl Entries

    /// Checks if an NFC tag is already registered to a vinyl entry
    func checkNFCTagRegistration(tagHash: String) async throws -> VinylEntry? {
        guard userID != nil else { throw SonexDBError.notAuthenticated }
        
        // If offline, we can't check registration status
        guard isOnline else { throw SonexDBError.noNetworkConnection }
        
        let entries: [VinylEntry] = try await supabase
            .from("vinyl_entries")
            .select()
            .eq("nfc_tag_hash", value: tagHash)
            .limit(1)
            .execute()
            .value
        
        return entries.first
    }

    /// Registers a new vinyl. Defaults to Unsorted crate if crateId is not provided.
    func registerVinyl(
        title: String,
        artist: String,
        crateId: String? = nil,
        discogsId: String? = nil,
        nfcTagHash: String? = nil,
        label: String? = nil,
        year: Int? = nil,
        pressing: String? = nil,
        format: String? = nil,
        grade: VinylGrade? = nil,
        gradeNotes: String? = nil,
        coverArtUrl: String? = nil,
        audioNoteUrl: String? = nil,
        forSale: Bool = false,
        askingPrice: Double? = nil
    ) async throws -> VinylEntry {
        guard let uid = userID else { throw SonexDBError.notAuthenticated }

        let resolvedCrateId: String
        if let crateId = crateId {
            resolvedCrateId = crateId
        } else {
            resolvedCrateId = try await resolveUnsortedCrateId()
        }

        let payload = VinylEntryPayload(
            ownerId: try await getCurrentSonexUserId(),
            title: title,
            artist: artist,
            crateId: resolvedCrateId,
            discogsId: discogsId,
            nfcTagHash: nfcTagHash,
            label: label,
            year: year,
            pressing: pressing,
            format: format,
            grade: grade?.rawValue,
            gradeNotes: gradeNotes,
            coverArtUrl: coverArtUrl,
            audioNoteUrl: audioNoteUrl,
            forSale: forSale,
            askingPrice: askingPrice
        )

        // If offline, queue the operation
        if !isOnline {
            // Create optimistic vinyl entry
            let optimisticEntry = VinylEntry(
                id: UUID().uuidString,
                ownerId: try await getCurrentSonexUserId(),
                discogsId: discogsId,
                nfcTagHash: nfcTagHash,
                title: title,
                artist: artist,
                label: label,
                year: year,
                pressing: pressing,
                format: format,
                grade: grade,
                gradeNotes: gradeNotes,
                coverArtUrl: coverArtUrl,
                audioNoteUrl: audioNoteUrl,
                forSale: forSale,
                askingPrice: askingPrice,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            
            // Add to appropriate crate
            if forSale {
                try await addVinylToCrate(vinylId: optimisticEntry.id, crateId: try await resolveForSaleCrateId())
            }
            try await addVinylToCrate(vinylId: optimisticEntry.id, crateId: resolvedCrateId)
            
            // Queue for server sync
            if let data = try? JSONEncoder().encode(payload) {
                let operation = PendingOperation(
                    type: .createVinyl,
                    timestamp: Date(),
                    data: data
                )
                cacheManager.addPendingOperation(operation)
            }
            
            return optimisticEntry
        }

        let newVinyl: VinylEntry = try await supabase
            .from("vinyl_entries")
            .insert(payload, returning: .representation)
            .select()
            .single()
            .execute()
            .value

        // Add to For Sale crate if marked for sale
        if forSale {
            try await addVinylToCrate(vinylId: newVinyl.id, crateId: try await resolveForSaleCrateId())
        }

        return newVinyl
    }

    func fetchVinylEntries(inCrate crateId: String) async throws -> [VinylEntry] {
        guard userID != nil else { throw SonexDBError.notAuthenticated }
        
        // If offline, we can't fetch from server
        guard isOnline else { throw SonexDBError.noNetworkConnection }
        
        return try await supabase
            .from("vinyl_entries")
            .select()
            .eq("crate_id", value: crateId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func moveVinyl(entryId: String, toCrate crateId: String) async throws {
        guard let uid = userID else { throw SonexDBError.notAuthenticated }

        struct MovePatch: Encodable { let crate_id: String }

        if !isOnline {
            // Queue for later if offline
            struct MoveVinylPayload: Codable {
                let entryId: String
                let crateId: String
            }
            
            if let data = try? JSONEncoder().encode(MoveVinylPayload(entryId: entryId, crateId: crateId)) {
                let operation = PendingOperation(
                    type: .moveVinyl,
                    timestamp: Date(),
                    data: data
                )
                cacheManager.addPendingOperation(operation)
            }
            return
        }

        try await supabase
            .from("vinyl_entries")
            .update(MovePatch(crate_id: crateId))
            .eq("id", value: entryId)
            .eq("owner_id", value: try await getCurrentSonexUserId())   // ownership guard
            .execute()
    }

    func updateVinylSaleStatus(entryId: String, forSale: Bool, askingPrice: Double?) async throws {
        guard let uid = userID else { throw SonexDBError.notAuthenticated }

        struct SalePatch: Encodable {
            let for_sale: Bool
            let asking_price: Double?
        }

        if !isOnline {
            // Queue for later if offline
            struct UpdateSaleStatusPayload: Codable {
                let entryId: String
                let forSale: Bool
                let askingPrice: Double?
            }
            
            if let data = try? JSONEncoder().encode(UpdateSaleStatusPayload(entryId: entryId, forSale: forSale, askingPrice: askingPrice)) {
                let operation = PendingOperation(
                    type: .updateVinyl,
                    timestamp: Date(),
                    data: data
                )
                cacheManager.addPendingOperation(operation)
            }
            return
        }

        try await supabase
            .from("vinyl_entries")
            .update(SalePatch(for_sale: forSale, asking_price: askingPrice))
            .eq("id", value: entryId)
            .eq("owner_id", value: try await getCurrentSonexUserId())
            .execute()
            
        // Update For Sale crate
        if forSale {
            try await addVinylToCrate(vinylId: entryId, crateId: try await resolveForSaleCrateId())
        } else {
            try await removeVinylFromCrate(vinylId: entryId, crateId: try await resolveForSaleCrateId())
        }
    }

    func deleteVinyl(entryId: String) async throws {
        guard let uid = userID else { throw SonexDBError.notAuthenticated }

        if !isOnline {
            // Queue for later if offline
            struct DeleteVinylPayload: Codable {
                let entryId: String
            }
            
            if let data = try? JSONEncoder().encode(DeleteVinylPayload(entryId: entryId)) {
                let operation = PendingOperation(
                    type: .deleteVinyl,
                    timestamp: Date(),
                    data: data
                )
                cacheManager.addPendingOperation(operation)
            }
            return
        }

        try await supabase
            .from("vinyl_entries")
            .delete()
            .eq("id", value: entryId)
            .eq("owner_id", value: try await getCurrentSonexUserId())
            .execute()
    }
    
    // MARK: - Crate Management Helpers
    
    /// Adds a vinyl entry ID to a crate's vinyl_entry_ids array
    private func addVinylToCrate(vinylId: String, crateId: String) async throws {
        // Get current crate
        let crate: Crate = try await supabase
            .from("crates")
            .select()
            .eq("id", value: crateId)
            .single()
            .execute()
            .value
        
        // Add vinyl ID if not already present
        var updatedIds = crate.vinyl_entry_ids
        if !updatedIds.contains(vinylId) {
            updatedIds.append(vinylId)
        }
        
        // Update crate
        struct CrateUpdatePayload: Codable {
            let vinyl_entry_ids: [String]
        }
        
        try await supabase
            .from("crates")
            .update(CrateUpdatePayload(vinyl_entry_ids: updatedIds))
            .eq("id", value: crateId)
            .execute()
        
        // Clear crates cache to force refresh
        await clearCratesCache()
    }
    
    /// Removes a vinyl entry ID from a crate's vinyl_entry_ids array
    private func removeVinylFromCrate(vinylId: String, crateId: String) async throws {
        // Get current crate
        let crate: Crate = try await supabase
            .from("crates")
            .select()
            .eq("id", value: crateId)
            .single()
            .execute()
            .value
        
        // Remove vinyl ID
        let updatedIds = crate.vinyl_entry_ids.filter { $0 != vinylId }
        
        // Update crate
        struct CrateUpdatePayload: Codable {
            let vinyl_entry_ids: [String]
        }
        
        try await supabase
            .from("crates")
            .update(CrateUpdatePayload(vinyl_entry_ids: updatedIds))
            .eq("id", value: crateId)
            .execute()
        
        // Clear crates cache to force refresh
        await clearCratesCache()
    }
//
//    /// Registers a new vinyl. Defaults to Unsorted crate if crateId is not provided.
//    func registerVinyl(
//        title: String,
//        artist: String,
//        crateId: String? = nil,
//        discogsId: String? = nil,
//        nfcTagHash: String? = nil,
//        label: String? = nil,
//        year: Int? = nil,
//        pressing: String? = nil,
//        format: String? = nil,
//        grade: String? = nil,
//        gradeNotes: String? = nil,
//        coverArtUrl: String? = nil,
//        audioNoteUrl: String? = nil,
//        forSale: Bool = false,
//        askingPrice: Double? = nil
//    ) async throws -> VinylEntry {
//        guard let uid = userID else { throw SonexDBError.notAuthenticated }
//
//        let resolvedCrateId: String
//        if let crateId = crateId {
//            resolvedCrateId = crateId
//        } else {
//            resolvedCrateId = try await resolveUnsortedCrateId()
//        }
//
//        let payload = VinylEntryPayload(
//            ownerId: uid,
//            title: title,
//            artist: artist,
//            crateId: resolvedCrateId,
//            discogsId: discogsId,
//            nfcTagHash: nfcTagHash,
//            label: label,
//            year: year,
//            pressing: pressing,
//            format: format,
//            grade: grade,
//            gradeNotes: gradeNotes,
//            coverArtUrl: coverArtUrl,
//            audioNoteUrl: audioNoteUrl,
//            forSale: forSale,
//            askingPrice: askingPrice
//        )
//
//        return try await supabase
//            .from("vinyl_entries")
//            .insert(payload, returning: .representation)
//            .select()
//            .single()
//            .execute()
//            .value
//    }
//
//    func fetchVinylEntries(inCrate crateId: String) async throws -> [VinylEntry] {
//        return try await supabase
//            .from("vinyl_entries")
//            .select()
//            .eq("crate_id", value: crateId)
//            .order("created_at", ascending: false)
//            .execute()
//            .value
//    }
//
//    func moveVinyl(entryId: String, toCrate crateId: String) async throws {
//        guard let uid = userID else { throw SonexDBError.notAuthenticated }
//
//        struct MovePatch: Encodable { let crate_id: String }
//
//        try await supabase
//            .from("vinyl_entries")
//            .update(MovePatch(crate_id: crateId))
//            .eq("id", value: entryId)
//            .eq("owner_id", value: uid)   // ownership guard
//            .execute()
//    }
//
//    func updateVinylSaleStatus(entryId: String, forSale: Bool, askingPrice: Double?) async throws {
//        guard let uid = userID else { throw SonexDBError.notAuthenticated }
//
//        struct SalePatch: Encodable {
//            let for_sale: Bool
//            let asking_price: Double?
//        }
//
//        try await supabase
//            .from("vinyl_entries")
//            .update(SalePatch(for_sale: forSale, asking_price: askingPrice))
//            .eq("id", value: entryId)
//            .eq("owner_id", value: uid)
//            .execute()
//    }
//
//    func deleteVinyl(entryId: String) async throws {
//        guard let uid = userID else { throw SonexDBError.notAuthenticated }
//
//        try await supabase
//            .from("vinyl_entries")
//            .delete()
//            .eq("id", value: entryId)
//            .eq("owner_id", value: uid)
//            .execute()
//    }
}

// MARK: - Error Types

enum SonexDBError: LocalizedError {
    case notAuthenticated
    case unsortedCrateMissing
    case noNetworkConnection

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:     return "No active session. Please sign in."
        case .unsortedCrateMissing: return "Default crate could not be found or created."
        case .noNetworkConnection:  return "No network connection. Please check your internet and try again."
        }
    }
}
