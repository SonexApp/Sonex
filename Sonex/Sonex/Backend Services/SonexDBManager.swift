
import SwiftUI
import Supabase
import SonexShared
import Foundation
import Network
import CoreLocation

struct UserProfilePayload: Encodable {
    var username: String
    var displayName: String?
    var user_id: String
    var bio: String?
    var address: String?

    enum CodingKeys: String, CodingKey {
        case username
        case displayName = "display_name"
        case user_id = "user_id"
        case bio = "bio"
        case address = "address"
    }
}

struct ProfileUpdatePayload: Codable {
    var username: String?
    var displayName: String?
    var avatarUrl: String?
    var bio: String?
    var address: String?

    enum CodingKeys: String, CodingKey {
        case username
        case displayName = "display_name"
        case avatarUrl  = "avatar_url"
        case bio
        case address
    }
}

struct VinylEntryPayload: Codable {
    var ownerId: String
    var title: String
    var artist: String
    var discogsId: String?
    var nfcTagHash: String?
    var label: String?
    var year: Int?
    var pressing: String?
    var format: String?
    var mediaGrade: String?
    var gradeNotes: String?
    var coverArtUrl: String?
    var forSale: Bool = false
    var askingPrice: Double?
    var catalogNumber: String?
    var matrixCode: String?
    var barcode: String?
    var releaseEdition: ReleaseEdition = .standard
    var editionNotes: String?
    var sleeveGrade: String?
    var locationNote: String?

    enum CodingKeys: String, CodingKey {
        case ownerId      = "owner_id"
        case title, artist
        case discogsId    = "discogs_id"
        case nfcTagHash   = "nfc_tag_hash"
        case label, year, pressing, format
        case mediaGrade   = "media_grade"
        case gradeNotes   = "grade_notes"
        case coverArtUrl  = "cover_art_url"
        case forSale      = "for_sale"
        case askingPrice  = "asking_price"
        case catalogNumber = "catalog_number"
        case matrixCode   = "matrix_code"
        case barcode
        case releaseEdition = "release_edition"
        case editionNotes = "edition_notes"
        case sleeveGrade  = "sleeve_grade"
        case locationNote = "location_note"
    }
}

// MARK: - Image Cache Manager
@MainActor
class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize: Int = 100 * 1024 * 1024 // 100MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    private init() {
        // Create cache directory in Documents folder
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsDirectory.appendingPathComponent("ImageCache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Configure memory cache
        memoryCache.countLimit = 100 // Maximum number of images in memory
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB memory limit
        
        // Clean up old cache on init
        Task {
            await cleanupExpiredCache()
        }
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.memoryCache.removeAllObjects()
        }
    }
    
    // MARK: - Public Methods
    
    /// Retrieves an image from cache or downloads it if not available
    func getImage(for url: String) async throws -> UIImage? {
        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: NSString(string: url)) {
            return cachedImage
        }
        
        // Check disk cache
        if let diskImage = await loadImageFromDisk(url: url) {
            // Store in memory cache for faster access
            memoryCache.setObject(diskImage, forKey: NSString(string: url))
            return diskImage
        }
        
        // Download and cache the image
        return try await downloadAndCacheImage(url: url)
    }
    
    /// Preloads an image into cache without returning it
    func preloadImage(for url: String) {
        Task {
            do {
                _ = try await getImage(for: url)
            } catch {
                print("⚠️ [ImageCacheManager] Failed to preload image for URL: \(url) - \(error)")
            }
        }
    }
    
    /// Clears all cached images
    func clearCache() async {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// Gets the current cache size in bytes
    func getCacheSize() async -> Int {
        return await calculateDirectorySize(cacheDirectory)
    }
    
    // MARK: - Private Methods
    
    private func downloadAndCacheImage(url: String) async throws -> UIImage? {
        guard let imageURL = URL(string: url) else {
            throw NSError(domain: "ImageCache", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        // Download the image
        let (data, _) = try await URLSession.shared.data(from: imageURL)
        
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "ImageCache", code: 422, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }
        
        // Save to disk cache
        await saveImageToDisk(image: image, url: url)
        
        // Store in memory cache
        memoryCache.setObject(image, forKey: NSString(string: url))
        
        return image
    }
    
    private func loadImageFromDisk(url: String) async -> UIImage? {
        let cacheKey = hashString(url)
        let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey).jpg")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // Check if file is not too old
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let modificationDate = attributes[.modificationDate] as? Date,
               Date().timeIntervalSince(modificationDate) > maxCacheAge {
                try? fileManager.removeItem(at: fileURL)
                return nil
            }
        } catch {
            return nil
        }
        
        // Load and return the image
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            // Remove corrupted file
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        
        return image
    }
    
    private func saveImageToDisk(image: UIImage, url: String) async {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        let cacheKey = hashString(url)
        let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey).jpg")
        
        do {
            try data.write(to: fileURL)
        } catch {
            print("⚠️ [ImageCacheManager] Failed to save image to disk: \(error)")
        }
        
        // Check cache size and cleanup if needed
        await cleanupCacheIfNeeded()
    }
    
    private func cleanupCacheIfNeeded() async {
        let currentSize = await calculateDirectorySize(cacheDirectory)
        
        if currentSize > maxCacheSize {
            await cleanupOldestFiles()
        }
    }
    
    private func cleanupExpiredCache() async {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }
        
        let now = Date()
        
        for fileURL in files {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
                if let modificationDate = resourceValues.contentModificationDate,
                   now.timeIntervalSince(modificationDate) > maxCacheAge {
                    try fileManager.removeItem(at: fileURL)
                }
            } catch {
                // Remove files we can't read
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    private func cleanupOldestFiles() async {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return
        }
        
        // Sort by modification date (oldest first)
        let sortedFiles = files.compactMap { fileURL -> (URL, Date, Int)? in
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                guard let modificationDate = resourceValues.contentModificationDate,
                      let fileSize = resourceValues.fileSize else {
                    return nil
                }
                return (fileURL, modificationDate, fileSize)
            } catch {
                return nil
            }
        }.sorted { $0.1 < $1.1 }
        
        var currentSize = await calculateDirectorySize(cacheDirectory)
        let targetSize = maxCacheSize * 3 / 4 // Reduce to 75% of max size
        
        for (fileURL, _, fileSize) in sortedFiles {
            if currentSize <= targetSize {
                break
            }
            
            try? fileManager.removeItem(at: fileURL)
            currentSize -= fileSize
        }
    }
    
    private func calculateDirectorySize(_ directory: URL) async -> Int {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize = 0
        for fileURL in files {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
    
    private func hashString(_ string: String) -> String {
        return String(string.hashValue)
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
        static let cratesWithCounts = "cached_crates_with_counts"
        static let cratesTimestamp = "cached_crates_timestamp"
        static let unsortedCrateId = "cached_unsorted_crate_id"
        static let forSaleCrateId = "cached_for_sale_crate_id"
        static let wishlistCrateId = "cached_wishlist_crate_id"
        static let lastSyncTimestamp = "last_sync_timestamp"
        static let pendingOperations = "pending_operations"
        static let vinylEntriesPrefix = "cached_vinyl_entries_"
        static let vinylEntriesTimestampPrefix = "cached_vinyl_entries_timestamp_"
        static let totalRecordsCount = "cached_total_records_count"
        static let totalRecordsTimestamp = "cached_total_records_timestamp"
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
    
    func cacheCratesWithCounts(_ crates: [CrateWithCount]) {
        if let data = try? JSONEncoder().encode(crates) {
            userDefaults.set(data, forKey: CacheKeys.cratesWithCounts)
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
    
    func getCachedCratesWithCounts() -> [CrateWithCount]? {
        guard let data = userDefaults.data(forKey: CacheKeys.cratesWithCounts),
              let crates = try? JSONDecoder().decode([CrateWithCount].self, from: data) else {
            return nil
        }
        return crates
    }
    
    func getCratesCacheTimestamp() -> Date? {
        return userDefaults.object(forKey: CacheKeys.cratesTimestamp) as? Date
    }
    
    func clearCachedCrates() {
        userDefaults.removeObject(forKey: CacheKeys.crates)
        userDefaults.removeObject(forKey: CacheKeys.cratesWithCounts)
        userDefaults.removeObject(forKey: CacheKeys.cratesTimestamp)
    }
    
    // MARK: - Vinyl Entries Cache
    func cacheVinylEntries(_ entries: [VinylEntry], forCrate crateId: String) {
        if let data = try? JSONEncoder().encode(entries) {
            userDefaults.set(data, forKey: CacheKeys.vinylEntriesPrefix + crateId)
            userDefaults.set(Date(), forKey: CacheKeys.vinylEntriesTimestampPrefix + crateId)
        }
    }
    
    func getCachedVinylEntries(forCrate crateId: String) -> [VinylEntry]? {
        guard let data = userDefaults.data(forKey: CacheKeys.vinylEntriesPrefix + crateId),
              let entries = try? JSONDecoder().decode([VinylEntry].self, from: data) else {
            return nil
        }
        return entries
    }
    
    func getVinylEntriesCacheTimestamp(forCrate crateId: String) -> Date? {
        return userDefaults.object(forKey: CacheKeys.vinylEntriesTimestampPrefix + crateId) as? Date
    }
    
    func clearVinylEntriesCache(forCrate crateId: String) {
        userDefaults.removeObject(forKey: CacheKeys.vinylEntriesPrefix + crateId)
        userDefaults.removeObject(forKey: CacheKeys.vinylEntriesTimestampPrefix + crateId)
    }
    
    func clearAllVinylEntriesCache() {
        // Get all keys and remove vinyl entries caches
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix(CacheKeys.vinylEntriesPrefix) || key.hasPrefix(CacheKeys.vinylEntriesTimestampPrefix) {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    // MARK: - Total Records Count Cache
    func cacheTotalRecordsCount(_ count: Int) {
        userDefaults.set(count, forKey: CacheKeys.totalRecordsCount)
        userDefaults.set(Date(), forKey: CacheKeys.totalRecordsTimestamp)
    }
    
    func getCachedTotalRecordsCount() -> Int? {
        guard userDefaults.object(forKey: CacheKeys.totalRecordsCount) != nil else {
            return nil
        }
        return userDefaults.integer(forKey: CacheKeys.totalRecordsCount)
    }
    
    func getTotalRecordsTimestamp() -> Date? {
        return userDefaults.object(forKey: CacheKeys.totalRecordsTimestamp) as? Date
    }
    
    func clearTotalRecordsCache() {
        userDefaults.removeObject(forKey: CacheKeys.totalRecordsCount)
        userDefaults.removeObject(forKey: CacheKeys.totalRecordsTimestamp)
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
        clearAllVinylEntriesCache()
        clearTotalRecordsCache()
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
        case updateLocationNote
        case updateCoverArt
    }
}


@MainActor
@Observable
class SonexDBManager {
    static let shared = SonexDBManager()
    private let supabase: SupabaseClient
    private let cacheManager = OfflineCacheManager.shared
    private let imageCacheManager = ImageCacheManager.shared
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
    private var _cachedCratesWithCounts: [CrateWithCount]?
    private var _cratesCacheTimestamp: Date?
    private let cratesCacheExpirationInterval: TimeInterval = 300 // 5 minutes
    
    // Vinyl entries cache - per crate
    private var _cachedVinylEntries: [String: [VinylEntry]] = [:]
    private var _vinylEntriesCacheTimestamps: [String: Date] = [:]
    private let vinylEntriesCacheExpirationInterval: TimeInterval = 300 // 5 minutes
    
    // Total records cache
    private var _cachedTotalRecords: Int?
    private var _totalRecordsCacheTimestamp: Date?
    private let totalRecordsCacheExpirationInterval: TimeInterval = 300 // 5 minutes
    
    // User profile cache
    private var _cachedUserProfile: SonexUser?
    private var _userProfileCacheTimestamp: Date?
    private let userProfileCacheExpirationInterval: TimeInterval = 600 // 10 minutes
    
    private init() {
        supabase = SupabaseClient(
            supabaseURL: URL(string: "https://bbjtznnxrreuzurgtuyz.supabase.co")!, 
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJianR6bm54cnJldXp1cmd0dXl6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5ODMzMTksImV4cCI6MjA5MDU1OTMxOX0.hrHqnA_rlEc51OROgU0ALAqRCjzWcPYGEj7UaP56qYc",
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
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
        
        // Preload user data when authenticated and online
        Task {
            await initializeUserData()
        }
    }
    
    /// Initialize user data on app start
    private func initializeUserData() async {
        guard isAuthenticated && isOnline else { return }
        
        do {
            print("🚀 [initializeUserData] Starting data preload...")
            try await preloadUserData()
            print("✅ [initializeUserData] Data preload completed")
        } catch {
            print("⚠️ [initializeUserData] Data preload failed, will use cached data: \(error)")
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
        
        // Load cached crates with counts
        if let cachedCratesWithCounts = cacheManager.getCachedCratesWithCounts() {
            _cachedCratesWithCounts = cachedCratesWithCounts
            _cratesCacheTimestamp = cacheManager.getCratesCacheTimestamp()
        }
        
        // Load cached total records
        if let cachedTotalRecords = cacheManager.getCachedTotalRecordsCount() {
            _cachedTotalRecords = cachedTotalRecords
            _totalRecordsCacheTimestamp = cacheManager.getTotalRecordsTimestamp()
        }
        
        // Load cached user profile
        if let cachedProfile = cacheManager.getCachedUserProfile() {
            _cachedUserProfile = cachedProfile
            _userProfileCacheTimestamp = Date() // Assume recent for offline access
        }
        
        // Load cached vinyl entries for each crate
        if let cachedCrates = _cachedCrates {
            for crate in cachedCrates {
                if let cachedVinylEntries = cacheManager.getCachedVinylEntries(forCrate: crate.id) {
                    _cachedVinylEntries[crate.id] = cachedVinylEntries
                    _vinylEntriesCacheTimestamps[crate.id] = cacheManager.getVinylEntriesCacheTimestamp(forCrate: crate.id) ?? Date()
                }
            }
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
            if let payload = try? JSONDecoder().decode(VinylEntryPayload.self, from: operation.data) {
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
                
                // Add to the default Unsorted crate (since we don't have the original crate info in the payload)
                try await addVinylToCrate(vinylId: vinyl.id, crateId: try await resolveUnsortedCrateId())
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
                let fromCrateId: String
                let toCrateId: String
            }
            
            if let payload = try? JSONDecoder().decode(MoveVinylPayload.self, from: operation.data) {
                // Remove from old crate
                try await removeVinylFromCrate(vinylId: payload.entryId, crateId: payload.fromCrateId)
                
                // Add to new crate
                try await addVinylToCrate(vinylId: payload.entryId, crateId: payload.toCrateId)
            }
            
        case .updateLocationNote:
            // Decode and process location note update
            struct UpdateLocationNotePayload: Codable {
                let entryId: String
                let locationNote: String?
            }
            
            if let payload = try? JSONDecoder().decode(UpdateLocationNotePayload.self, from: operation.data) {
                try await updateVinylLocationNoteOnServer(entryId: payload.entryId, locationNote: payload.locationNote)
            }
            
        case .updateCoverArt:
            // Decode and process cover art update
            struct UpdateCoverArtPayload: Codable {
                let entryId: String
                let coverArtUrl: String
            }
            
            if let payload = try? JSONDecoder().decode(UpdateCoverArtPayload.self, from: operation.data) {
                try await updateVinylCoverArtOnServer(entryId: payload.entryId, coverArtUrl: payload.coverArtUrl)
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
    
    /// Clear all cache when user signs out
    private func clearSessionCache() async {
        self.currentSession = nil
        self.isAuthenticated = false
        // Clear all caches when user signs out
        await clearCratesCache()
        await clearUserProfileCache()
        await clearAllVinylEntriesCache()
        await clearTotalRecordsCache()
        await clearImageCache()
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
    func createUserProfile(username: String, displayName: String? = nil, bio: String? = nil, address: String? = nil) async throws -> SonexUser {
        guard userID != nil else { throw SonexDBError.notAuthenticated }
        
        // If offline, queue the operation
        guard isOnline else {
            throw SonexDBError.noNetworkConnection
        }
        
        let payload = UserProfilePayload(username: username, displayName: displayName, user_id: userID!, bio: bio, address: address)
        
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
        guard userID != nil else { throw SonexDBError.notAuthenticated }
        
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
                if let address = fields.address {
                    cachedProfile.address = address
                }
                await updateUserProfileCache(cachedProfile)
            }
        }
    }
    
    private func updateProfileOnServer(_ fields: ProfileUpdatePayload) async throws {
        guard let uid = userID else { throw SonexDBError.notAuthenticated }
        
        // Perform the update operation
        try await supabase
            .from("users")
            .update(fields)
            .eq("user_id", value: uid)
            .execute()
        
        // Fetch the updated profile separately to update cache
        let updatedProfile: SonexUser = try await supabase
            .from("users")
            .select()
            .eq("user_id", value: uid)
            .single()
            .execute()
            .value
        
        // Update cache with fresh data
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
    
    // MARK: - Crates Cache Management
    
    private func clearCratesCache() async {
        _cachedCrates = nil
        _cachedCratesWithCounts = nil
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
        let forSaleId = crates.first(where: { $0.name == "For Sale" })?.id
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
    
    private func updateCratesWithCountsCache(_ crates: [CrateWithCount]) async {
        _cachedCratesWithCounts = crates
        _cratesCacheTimestamp = Date()
        cacheManager.cacheCratesWithCounts(crates)
        
        // Update the basic crates cache as well
        let basicCrates = crates.map { $0.asCrate }
        _cachedCrates = basicCrates
        cacheManager.cacheCrates(basicCrates)
        
        // Cache special crate IDs for quick access
        let unsortedId = crates.first(where: { $0.name == "Unsorted" })?.id
        let forSaleId = crates.first(where: { $0.name == "For Sale" })?.id
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
    
    // MARK: - Vinyl Entries Cache Management

    
    private func clearAllVinylEntriesCache() async {
        _cachedVinylEntries.removeAll()
        _vinylEntriesCacheTimestamps.removeAll()
        cacheManager.clearAllVinylEntriesCache()
    }
    
    // MARK: - Total Records Cache Management
    
    private func clearTotalRecordsCache() async {
        _cachedTotalRecords = nil
        _totalRecordsCacheTimestamp = nil
        cacheManager.clearTotalRecordsCache()
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
    
    func deleteCrate(crateId: String) async throws {
        print("🗑️ [deleteCrate] Starting deletion for crate ID: \(crateId)")
        
        guard userID != nil else { 
            print("❌ [deleteCrate] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        if !isOnline {
            print("❌ [deleteCrate] Cannot delete crate while offline")
            throw SonexDBError.noNetworkConnection
        }
        
        print("🌐 [deleteCrate] Online mode - deleting from database")
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            print("👤 [deleteCrate] Sonex user ID: \(sonexUserId)")
            
            // First, remove all vinyl-crate relationships for this crate
            try await supabase
                .from("vinyl_crates")
                .delete()
                .eq("crate_id", value: crateId)
                .execute()
            
            print("✅ [deleteCrate] Removed all vinyl-crate relationships")
            
            // Then delete the crate itself
            try await supabase
                .from("crates")
                .delete()
                .eq("id", value: crateId)
                .eq("owner_id", value: sonexUserId)
                .execute()
            
            print("✅ [deleteCrate] Successfully deleted crate from database")
            
            // Invalidate cache when a crate is deleted
            await clearCratesCache()
            
            print("🗑️ [deleteCrate] Crate deletion completed successfully")
            
        } catch {
            print("❌ [deleteCrate] Failed to delete crate: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [deleteCrate] Localized error description: \(localizedError.errorDescription ?? "No description")")
            }
            throw error
        }
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
            if let forSale = cachedCrates.first(where: { $0.name == "For Sale" }) {
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
            .eq("name", value: "For Sale")
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
    
    /// Comprehensive data preloading for offline use
    func preloadUserData(forceRefresh: Bool = false) async throws {
        print("📦 [preloadUserData] Starting comprehensive data preload, forceRefresh: \(forceRefresh)")
        
        guard userID != nil else { 
            print("❌ [preloadUserData] Not authenticated")
            throw SonexDBError.notAuthenticated 
        }
        
        guard isOnline else {
            print("📱 [preloadUserData] Offline - cannot preload data")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            print("👤 [preloadUserData] Sonex user ID: \(sonexUserId)")
            
            // 1. Load user profile
            print("👤 [preloadUserData] Loading user profile...")
            _ = try await fetchCurrentUser(forceRefresh: forceRefresh)
            
            // 2. Load all crates with counts
            print("📦 [preloadUserData] Loading crates with counts...")
            let cratesWithCounts = try await fetchCratesWithCountsFromDB(sonexUserId: sonexUserId)
            
            // Update cache with crates and counts
            _cachedCratesWithCounts = cratesWithCounts
            _cachedCrates = cratesWithCounts.map { $0.asCrate }
            _cratesCacheTimestamp = Date()
            
            // Cache to persistent storage
            cacheManager.cacheCratesWithCounts(cratesWithCounts)
            cacheManager.cacheCrates(cratesWithCounts.map { $0.asCrate })
            
            // Cache special crate IDs
            updateSpecialCrateIds(from: cratesWithCounts)
            
            // 3. Load total records count
            print("🔢 [preloadUserData] Loading total records count...")
            let totalCount = try await fetchTotalRecordsFromDB(sonexUserId: sonexUserId)
            await updateTotalRecordsCache(totalCount)
            
            // 4. Preload vinyl entries for each crate
            print("🎵 [preloadUserData] Loading vinyl entries for all crates...")
            await preloadVinylEntries(for: cratesWithCounts.map { $0.asCrate })
            
            // 5. Preload cover art images for better performance
            print("🖼️ [preloadUserData] Preloading cover art images...")
            await preloadCoverArtForAllCrates(cratesWithCounts.map { $0.asCrate })
            
            // 6. Preload discover posts for better discover tab experience
            print("🗺️ [preloadUserData] Preloading discover posts...")
            await preloadDiscoverData()
            
            print("✅ [preloadUserData] Successfully preloaded all user data")
            
        } catch {
            print("❌ [preloadUserData] Failed to preload user data: \(error)")
            throw error
        }
    }
    
    /// Preloads discover posts for better initial experience
    private func preloadDiscoverData() async {
        do {
            // Fetch a small initial set of discover posts without location filtering
            let posts = try await fetchDiscoverPosts(near: nil, radius: 50000) // 50km radius
            print("🗺️ [preloadDiscoverData] Successfully preloaded \(posts.count) discover posts")
        } catch {
            print("⚠️ [preloadDiscoverData] Failed to preload discover posts (non-critical): \(error)")
            // Don't throw here as this is not critical for app functionality
        }
    }
    
    /// Helper function to fetch crates with counts from database
    private func fetchCratesWithCountsFromDB(sonexUserId: String) async throws -> [CrateWithCount] {
        // Fetch basic crates
        let crates: [Crate] = try await supabase
            .from("crates")
            .select("*")
            .eq("owner_id", value: sonexUserId)
            .order("sort_order", ascending: true)
            .execute()
            .value
        
        var cratesWithCounts: [CrateWithCount] = []
        
        // Fetch counts for each crate
        for crate in crates {
            do {
                let countResult: [CountResult] = try await supabase
                    .from("vinyl_crates")
                    .select("count", head: false, count: .exact)
                    .eq("crate_id", value: crate.id)
                    .execute()
                    .value
                
                let recordCount = countResult.first?.count ?? 0
                
                let crateWithCount = CrateWithCount(
                    id: crate.id,
                    ownerId: crate.owner_id ?? "",
                    name: crate.name,
                    sortOrder: crate.sortOrder,
                    createdAt: crate.createdAt,
                    forSale: crate.for_sale,
                    recordCount: recordCount
                )
                
                cratesWithCounts.append(crateWithCount)
                
            } catch {
                print("⚠️ [fetchCratesWithCountsFromDB] Failed to fetch count for crate '\(crate.name)': \(error)")
                // Add crate with 0 count on error
                let crateWithCount = CrateWithCount(
                    id: crate.id,
                    ownerId: crate.owner_id ?? "",
                    name: crate.name,
                    sortOrder: crate.sortOrder,
                    createdAt: crate.createdAt,
                    forSale: crate.for_sale,
                    recordCount: 0
                )
                cratesWithCounts.append(crateWithCount)
            }
        }
        
        return cratesWithCounts
    }
    
    /// Helper function to fetch total records from database
    private func fetchTotalRecordsFromDB(sonexUserId: String) async throws -> Int {
        let result: [CountResult] = try await supabase
            .from("vinyl_entries")
            .select("count", head: false, count: .exact)
            .eq("owner_id", value: sonexUserId)
            .execute()
            .value
        
        return result.first?.count ?? 0
    }
    
    /// Helper function to preload cover art for all crates
    private func preloadCoverArtForAllCrates(_ crates: [Crate]) async {
        await withTaskGroup(of: Void.self) { group in
            for crate in crates {
                group.addTask { [weak self] in
                    await self?.preloadCoverArtForCrate(crate.id)
                }
            }
        }
    }
    
    /// Helper function to preload vinyl entries for all crates
    private func preloadVinylEntries(for crates: [Crate]) async {
        await withTaskGroup(of: Void.self) { group in
            for crate in crates {
                group.addTask { [weak self] in
                    await self?.preloadVinylEntriesForCrate(crate)
                }
            }
        }
    }
    
    /// Helper function to preload vinyl entries for a single crate
    private func preloadVinylEntriesForCrate(_ crate: Crate) async {
        do {
            let vinylEntries: [VinylEntry] = try await supabase
                .from("vinyl_entries")
                .select("""
                    *,
                    vinyl_crates!inner(crate_id, added_at)
                """)
                .eq("vinyl_crates.crate_id", value: crate.id)
                .execute()
                .value
            
            print("✅ [preloadVinylEntriesForCrate] Loaded \(vinylEntries.count) entries for crate '\(crate.name)'")
            
            // Update cache
            await updateVinylEntriesCache(vinylEntries, forCrate: crate.id)
            
        } catch {
            print("❌ [preloadVinylEntriesForCrate] Failed to load entries for crate '\(crate.name)': \(error)")
        }
    }
    
    /// Helper function to update special crate IDs from crates list
    private func updateSpecialCrateIds(from crates: [CrateWithCount]) {
        let unsortedId = crates.first(where: { $0.name == "Unsorted" })?.id
        let forSaleId = crates.first(where: { $0.name == "For Sale" })?.id
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
    
    /// Helper function to check if cached vinyl entries are valid for a crate
    private func isVinylEntriesCacheValid(forCrate crateId: String) -> Bool {
        guard let timestamp = _vinylEntriesCacheTimestamps[crateId] else { return false }
        return Date().timeIntervalSince(timestamp) < vinylEntriesCacheExpirationInterval
    }
    
    /// Helper function to update vinyl entries cache
    private func updateVinylEntriesCache(_ entries: [VinylEntry], forCrate crateId: String) async {
        _cachedVinylEntries[crateId] = entries
        _vinylEntriesCacheTimestamps[crateId] = Date()
        cacheManager.cacheVinylEntries(entries, forCrate: crateId)
    }
    
    /// Helper function to clear vinyl entries cache for a crate
    private func clearVinylEntriesCache(forCrate crateId: String) async {
        _cachedVinylEntries[crateId] = nil
        _vinylEntriesCacheTimestamps[crateId] = nil
        cacheManager.clearVinylEntriesCache(forCrate: crateId)
    }
    
    /// Helper function to check if total records cache is valid
    private func isTotalRecordsCacheValid() -> Bool {
        guard let timestamp = _totalRecordsCacheTimestamp else { return false }
        return Date().timeIntervalSince(timestamp) < totalRecordsCacheExpirationInterval
    }
    
    /// Helper function to update total records cache
    private func updateTotalRecordsCache(_ count: Int) async {
        _cachedTotalRecords = count
        _totalRecordsCacheTimestamp = Date()
        cacheManager.cacheTotalRecordsCount(count)
    }

    /// Returns true if the app can function with cached data while offline
    var canWorkOffline: Bool {
        return _cachedUserProfile != nil && _cachedCratesWithCounts != nil
    }
    
    /// Quick access to cached crates with counts (for UI that needs immediate data)
    func getCachedCratesWithCounts() -> [CrateWithCount] {
        return _cachedCratesWithCounts ?? []
    }
    
    /// Quick access to cached vinyl entries for a crate (for UI that needs immediate data)
    func getCachedVinylEntries(forCrate crateId: String) -> [VinylEntry] {
        return _cachedVinylEntries[crateId] ?? []
    }
    
    /// Quick access to cached total records count
    func getCachedTotalRecords() -> Int {
        return _cachedTotalRecords ?? 0
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
    
    // MARK: - User Statistics
    
    /// Fetches comprehensive user statistics for the current user
    func fetchUserStats() async throws -> UserStats {
        print("📊 [fetchUserStats] Starting fetch for user statistics")
        
        guard userID != nil else { 
            print("❌ [fetchUserStats] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        // If offline, return cached stats if available, otherwise return zeros
        if !isOnline {
            print("📱 [fetchUserStats] Offline - returning basic stats from cache")
            let cratesCount = _cachedCrates?.count ?? 0
            return UserStats(
                cratesCount: cratesCount,
                followingCount: 0,
                followersCount: 0,
                exchangesCount: 0,
                totalRecordsCount: 0
            )
        }
        
        print("🌐 [fetchUserStats] Online - fetching comprehensive stats")
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            print("👤 [fetchUserStats] Sonex user ID: \(sonexUserId)")
            
            // Fetch all stats concurrently for better performance
            async let cratesTask = fetchCratesCount(userId: sonexUserId)
            async let followingTask = fetchFollowingCount(userId: sonexUserId)
            async let followersTask = fetchFollowersCount(userId: sonexUserId)
            async let exchangesTask = fetchExchangesCount(userId: sonexUserId)
            async let recordsTask = fetchTotalUserRecords()
            
            let (cratesCount, followingCount, followersCount, exchangesCount, recordsCount) = try await (
                cratesTask, followingTask, followersTask, exchangesTask, recordsTask
            )
            
            let stats = UserStats(
                cratesCount: cratesCount,
                followingCount: followingCount,
                followersCount: followersCount,
                exchangesCount: exchangesCount,
                totalRecordsCount: recordsCount
            )
            
            print("✅ [fetchUserStats] Successfully fetched user stats:")
            print("   - Crates: \(stats.cratesCount)")
            print("   - Following: \(stats.followingCount)")
            print("   - Followers: \(stats.followersCount)")
            print("   - Exchanges: \(stats.exchangesCount)")
            print("   - Total Records: \(stats.totalRecordsCount)")
            
            return stats
            
        } catch {
            print("❌ [fetchUserStats] Failed to fetch user stats: \(error)")
            throw error
        }
    }
    
    /// Fetches the count of crates for a specific user
    private func fetchCratesCount(userId: String) async throws -> Int {
        let result: [CountResult] = try await supabase
            .from("crates")
            .select("count", head: false, count: .exact)
            .eq("owner_id", value: userId)
            .execute()
            .value
        
        return result.first?.count ?? 0
    }
    
    /// Fetches the count of users the current user is following
    private func fetchFollowingCount(userId: String) async throws -> Int {
        let result: [CountResult] = try await supabase
            .from("friendships")
            .select("count", head: false, count: .exact)
            .eq("requester_id", value: userId)
            .in("status", value: ["following", "accepted"]) // Include legacy "accepted" status
            .execute()
            .value
        
        return result.first?.count ?? 0
    }
    
    /// Fetches the count of users following the current user
    private func fetchFollowersCount(userId: String) async throws -> Int {
        let result: [CountResult] = try await supabase
            .from("friendships")
            .select("count", head: false, count: .exact)
            .eq("addressee_id", value: userId)
            .in("status", value: ["following", "accepted"]) // Include legacy "accepted" status
            .execute()
            .value
        
        return result.first?.count ?? 0
    }
    
    /// Fetches the count of exchanges (both as buyer and seller) for the current user
    private func fetchExchangesCount(userId: String) async throws -> Int {
        // Count as seller
        let sellerResult: [CountResult] = try await supabase
            .from("exchanges")
            .select("count", head: false, count: .exact)
            .eq("seller_id", value: userId)
            .execute()
            .value
        
        // Count as buyer
        let buyerResult: [CountResult] = try await supabase
            .from("exchanges")
            .select("count", head: false, count: .exact)
            .eq("buyer_id", value: userId)
            .execute()
            .value
        
        let sellerCount = sellerResult.first?.count ?? 0
        let buyerCount = buyerResult.first?.count ?? 0
        
        return sellerCount + buyerCount
    }
    
    /// Fetches the total number of vinyl records for a specific user
    func fetchTotalRecordsForUser(_ userId: String) async throws -> Int {
        print("🔢 [fetchTotalRecordsForUser] Starting fetch for user: \(userId)")
        
        guard userID != nil else { 
            print("❌ [fetchTotalRecordsForUser] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        guard isOnline else {
            print("📱 [fetchTotalRecordsForUser] Offline - cannot fetch records count")
            throw SonexDBError.noNetworkConnection
        }
        
        print("🌐 [fetchTotalRecordsForUser] Online mode - fetching from database")
        
        do {
            // Get count directly from vinyl_entries table for the specific user
            let result: [CountResult] = try await supabase
                .from("vinyl_entries")
                .select("count", head: false, count: .exact)
                .eq("owner_id", value: userId)
                .execute()
                .value
            
            let totalCount = result.first?.count ?? 0
            print("📊 [fetchTotalRecordsForUser] Total records for user \(userId): \(totalCount)")
            
            return totalCount
            
        } catch {
            print("❌ [fetchTotalRecordsForUser] Failed to fetch total records for user: \(error)")
            throw error
        }
    }
    
    /// Fetches the list of users the current user is following
    func fetchFollowing() async throws -> [FriendshipRelation] {
        print("👥 [fetchFollowing] Fetching following list")
        
        guard userID != nil else { 
            print("❌ [fetchFollowing] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        guard isOnline else {
            print("📱 [fetchFollowing] Offline - cannot fetch following list")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            print("👤 [fetchFollowing] Sonex user ID: \(sonexUserId)")
            
            // Fetch friendships where current user is the requester and status is following/accepted
            // Using a custom response structure to handle the joined user data
            let response = try await supabase
                .from("friendships")
                .select("""
                    id,
                    status,
                    created_at,
                    addressee_user:users!friendships_addressee_id_fkey(
                        id,
                        user_id,
                        username,
                        display_name,
                        avatar_url,
                        bio,
                        address,
                        created_at,
                        is_signature
                    )
                """)
                .eq("requester_id", value: sonexUserId)
                .in("status", value: ["following", "accepted"])
                .order("created_at", ascending: false)
                .execute()
            
            // Parse the response manually since we're dealing with nested data
            let data = response.data
            
            let decoder = JSONDecoder()
            let friendshipResponses = try decoder.decode([FriendshipWithUser].self, from: data)
            
            print("✅ [fetchFollowing] Successfully fetched \(friendshipResponses.count) following relationships")
            
            // Convert to FriendshipRelation objects
            let friendshipRelations = friendshipResponses.compactMap { response -> FriendshipRelation? in
                guard let user = response.addresseeUser else {
                    print("⚠️ [fetchFollowing] Missing user data for friendship \(response.id)")
                    return nil
                }
                
                return FriendshipRelation(
                    id: response.id,
                    user: user,
                    status: response.status,
                    isFollowing: true, // Current user is following this user
                    isFollower: false, // We'd need to check the reverse relationship
                    createdAt: response.createdAt
                )
            }
            
            print("✅ [fetchFollowing] Converted to \(friendshipRelations.count) FriendshipRelation objects")
            return friendshipRelations
            
        } catch {
            print("❌ [fetchFollowing] Failed to fetch following list: \(error)")
            throw error
        }
    }
    
    /// Fetches the list of users following the current user
    func fetchFollowers() async throws -> [FriendshipRelation] {
        print("👥 [fetchFollowers] Fetching followers list")
        
        guard userID != nil else { 
            print("❌ [fetchFollowers] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        guard isOnline else {
            print("📱 [fetchFollowers] Offline - cannot fetch followers list")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            print("👤 [fetchFollowers] Sonex user ID: \(sonexUserId)")
            
            // Fetch friendships where current user is the addressee and status is following/accepted
            let response = try await supabase
                .from("friendships")
                .select("""
                    id,
                    status,
                    created_at,
                    requester_user:users!friendships_requester_id_fkey(
                        id,
                        user_id,
                        username,
                        display_name,
                        avatar_url,
                        bio,
                        address,
                        created_at,
                        is_signature
                    )
                """)
                .eq("addressee_id", value: sonexUserId)
                .in("status", value: ["following", "accepted"])
                .order("created_at", ascending: false)
                .execute()
            
            // Parse the response manually since we're dealing with nested data
            let data = response.data
            
            let decoder = JSONDecoder()
            let friendshipResponses = try decoder.decode([FriendshipWithRequester].self, from: data)
            
            print("✅ [fetchFollowers] Successfully fetched \(friendshipResponses.count) follower relationships")
            
            // Convert to FriendshipRelation objects
            let friendshipRelations = friendshipResponses.compactMap { response -> FriendshipRelation? in
                guard let user = response.requesterUser else {
                    print("⚠️ [fetchFollowers] Missing user data for friendship \(response.id)")
                    return nil
                }
                
                return FriendshipRelation(
                    id: response.id,
                    user: user,
                    status: response.status,
                    isFollowing: false, // We'd need to check the reverse relationship
                    isFollower: true, // This user is following the current user
                    createdAt: response.createdAt
                )
            }
            
            print("✅ [fetchFollowers] Converted to \(friendshipRelations.count) FriendshipRelation objects")
            return friendshipRelations
            
        } catch {
            print("❌ [fetchFollowers] Failed to fetch followers list: \(error)")
            throw error
        }
    }
    
    /// Fetches the exchange history for the current user
    func fetchExchangeHistory() async throws -> [ExchangeSummary] {
        print("💱 [fetchExchangeHistory] Fetching exchange history")
        
        guard userID != nil else { 
            print("❌ [fetchExchangeHistory] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        guard isOnline else {
            print("📱 [fetchExchangeHistory] Offline - cannot fetch exchange history")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            print("👤 [fetchExchangeHistory] Sonex user ID: \(sonexUserId)")
            
            // Fetch exchanges where user is either seller or buyer
            let response = try await supabase
                .from("exchanges")
                .select("""
                    id,
                    seller_id,
                    buyer_id,
                    record_ids,
                    total_price,
                    status,
                    completed_at,
                    seller:users!exchanges_seller_id_fkey(
                        id,
                        user_id,
                        username,
                        display_name,
                        avatar_url,
                        bio,
                        address,
                        created_at
                    ),
                    buyer:users!exchanges_buyer_id_fkey(
                        id,
                        user_id,
                        username,
                        display_name,
                        avatar_url,
                        bio,
                        address,
                        created_at
                    )
                """)
                .or("seller_id.eq.\(sonexUserId),buyer_id.eq.\(sonexUserId)")
                .order("completed_at", ascending: false, nullsFirst: false)
                .order("id", ascending: false)
                .execute()
            
            // Parse the response manually since we're dealing with nested data
            let data = response.data
            
            let decoder = JSONDecoder()
            let exchangeResponses = try decoder.decode([ExchangeWithUsers].self, from: data)
            
            print("✅ [fetchExchangeHistory] Successfully fetched \(exchangeResponses.count) exchanges")
            
            // Convert to ExchangeSummary objects
            let exchangeSummaries = exchangeResponses.compactMap { response -> ExchangeSummary? in
                let isSellerInExchange = response.sellerId == sonexUserId
                let otherUser = isSellerInExchange ? response.buyer : response.seller
                
                guard let otherUser = otherUser else {
                    print("⚠️ [fetchExchangeHistory] Missing user data for exchange \(response.id)")
                    return nil
                }
                
                return ExchangeSummary(
                    id: response.id,
                    otherUser: otherUser,
                    recordCount: response.recordIds?.count ?? 0,
                    totalPrice: response.totalPrice,
                    status: response.status,
                    isSellerInExchange: isSellerInExchange,
                    completedAt: response.completedAt
                )
            }
            
            print("✅ [fetchExchangeHistory] Converted to \(exchangeSummaries.count) ExchangeSummary objects")
            return exchangeSummaries
            
        } catch {
            print("❌ [fetchExchangeHistory] Failed to fetch exchange history: \(error)")
            throw error
        }
    }
    
    /// Fetches a user by their ID (not auth user ID, but Sonex user ID)
    func fetchUserById(_ userId: String) async throws -> SonexUser {
        print("👤 [fetchUserById] Fetching user with ID: \(userId)")
        
        guard isOnline else {
            print("❌ [fetchUserById] Cannot fetch user while offline")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            let user: SonexUser = try await supabase
                .from("users")
                .select("*")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            print("✅ [fetchUserById] Successfully fetched user: \(user.username)")
            return user
            
        } catch {
            print("❌ [fetchUserById] Failed to fetch user: \(error)")
            throw error
        }
    }
    
    /// Checks if a vinyl with the given title and artist exists in the current user's collection
    func checkVinylExistsInCollection(title: String, artist: String) async throws -> Bool {
        print("🔍 [checkVinylExistsInCollection] Checking for '\(title)' by '\(artist)'")
        
        guard userID != nil else { 
            print("❌ [checkVinylExistsInCollection] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        guard isOnline else {
            print("❌ [checkVinylExistsInCollection] Cannot check while offline")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            
            // Use count query for better performance and to avoid decoding issues
            let result: [CountResult] = try await supabase
                .from("vinyl_entries")
                .select("count", head: false, count: .exact)
                .eq("owner_id", value: sonexUserId)
                .eq("title", value: title)
                .eq("artist", value: artist)
                .execute()
                .value
            
            let count = result.first?.count ?? 0
            let exists = count > 0
            print("✅ [checkVinylExistsInCollection] Found \(count) matches - exists: \(exists)")
            return exists
            
        } catch {
            print("❌ [checkVinylExistsInCollection] Failed to check: \(error)")
            throw error
        }
    }
    func searchUsers(query: String, limit: Int = 10) async throws -> [SonexUser] {
        print("🔍 [searchUsers] Searching for users with query: \(query)")
        
        guard userID != nil else { 
            print("❌ [searchUsers] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        guard isOnline else {
            print("❌ [searchUsers] Cannot search users while offline")
            throw SonexDBError.noNetworkConnection
        }
        
        guard query.count >= 2 else {
            print("❌ [searchUsers] Query too short")
            return []
        }
        
        do {
            let currentSonexUserId = try await getCurrentSonexUserId()
            
            // Search for users by username or display name
            // Using ilike for case-insensitive matching
            let users: [SonexUser] = try await supabase
                .from("users")
                .select("*")
                .or("username.ilike.%\(query)%,display_name.ilike.%\(query)%")
                .neq("user_id", value: currentSonexUserId) // Exclude current user
                .limit(limit)
                .execute()
                .value
            
            print("✅ [searchUsers] Found \(users.count) users matching query")
            return users
            
        } catch {
            print("❌ [searchUsers] Failed to search users: \(error)")
            throw error
        }
    }
    
    /// Fetches basic user stats for a specific user (for displaying in search results)
    func fetchUserStats(for userId: String) async throws -> UserStats {
        print("📊 [fetchUserStats] Fetching stats for user: \(userId)")
        
        guard userID != nil else { 
            print("❌ [fetchUserStats] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        guard isOnline else {
            print("❌ [fetchUserStats] Cannot fetch user stats while offline")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            async let cratesCount = fetchCratesCount(userId: userId)
            async let followingCount = fetchFollowingCount(userId: userId)
            async let followersCount = fetchFollowersCount(userId: userId)
            async let exchangesCount = fetchExchangesCount(userId: userId)
            async let totalRecordsCount = fetchTotalRecordsForUser(userId)
            
            let (crates, following, followers, exchanges, totalRecords) = try await (cratesCount, followingCount, followersCount, exchangesCount, totalRecordsCount)
            
            let userStats = UserStats(
                cratesCount: crates,
                followingCount: following,
                followersCount: followers,
                exchangesCount: exchanges,
                totalRecordsCount: totalRecords
            )
            
            print("✅ [fetchUserStats] Successfully fetched stats for user")
            return userStats
            
        } catch {
            print("❌ [fetchUserStats] Failed to fetch user stats: \(error)")
            throw error
        }
    }
    
    /// Follows a user (creates a friendship relationship)
    func followUser(userId: String) async throws {
        print("➕ [followUser] Starting to follow user: \(userId)")
        
        guard userID != nil else { 
            print("❌ [followUser] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        guard isOnline else {
            print("❌ [followUser] Cannot follow user while offline")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            let currentUserId = try await getCurrentSonexUserId()
            print("👤 [followUser] Current user ID: \(currentUserId)")
            
            // Check if relationship already exists
            let existingFriendships: [Friendship] = try await supabase
                .from("friendships")
                .select("*")
                .eq("requester_id", value: currentUserId)
                .eq("addressee_id", value: userId)
                .execute()
                .value
            
            if let existing = existingFriendships.first {
                print("⚠️ [followUser] Friendship already exists with status: \(existing.status)")
                
                // If it's declined or blocked, we might want to update it
                if existing.status == .declined {
                    try await supabase
                        .from("friendships")
                        .update(["status": FriendshipStatus.following.rawValue])
                        .eq("id", value: existing.id.uuidString)
                        .execute()
                    print("✅ [followUser] Updated declined friendship to following")
                }
                return
            }
            
            // Create new friendship
            struct FollowPayload: Codable {
                let requester_id: String
                let addressee_id: String
                let status: String
            }
            
            let payload = FollowPayload(
                requester_id: currentUserId,
                addressee_id: userId,
                status: FriendshipStatus.following.rawValue
            )
            
            try await supabase
                .from("friendships")
                .insert(payload)
                .execute()
            
            print("✅ [followUser] Successfully created follow relationship")
            
        } catch {
            print("❌ [followUser] Failed to follow user: \(error)")
            throw error
        }
    }
    
    /// Unfollows a user (updates or removes friendship relationship)
    func unfollowUser(userId: String) async throws {
        print("➖ [unfollowUser] Starting to unfollow user: \(userId)")
        
        guard userID != nil else { 
            print("❌ [unfollowUser] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        guard isOnline else {
            print("❌ [unfollowUser] Cannot unfollow user while offline")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            let currentUserId = try await getCurrentSonexUserId()
            print("👤 [unfollowUser] Current user ID: \(currentUserId)")
            
            // Remove the friendship relationship
            try await supabase
                .from("friendships")
                .delete()
                .eq("requester_id", value: currentUserId)
                .eq("addressee_id", value: userId)
                .execute()
            
            print("✅ [unfollowUser] Successfully unfollowed user")
            
        } catch {
            print("❌ [unfollowUser] Failed to unfollow user: \(error)")
            throw error
        }
    }
    
    // MARK: - RSVP Management
    
    /// Creates an RSVP for a discover post event
    func createRSVP(eventId: String, status: RSVPStatus = .interested) async throws {
        print("📝 [createRSVP] Creating RSVP for event: \(eventId) with status: \(status.rawValue)")
        
        guard userID != nil else {
            print("❌ [createRSVP] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated
        }
        
        guard isOnline else {
            print("❌ [createRSVP] Cannot create RSVP while offline")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            
            // Check if RSVP already exists
            let existingRSVPs: [EventRSVP] = try await supabase
                .from("event_rsvps")
                .select("*")
                .eq("event_id", value: eventId)
                .eq("user_id", value: sonexUserId)
                .execute()
                .value
            
            if let existingRSVP = existingRSVPs.first {
                // Update existing RSVP
                try await supabase
                    .from("event_rsvps")
                    .update(["status": status.rawValue])
                    .eq("id", value: existingRSVP.id)
                    .execute()
                print("✅ [createRSVP] Updated existing RSVP")
            } else {
                // Create new RSVP
                struct RSVPPayload: Codable {
                    let event_id: String
                    let user_id: String
                    let status: String
                }
                
                try await supabase
                    .from("event_rsvps")
                    .insert(RSVPPayload(event_id: eventId, user_id: sonexUserId, status: status.rawValue))
                    .execute()
                print("✅ [createRSVP] Created new RSVP")
            }
            
        } catch {
            print("❌ [createRSVP] Failed to create RSVP: \(error)")
            throw error
        }
    }
    
    /// Fetches RSVPs for a specific event
    func fetchRSVPs(for eventId: String) async throws -> [EventRSVP] {
        print("📋 [fetchRSVPs] Fetching RSVPs for event: \(eventId)")
        
        guard userID != nil else {
            print("❌ [fetchRSVPs] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated
        }
        
        guard isOnline else {
            print("❌ [fetchRSVPs] Cannot fetch RSVPs while offline")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            let rsvps: [EventRSVP] = try await supabase
                .from("event_rsvps")
                .select("""
                    *,
                    user:users!event_rsvps_user_id_fkey(
                        id,
                        username,
                        display_name,
                        avatar_url
                    )
                """)
                .eq("event_id", value: eventId)
                .execute()
                .value
            
            print("✅ [fetchRSVPs] Fetched \(rsvps.count) RSVPs for event")
            return rsvps
            
        } catch {
            print("❌ [fetchRSVPs] Failed to fetch RSVPs: \(error)")
            throw error
        }
    }
    
    /// Gets the current user's RSVP status for an event
    func getCurrentUserRSVP(for eventId: String) async throws -> EventRSVP? {
        print("🔍 [getCurrentUserRSVP] Checking user's RSVP status for event: \(eventId)")
        
        guard userID != nil else {
            return nil
        }
        
        guard isOnline else {
            return nil
        }
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            
            let rsvps: [EventRSVP] = try await supabase
                .from("event_rsvps")
                .select("*")
                .eq("event_id", value: eventId)
                .eq("user_id", value: sonexUserId)
                .execute()
                .value
            
            return rsvps.first
            
        } catch {
            print("❌ [getCurrentUserRSVP] Failed to check RSVP status: \(error)")
            return nil
        }
    }
    
    /// Removes the current user's RSVP for an event
    func removeRSVP(for eventId: String) async throws {
        print("🗑️ [removeRSVP] Removing RSVP for event: \(eventId)")
        
        guard userID != nil else {
            print("❌ [removeRSVP] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated
        }
        
        guard isOnline else {
            print("❌ [removeRSVP] Cannot remove RSVP while offline")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            
            try await supabase
                .from("event_rsvps")
                .delete()
                .eq("event_id", value: eventId)
                .eq("user_id", value: sonexUserId)
                .execute()
            
            print("✅ [removeRSVP] Successfully removed RSVP")
            
        } catch {
            print("❌ [removeRSVP] Failed to remove RSVP: \(error)")
            throw error
        }
    }
    
    /// Fetches discover posts created by the current user
    func fetchUserDiscoverPosts() async throws -> [DiscoverPost] {
        print("📋 [fetchUserDiscoverPosts] Fetching user's discover posts")
        
        guard userID != nil else {
            print("❌ [fetchUserDiscoverPosts] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated
        }
        
        guard isOnline else {
            print("📱 [fetchUserDiscoverPosts] Offline - cannot fetch discover posts")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            
            let posts: [DiscoverPost] = try await supabase
                .from("discover_posts")
                .select()
                .eq("author_id", value: sonexUserId)
                .eq("active", value: true)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            
            print("✅ [fetchUserDiscoverPosts] Fetched \(posts.count) user discover posts")
            return posts
            
        } catch {
            print("❌ [fetchUserDiscoverPosts] Failed to fetch user discover posts: \(error)")
            throw error
        }
    }
    
    /// Fetches discover posts that the current user has RSVPed to
    func fetchUserRSVPDiscoverPosts() async throws -> [DiscoverPostWithRSVP] {
        print("📋 [fetchUserRSVPDiscoverPosts] Fetching user's RSVP discover posts")
        
        guard userID != nil else {
            print("❌ [fetchUserRSVPDiscoverPosts] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated
        }
        
        guard isOnline else {
            print("📱 [fetchUserRSVPDiscoverPosts] Offline - cannot fetch RSVP discover posts")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            
            // Fetch RSVPs with their associated discover posts
            let response = try await supabase
                .from("event_rsvps")
                .select("""
                    id,
                    status,
                    created_at,
                    discover_post:discover_posts!event_rsvps_event_id_fkey(
                        id,
                        author_id,
                        type,
                        title,
                        description,
                        latitude,
                        longitude,
                        address,
                        metadata,
                        active,
                        created_at,
                        expires_at,
                        crate_id
                    )
                """)
                .eq("user_id", value: sonexUserId)
                .eq("discover_posts.active", value: true)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
            
            let data = response.data
            let decoder = JSONDecoder()
            let rsvpResponses = try decoder.decode([RSVPWithDiscoverPost].self, from: data)
            
            // Convert to DiscoverPostWithRSVP objects
            let postsWithRSVPs = rsvpResponses.compactMap { response -> DiscoverPostWithRSVP? in
                guard let post = response.discoverPost else { return nil }
                
                return DiscoverPostWithRSVP(
                    post: post,
                    rsvpStatus: response.status,
                    rsvpCreatedAt: response.createdAt
                )
            }
            
            print("✅ [fetchUserRSVPDiscoverPosts] Fetched \(postsWithRSVPs.count) RSVP discover posts")
            return postsWithRSVPs
            
        } catch {
            print("❌ [fetchUserRSVPDiscoverPosts] Failed to fetch RSVP discover posts: \(error)")
            throw error
        }
    }
    
    /// Fetches discover posts created by a specific user
    func fetchDiscoverPostsByUser(userId: String) async throws -> [DiscoverPost] {
        print("📋 [fetchDiscoverPostsByUser] Fetching discover posts for user: \(userId)")
        
        guard userID != nil else {
            print("❌ [fetchDiscoverPostsByUser] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated
        }
        
        guard isOnline else {
            print("📱 [fetchDiscoverPostsByUser] Offline - cannot fetch discover posts")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            let posts: [DiscoverPost] = try await supabase
                .from("discover_posts")
                .select()
                .eq("author_id", value: userId)
                .eq("active", value: true)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            
            print("✅ [fetchDiscoverPostsByUser] Fetched \(posts.count) discover posts for user")
            return posts
            
        } catch {
            print("❌ [fetchDiscoverPostsByUser] Failed to fetch discover posts: \(error)")
            throw error
        }
    }
    
    /// Fetches discover posts that a specific user has RSVPed to
    func fetchUserRSVPDiscoverPosts(for userId: String) async throws -> [DiscoverPostWithRSVP] {
        print("📋 [fetchUserRSVPDiscoverPosts] Fetching RSVP discover posts for user: \(userId)")
        
        guard userID != nil else {
            print("❌ [fetchUserRSVPDiscoverPosts] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated
        }
        
        guard isOnline else {
            print("📱 [fetchUserRSVPDiscoverPosts] Offline - cannot fetch RSVP discover posts")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            // First get the user's Sonex user ID from the userId (Firebase Auth ID)
            let userResponse: [SonexUser] = try await supabase
                .from("users")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            
            guard let targetUser = userResponse.first else {
                print("❌ [fetchUserRSVPDiscoverPosts] User not found with ID: \(userId)")
                return []
            }
            
            // Now fetch RSVPs for this user with their discover posts
            let rsvpResponses: [RSVPWithDiscoverPost] = try await supabase
                .from("event_rsvps")
                .select("""
                    id,
                    status,
                    created_at,
                    discover_post:discover_posts(*)
                """)
                .eq("user_id", value: targetUser.id)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            
            // Convert to DiscoverPostWithRSVP objects
            let postsWithRSVPs = rsvpResponses.compactMap { response -> DiscoverPostWithRSVP? in
                guard let post = response.discoverPost else { return nil }
                
                return DiscoverPostWithRSVP(
                    post: post,
                    rsvpStatus: response.status,
                    rsvpCreatedAt: response.createdAt
                )
            }
            
            print("✅ [fetchUserRSVPDiscoverPosts] Fetched \(postsWithRSVPs.count) RSVP discover posts for user")
            return postsWithRSVPs
            
        } catch {
            print("❌ [fetchUserRSVPDiscoverPosts] Failed to fetch RSVP discover posts for user: \(error)")
            throw error
        }
    }

    // MARK: - Discover Posts
    
    /// Fetches discover posts near a location with tiered restrictions based on user signature status
    func fetchDiscoverPosts(near location: SonexShared.SonexLocation? = nil, radius: Double = 1000000) async throws -> [DiscoverPost] {
        print("🗺️ [fetchDiscoverPosts] Fetching discover posts")
        
        guard userID != nil else { 
            print("❌ [fetchDiscoverPosts] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        // If offline, return empty array (could cache these in the future)
        guard isOnline else { 
            print("📱 [fetchDiscoverPosts] Offline - returning empty array")
            return []
        }
        
        print("🌐 [fetchDiscoverPosts] Online - fetching from database")
        
        do {
            // Get user's signature status to determine filtering
            let currentUser = try await fetchCurrentUser()
            let effectiveRadius = currentUser.isSignature ? radius : min(radius, 10000) // 10km max for free users
            
            print("👤 [fetchDiscoverPosts] User signature status: \(currentUser.isSignature ? "Premium" : "Free")")
            print("📏 [fetchDiscoverPosts] Using radius: \(effectiveRadius)m")
            
            let posts: [DiscoverPost] = try await supabase
                .from("discover_posts")
                .select()
                .eq("active", value: true)
                .order("created_at", ascending: false)
                .limit(currentUser.isSignature ? 200 : 50) // More posts for signature users
                .execute()
                .value
            
            print("✅ [fetchDiscoverPosts] Successfully fetched \(posts.count) discover posts")
            
            // Filter by location if provided (client-side filtering for simplicity)
            if let location = location {
                let filteredPosts = posts.filter { post in
                    // Check if post has latitude and longitude
                    guard let postLatitude = post.latitude,
                          let postLongitude = post.longitude else { 
                        return false 
                    }
                    
                    // Convert to SonexLocation for distance calculation
                    let postLocation = SonexShared.SonexLocation(
                        latitude: postLatitude,
                        longitude: postLongitude
                    )
                    
                    let distance = calculateDistance(
                        from: location,
                        to: postLocation
                    )
                    return distance <= effectiveRadius
                }
                print("🎯 [fetchDiscoverPosts] Filtered to \(filteredPosts.count) posts within \(effectiveRadius)m")
                return filteredPosts
            }
            
            return posts
            
        } catch {
            print("❌ [fetchDiscoverPosts] Failed to fetch discover posts: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [fetchDiscoverPosts] Localized error description: \(localizedError.errorDescription ?? "No description")")
            }
            throw error
        }
    }
    
    /// Fetches discover posts filtered by type (signature users only)
    func fetchDiscoverPosts(near location: SonexShared.SonexLocation? = nil, radius: Double = 1000000, types: [DiscoverPostType]? = nil) async throws -> [DiscoverPost] {
        print("🗺️ [fetchDiscoverPosts] Fetching discover posts with type filtering")
        
        guard userID != nil else { 
            print("❌ [fetchDiscoverPosts] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        // If offline, return empty array (could cache these in the future)
        guard isOnline else { 
            print("📱 [fetchDiscoverPosts] Offline - returning empty array")
            return []
        }
        
        print("🌐 [fetchDiscoverPosts] Online - fetching from database with type filtering")
        
        do {
            // Get user's signature status to determine filtering capabilities
            let currentUser = try await fetchCurrentUser()
            
            // Only signature users can filter by type
            if !currentUser.isSignature && types != nil {
                print("⚠️ [fetchDiscoverPosts] Free user attempted type filtering - ignoring filter")
            }
            
            let effectiveRadius = currentUser.isSignature ? radius : min(radius, 10000) // 10km max for free users
            let shouldFilterByTypes = currentUser.isSignature && types != nil
            
            print("👤 [fetchDiscoverPosts] User signature status: \(currentUser.isSignature ? "Premium" : "Free")")
            print("📏 [fetchDiscoverPosts] Using radius: \(effectiveRadius)m")
            print("🏷️ [fetchDiscoverPosts] Type filtering enabled: \(shouldFilterByTypes)")
            
            var query = supabase
                .from("discover_posts")
                .select()
                .eq("active", value: true)
            
            // Add type filtering for signature users
            if shouldFilterByTypes, let types = types, !types.isEmpty {
                let typeValues = types.map { $0.rawValue }
                query = query.in("type", value: typeValues)
                print("🎯 [fetchDiscoverPosts] Filtering by types: \(typeValues)")
            }
            
            let posts: [DiscoverPost] = try await query
                .order("created_at", ascending: false)
                .limit(currentUser.isSignature ? 200 : 50) // More posts for signature users
                .execute()
                .value
            
            print("✅ [fetchDiscoverPosts] Successfully fetched \(posts.count) discover posts")
            
            // Filter by location if provided (client-side filtering for simplicity)
            if let location = location {
                let filteredPosts = posts.filter { post in
                    // Check if post has latitude and longitude
                    guard let postLatitude = post.latitude,
                          let postLongitude = post.longitude else { 
                        return false 
                    }
                    
                    // Convert to SonexLocation for distance calculation
                    let postLocation = SonexShared.SonexLocation(
                        latitude: postLatitude,
                        longitude: postLongitude
                    )
                    
                    let distance = calculateDistance(
                        from: location,
                        to: postLocation
                    )
                    return distance <= effectiveRadius
                }
                print("🎯 [fetchDiscoverPosts] Filtered to \(filteredPosts.count) posts within \(effectiveRadius)m")
                return filteredPosts
            }
            
            return posts
            
        } catch {
            print("❌ [fetchDiscoverPosts] Failed to fetch discover posts: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [fetchDiscoverPosts] Localized error description: \(localizedError.errorDescription ?? "No description")")
            }
            throw error
        }
    }
    
    /// Creates a new discover post
    func createDiscoverPost(
        type: DiscoverPostType,
        title: String? = nil,
        description: String? = nil,
        location: SonexShared.SonexLocation,
        address: String? = nil,
        metadata: [String: SonexShared.AnyCodable]? = nil,
        expiresAt: Date? = nil
    ) async throws -> DiscoverPost {
        print("📝 [createDiscoverPost] Creating discover post of type: \(type.rawValue)")
        var crateId : String?  = nil
        guard let uid = userID else {
            print("❌ [createDiscoverPost] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        guard isOnline else {
            print("❌ [createDiscoverPost] Cannot create post while offline")
            throw SonexDBError.noNetworkConnection
        }
        
        print("🌐 [createDiscoverPost] Online mode - creating in database")
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            print("👤 [createDiscoverPost] Sonex user ID: \(sonexUserId)")
            
            // Prepare metadata and add For Sale crate ID if this is a crate drop
            var finalMetadata = metadata
            
            if type == .crateDrop {
                print("📦 [createDiscoverPost] Crate drop detected - adding For Sale crate ID to metadata")
                do {
                    let forSaleCrateId = try await resolveForSaleCrateId()
                    crateId = forSaleCrateId
                    print("📦 [createDiscoverPost] For Sale crate ID: \(forSaleCrateId)")
                    
                    // Initialize metadata if it's nil
                    if finalMetadata == nil {
                        finalMetadata = [:]
                    }
                    
                    // Add the crate_id to metadata
                    finalMetadata?["crate_id"] = SonexShared.AnyCodable(forSaleCrateId)
                    
                    print("✅ [createDiscoverPost] Added For Sale crate ID to metadata")
                    
                } catch {
                    print("⚠️ [createDiscoverPost] Failed to resolve For Sale crate ID: \(error)")
                    // Continue without the crate ID rather than failing the entire operation
                }
            }
            
            // First, try the RPC approach (most reliable for PostGIS)
//            let success = await tryCreateDiscoverPostWithRPC(
//                sonexUserId: sonexUserId,
//                type: type,
//                title: title,
//                description: description,
//                location: location,
//                address: address,
//                metadata: finalMetadata,
//                expiresAt: expiresAt
//            )
//            
//            if let post = success {
//                return post
//            }
            
            // Fallback to direct insertion approach
            return try await createDiscoverPostDirect(
                sonexUserId: sonexUserId,
                type: type,
                title: title,
                description: description,
                location: location,
                address: address,
                metadata: finalMetadata,
                expiresAt: expiresAt,
                crateId: crateId
            )
            
        } catch {
            print("❌ [createDiscoverPost] Failed to create discover post: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [createDiscoverPost] Localized error description: \(localizedError.errorDescription ?? "No description")")
            }
            throw error
        }
    }
    
    // MARK: - Helper Methods for Discover Post Creation
    
//    /// Try creating discover post using RPC function (recommended for PostGIS)
//    private func tryCreateDiscoverPostWithRPC(
//        sonexUserId: String,
//        type: DiscoverPostType,
//        title: String?,
//        description: String?,
//        location: SonexShared.SonexLocation,
//        address: String?,
//        metadata: [String: SonexShared.AnyCodable]?,
//        expiresAt: Date?
//    ) async -> DiscoverPost? {
//        
//        print("🔄 [tryCreateDiscoverPostWithRPC] Attempting RPC creation")
//        
//        do {
//            // Format the expires_at date in ISO8601 format if provided
//            let expiresAtString: String? = expiresAt?.ISO8601Format()
//            
//            let rpcParams = CreateDiscoverPostRPCParams(
//                p_author_id: sonexUserId,
//                p_type: type.rawValue,
//                p_latitude: location.latitude,
//                p_longitude: location.longitude,
//                p_title: title,
//                p_description: description,
//                p_address: address,
//                p_metadata: metadata,
//                p_expires_at: expiresAtString
//            )
//            
//            print("📄 [tryCreateDiscoverPostWithRPC] RPC parameters created")
//            
//            // Call the RPC function with properly typed parameters
//            let response = try await supabase
//                .rpc("create_discover_post", params: rpcParams)
//                .execute()
//            
//            // Parse the response as DiscoverPost
//            let newPost: DiscoverPost = response.value
//            
//            print("✅ [tryCreateDiscoverPostWithRPC] Successfully created discover post with RPC")
//            return newPost
//            
//        } catch {
//            print("⚠️ [tryCreateDiscoverPostWithRPC] RPC method failed with error: \(error)")
//            
//            // Log more detailed error information for debugging
//            if let localizedError = error as? LocalizedError {
//                print("⚠️ [tryCreateDiscoverPostWithRPC] Error description: \(localizedError.errorDescription ?? "Unknown error")")
//            }
//            
//            // Check if it's a specific Supabase or network error
//            if error.localizedDescription.contains("function") || 
//               error.localizedDescription.contains("rpc") ||
//               error.localizedDescription.contains("procedure") {
//                print("⚠️ [tryCreateDiscoverPostWithRPC] RPC function might not exist or has parameter mismatch")
//            }
//            
//            return nil
//        }
//    }
    
    /// Direct insertion method as fallback
    private func createDiscoverPostDirect(
        sonexUserId: String,
        type: DiscoverPostType,
        title: String?,
        description: String?,
        location: SonexShared.SonexLocation,
        address: String?,
        metadata: [String: SonexShared.AnyCodable]?,
        expiresAt: Date?,
        crateId: String?
    ) async throws -> DiscoverPost {
        print("🔄 [createDiscoverPostDirect] Attempting direct insertion")
        
        // Try approach 1: Send latitude and longitude separately
        // This requires the database to have a trigger or computed column for the location geometry
        do {
            return try await createDiscoverPostWithLatLng(
                sonexUserId: sonexUserId,
                type: type,
                title: title,
                description: description,
                location: location,
                address: address,
                metadata: metadata,
                expiresAt: expiresAt,
                crateId: crateId
            )
        } catch {
            print("⚠️ [createDiscoverPostDirect] Lat/Lng approach failed: \(error)")
        }
        
        // Try approach 2: Send as GeoJSON
        do {
            return try await createDiscoverPostWithGeoJSON(
                sonexUserId: sonexUserId,
                type: type,
                title: title,
                description: description,
                location: location,
                address: address,
                metadata: metadata,
                expiresAt: expiresAt,
                crateId: crateId
            )
        } catch {
            print("⚠️ [createDiscoverPostDirect] GeoJSON approach failed: \(error)")
            throw error
        }
    }
    
    /// Method that sends lat/lng separately (requires database trigger or computed column)
    private func createDiscoverPostWithLatLng(
        sonexUserId: String,
        type: DiscoverPostType,
        title: String?,
        description: String?,
        location: SonexShared.SonexLocation,
        address: String?,
        metadata: [String: SonexShared.AnyCodable]?,
        expiresAt: Date?,
        crateId: String?
    ) async throws -> DiscoverPost {
        
        struct DiscoverPostLatLngPayload: Codable {
            let author_id: String
            let type: String
            let title: String?
            let description: String?
            let latitude: Double
            let longitude: Double
            let address: String?
            let metadata: [String: SonexShared.AnyCodable]?
            let active: Bool
            let expires_at: String?
            let crate_id: String?
        }
        
        let expiresAtString = expiresAt?.ISO8601Format()
        
        let payload = DiscoverPostLatLngPayload(
            author_id: sonexUserId,
            type: type.rawValue,
            title: title,
            description: description,
            latitude: location.latitude,
            longitude: location.longitude,
            address: address,
            metadata: metadata,
            active: true,
            expires_at: expiresAtString,
            crate_id: crateId
        )
        
        print("📄 [createDiscoverPostWithLatLng] Using lat/lng payload")
        
        let newPost: DiscoverPost = try await supabase
            .from("discover_posts")
            .insert(payload, returning: .representation)
            .select()
            .single()
            .execute()
            .value
        
        print("✅ [createDiscoverPostWithLatLng] Success with lat/lng approach")
        return newPost
    }
    
    /// Method that sends location as GeoJSON
    private func createDiscoverPostWithGeoJSON(
        sonexUserId: String,
        type: DiscoverPostType,
        title: String?,
        description: String?,
        location: SonexShared.SonexLocation,
        address: String?,
        metadata: [String: SonexShared.AnyCodable]?,
        expiresAt: Date?,
        crateId: String? = nil
    ) async throws -> DiscoverPost {
        
        struct DiscoverPostGeoJSONPayload: Codable {
            let author_id: String
            let type: String
            let title: String?
            let description: String?
            let location: PostGISPointForInsertion
            let address: String?
            let metadata: [String: SonexShared.AnyCodable]?
            let active: Bool
            let expires_at: String?
            let crate_id: String?
        }
        
        // Custom struct for PostGIS insertion that encodes properly
        struct PostGISPointForInsertion: Codable {
            let type: String = "Point"
            let coordinates: [Double]
            
            init(latitude: Double, longitude: Double) {
                self.coordinates = [longitude, latitude]
            }
        }
        
        let expiresAtString = expiresAt?.ISO8601Format()
        
        let payload = DiscoverPostGeoJSONPayload(
            author_id: sonexUserId,
            type: type.rawValue,
            title: title,
            description: description,
            location: PostGISPointForInsertion(latitude: location.latitude, longitude: location.longitude),
            address: address,
            metadata: metadata,
            active: true,
            expires_at: expiresAtString,
            crate_id: crateId
        )
        
        print("📄 [createDiscoverPostWithGeoJSON] Using GeoJSON payload")
        
        let newPost: DiscoverPost = try await supabase
            .from("discover_posts")
            .insert(payload, returning: .representation)
            .select()
            .single()
            .execute()
            .value
        
        print("✅ [createDiscoverPostWithGeoJSON] Success with GeoJSON approach")
        return newPost
    }
    
    /// Updates a discover post (only the author can update)
    func updateDiscoverPost(_ postId: String, title: String? = nil, description: String? = nil) async throws {
        print("✏️ [updateDiscoverPost] Updating discover post: \(postId)")
        
        guard userID != nil else { 
            print("❌ [updateDiscoverPost] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        guard isOnline else {
            print("❌ [updateDiscoverPost] Cannot update post while offline")
            throw SonexDBError.noNetworkConnection
        }
        
        print("🌐 [updateDiscoverPost] Online mode - updating in database")
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            
            struct UpdatePayload: Codable {
                let title: String?
                let description: String?
            }
            
            try await supabase
                .from("discover_posts")
                .update(UpdatePayload(title: title, description: description))
                .eq("id", value: postId)
                .eq("author_id", value: sonexUserId) // Only author can update
                .execute()
            
            print("✅ [updateDiscoverPost] Successfully updated discover post")
            
        } catch {
            print("❌ [updateDiscoverPost] Failed to update discover post: \(error)")
            throw error
        }
    }
    
    /// Deactivates a discover post (only the author can deactivate)
    func deactivateDiscoverPost(_ postId: String) async throws {
        print("🗑️ [deactivateDiscoverPost] Deactivating discover post: \(postId)")
        
        guard userID != nil else { 
            print("❌ [deactivateDiscoverPost] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        guard isOnline else {
            print("❌ [deactivateDiscoverPost] Cannot deactivate post while offline")
            throw SonexDBError.noNetworkConnection
        }
        
        print("🌐 [deactivateDiscoverPost] Online mode - deactivating in database")
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            
            try await supabase
                .from("discover_posts")
                .update(["active": false])
                .eq("id", value: postId)
                .eq("author_id", value: sonexUserId) // Only author can deactivate
                .execute()
            
            print("✅ [deactivateDiscoverPost] Successfully deactivated discover post")
            
        } catch {
            print("❌ [deactivateDiscoverPost] Failed to deactivate discover post: \(error)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    /// Calculates the distance between two locations in meters
    private func calculateDistance(from location1: SonexShared.SonexLocation, to location2: SonexShared.SonexLocation) -> Double {
        let coordinate1 = CLLocation(latitude: location1.latitude, longitude: location1.longitude)
        let coordinate2 = CLLocation(latitude: location2.latitude, longitude: location2.longitude)
        return coordinate1.distance(from: coordinate2)
    }
    
    // MARK: - Vinyl Entries
    
    /// Checks if an NFC tag is already registered to a vinyl entry
    func checkNFCTagRegistration(tagHash: String) async throws -> VinylEntry? {
        print("🏷️ [checkNFCTagRegistration] Checking registration for tag hash: \(tagHash)")
        
        guard userID != nil else { 
            print("❌ [checkNFCTagRegistration] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        // If offline, we can't check registration status
        guard isOnline else { 
            print("📱 [checkNFCTagRegistration] Offline - cannot check registration")
            throw SonexDBError.noNetworkConnection 
        }
        
        print("🌐 [checkNFCTagRegistration] Online - checking database for existing registration")
        
        do {
            let entries: [VinylEntry] = try await supabase
                .from("vinyl_entries")
                .select()
                .eq("nfc_tag_hash", value: tagHash)
                .limit(1)
                .execute()
                .value
            
            if let existingEntry = entries.first {
                print("⚠️ [checkNFCTagRegistration] Tag already registered to vinyl: '\(existingEntry.title)' by '\(existingEntry.artist)' (ID: \(existingEntry.id))")
                return existingEntry
            } else {
                print("✅ [checkNFCTagRegistration] Tag is available for registration")
                return nil
            }
            
        } catch {
            print("❌ [checkNFCTagRegistration] Failed to check NFC tag registration: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [checkNFCTagRegistration] Localized error description: \(localizedError.errorDescription ?? "No description")")
            }
            throw error
        }
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
        mediaGrade: VinylGrade? = nil,
        gradeNotes: String? = nil,
        coverArtUrl: String? = nil,
        forSale: Bool = false,
        askingPrice: Double? = nil,
        catalogNumber: String? = nil,
        matrixCode: String? = nil,
        barcode: String? = nil,
        releaseEdition: ReleaseEdition = .standard,
        editionNotes: String? = nil,
        sleeveGrade: VinylGrade? = nil,
        locationNote: String? = nil
    ) async throws -> VinylEntry {
        print("🎵 [registerVinyl] Starting vinyl registration for '\(title)' by '\(artist)'")
        
        guard userID != nil else { 
            print("❌ [registerVinyl] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        print("🔍 [registerVinyl] User authenticated with ID: \(userID!)")
        
        let resolvedCrateId: String
        if let crateId = crateId {
            resolvedCrateId = crateId
            print("📦 [registerVinyl] Using provided crate ID: \(crateId)")
        } else {
            print("📦 [registerVinyl] Resolving unsorted crate ID...")
            do {
                resolvedCrateId = try await resolveUnsortedCrateId()
                print("📦 [registerVinyl] Resolved unsorted crate ID: \(resolvedCrateId)")
            } catch {
                print("❌ [registerVinyl] Failed to resolve unsorted crate ID: \(error)")
                throw error
            }
        }
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            print("👤 [registerVinyl] Sonex user ID: \(sonexUserId)")
            
            let payload = VinylEntryPayload(
                ownerId: sonexUserId,
                title: title,
                artist: artist,
                discogsId: discogsId,
                nfcTagHash: nfcTagHash,
                label: label,
                year: year,
                pressing: pressing,
                format: format,
                mediaGrade: mediaGrade?.rawValue,
                gradeNotes: gradeNotes,
                coverArtUrl: coverArtUrl,
                forSale: forSale,
                askingPrice: askingPrice,
                catalogNumber: catalogNumber,
                matrixCode: matrixCode,
                barcode: barcode,
                releaseEdition: releaseEdition,
                editionNotes: editionNotes,
                sleeveGrade: sleeveGrade?.rawValue,
                locationNote: locationNote
            )
            
            // Debug: Log the payload being sent to database
            print("📄 [registerVinyl] Database payload:")
            print("   - Title: '\(title)'")
            print("   - Artist: '\(artist)'")
            print("   - Owner ID: '\(sonexUserId)'")
            print("   - Release Edition: '\(releaseEdition.rawValue)'")
            print("   - Edition Notes: '\(editionNotes ?? "nil")'")
            print("   - For Sale: \(forSale)")
            print("   - Discogs ID: '\(discogsId ?? "nil")'")
            print("   - NFC Tag Hash: '\(nfcTagHash ?? "nil")'")
            print("   - Cover Art URL: '\(coverArtUrl ?? "nil")'")
            
            // If offline, queue the operation
            if !isOnline {
                print("📱 [registerVinyl] Offline mode - creating optimistic entry and queuing operation")
                
                // Create optimistic vinyl entry
                let optimisticEntry = VinylEntry(
                    id: UUID().uuidString,
                    ownerId: sonexUserId,
                    discogsId: discogsId,
                    nfcTagHash: nfcTagHash,
                    title: title,
                    artist: artist,
                    label: label,
                    year: year,
                    pressing: pressing,
                    format: format,
                    mediaGrade: mediaGrade,
                    gradeNotes: gradeNotes,
                    coverArtUrl: coverArtUrl,
                    forSale: forSale,
                    askingPrice: askingPrice,
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    catalogNumber: catalogNumber,
                    matrixCode: matrixCode,
                    barcode: barcode,
                    releaseEdition: releaseEdition,
                    editionNotes: editionNotes,
                    sleeveGrade: sleeveGrade,
                    locationNote: locationNote
                )
                
                print("🎯 [registerVinyl] Created optimistic entry with ID: \(optimisticEntry.id)")
                
                // Add to appropriate crate
                if forSale {
                    print("💰 [registerVinyl] Adding to For Sale crate (offline)")
                    try await addVinylToCrate(vinylId: optimisticEntry.id, crateId: try await resolveForSaleCrateId())
                }
                
                print("📦 [registerVinyl] Adding to target crate: \(resolvedCrateId) (offline)")
                try await addVinylToCrate(vinylId: optimisticEntry.id, crateId: resolvedCrateId)
                
                // Queue for server sync
                if let data = try? JSONEncoder().encode(payload) {
                    let operation = PendingOperation(
                        type: .createVinyl,
                        timestamp: Date(),
                        data: data
                    )
                    cacheManager.addPendingOperation(operation)
                    print("⏳ [registerVinyl] Queued operation for sync when online")
                }
                
                print("✅ [registerVinyl] Offline vinyl registration complete")
                return optimisticEntry
            }
            
            print("🌐 [registerVinyl] Online mode - inserting into database")
            
            let newVinyl: VinylEntry = try await supabase
                .from("vinyl_entries")
                .insert(payload, returning: .representation)
                .select()
                .single()
                .execute()
                .value
            
            print("✅ [registerVinyl] Successfully created vinyl entry with ID: \(newVinyl.id)")
            
            // Add to For Sale crate if marked for sale
            if forSale {
                print("💰 [registerVinyl] Adding to For Sale crate")
                do {
                    let forSaleCrateId = try await resolveForSaleCrateId()
                    try await addVinylToCrate(vinylId: newVinyl.id, crateId: forSaleCrateId)
                    print("✅ [registerVinyl] Successfully added to For Sale crate: \(forSaleCrateId)")
                } catch {
                    print("❌ [registerVinyl] Failed to add to For Sale crate: \(error)")
                    // Don't throw here, as the vinyl was created successfully
                }
            }
            
            print("📦 [registerVinyl] Adding to target crate: \(resolvedCrateId)")
            do {
                try await addVinylToCrate(vinylId: newVinyl.id, crateId: resolvedCrateId)
                print("✅ [registerVinyl] Successfully added to target crate")
            } catch {
                print("❌ [registerVinyl] Failed to add to target crate: \(error)")
                // Don't throw here, as the vinyl was created successfully
            }
            
            print("🎵 [registerVinyl] Vinyl registration completed successfully")
            return newVinyl
            
        } catch {
            print("❌ [registerVinyl] Registration failed with error: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [registerVinyl] Localized error description: \(localizedError.errorDescription ?? "No description")")
            }
            throw error
        }
    }
    
    func fetchVinylEntries(inCrate crateId: String, forceRefresh: Bool = false) async throws -> [VinylEntry] {
        print("🔍 [fetchVinylEntries] Starting fetch for crate ID: \(crateId), forceRefresh: \(forceRefresh)")
        
        guard userID != nil else { 
            print("❌ [fetchVinylEntries] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        // Return cached data if available and valid, unless force refresh is requested
        if !forceRefresh, isVinylEntriesCacheValid(forCrate: crateId), let cachedEntries = _cachedVinylEntries[crateId] {
            print("✅ [fetchVinylEntries] Returning \(cachedEntries.count) cached vinyl entries for crate")
            return cachedEntries
        }
        
        // If offline, return cached data if available
        if !isOnline {
            print("📱 [fetchVinylEntries] Offline mode")
            if let cachedEntries = _cachedVinylEntries[crateId] {
                print("✅ [fetchVinylEntries] Returning \(cachedEntries.count) cached vinyl entries for crate")
                return cachedEntries
            } else if let cachedEntries = cacheManager.getCachedVinylEntries(forCrate: crateId) {
                // Load from persistent cache if not in memory
                print("✅ [fetchVinylEntries] Loading \(cachedEntries.count) vinyl entries from persistent cache")
                _cachedVinylEntries[crateId] = cachedEntries
                _vinylEntriesCacheTimestamps[crateId] = cacheManager.getVinylEntriesCacheTimestamp(forCrate: crateId) ?? Date()
                return cachedEntries
            } else {
                print("❌ [fetchVinylEntries] No cached data available offline")
                throw SonexDBError.noNetworkConnection
            }
        }
        
        print("🌐 [fetchVinylEntries] Online mode - fetching from database")
        
        do {
            // Query vinyl entries in this crate
            // Since PostgREST has issues with ordering by joined table columns,
            // we'll fetch the data and sort it in Swift
            let vinylEntries: [VinylEntry] = try await supabase
                .from("vinyl_entries")
                .select("""
                    *,
                    vinyl_crates!inner(crate_id, added_at)
                """)
                .eq("vinyl_crates.crate_id", value: crateId)
                .execute()
                .value
            
            print("✅ [fetchVinylEntries] Successfully fetched \(vinylEntries.count) vinyl entries for crate \(crateId)")
            
            // Update cache
            await updateVinylEntriesCache(vinylEntries, forCrate: crateId)
            
            // Preload cover art for better performance
            preloadCoverArt(for: vinylEntries)
            
            // Log first few entries for debugging
            let logCount = min(3, vinylEntries.count)
            for (index, entry) in vinylEntries.prefix(logCount).enumerated() {
                print("📀 [fetchVinylEntries] Entry \(index + 1): '\(entry.title)' by '\(entry.artist)' (ID: \(entry.id))")
            }
            
            if vinylEntries.count > logCount {
                print("📀 [fetchVinylEntries] ... and \(vinylEntries.count - logCount) more entries")
            }
            
            return vinylEntries
            
        } catch {
            print("❌ [fetchVinylEntries] Failed to fetch vinyl entries: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [fetchVinylEntries] Localized error description: \(localizedError.errorDescription ?? "No description")")
            }
            throw error
        }
    }
    
    func moveVinyl(entryId: String, fromCrate fromCrateId: String, toCrate toCrateId: String) async throws {
        print("🚚 [moveVinyl] Starting move operation")
        print("   - Vinyl ID: \(entryId)")
        print("   - From Crate ID: \(fromCrateId)")
        print("   - To Crate ID: \(toCrateId)")
        
        guard userID != nil else { 
            print("❌ [moveVinyl] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }

        if !isOnline {
            print("📱 [moveVinyl] Offline mode - queuing operation for later sync")
            
            // Queue for later if offline
            struct MoveVinylPayload: Codable {
                let entryId: String
                let fromCrateId: String
                let toCrateId: String
            }
            
            if let data = try? JSONEncoder().encode(MoveVinylPayload(entryId: entryId, fromCrateId: fromCrateId, toCrateId: toCrateId)) {
                let operation = PendingOperation(
                    type: .moveVinyl,
                    timestamp: Date(),
                    data: data
                )
                cacheManager.addPendingOperation(operation)
                print("⏳ [moveVinyl] Queued move operation for sync when online")
            }
            return
        }
        
        print("🌐 [moveVinyl] Online mode - executing move operation")
        
        do {
            // Remove from old crate
            print("🗑️ [moveVinyl] Removing vinyl from source crate: \(fromCrateId)")
            try await removeVinylFromCrate(vinylId: entryId, crateId: fromCrateId)
            print("✅ [moveVinyl] Successfully removed from source crate")
            
            // Add to new crate
            print("📦 [moveVinyl] Adding vinyl to destination crate: \(toCrateId)")
            try await addVinylToCrate(vinylId: entryId, crateId: toCrateId)
            print("✅ [moveVinyl] Successfully added to destination crate")
            
            print("🚚 [moveVinyl] Move operation completed successfully")
            
        } catch {
            print("❌ [moveVinyl] Move operation failed: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [moveVinyl] Localized error description: \(localizedError.errorDescription ?? "No description")")
            }
            throw error
        }
    }
    
    /// Moves multiple vinyl entries from one crate to another in a single transaction-like operation
    func moveVinyls(entryIds: [String], fromCrate fromCrateId: String, toCrate toCrateId: String) async throws {
        print("🚚 [moveVinyls] Starting bulk move operation")
        print("   - Vinyl IDs: \(entryIds)")
        print("   - From Crate ID: \(fromCrateId)")
        print("   - To Crate ID: \(toCrateId)")
        print("   - Count: \(entryIds.count) records")
        
        guard userID != nil else { 
            print("❌ [moveVinyls] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }

        guard !entryIds.isEmpty else {
            print("⚠️ [moveVinyls] No vinyl IDs provided, skipping operation")
            return
        }

        if !isOnline {
            print("📱 [moveVinyls] Offline mode - queuing operations for later sync")
            
            // Queue individual move operations for later if offline
            for entryId in entryIds {
                struct MoveVinylPayload: Codable {
                    let entryId: String
                    let fromCrateId: String
                    let toCrateId: String
                }
                
                if let data = try? JSONEncoder().encode(MoveVinylPayload(entryId: entryId, fromCrateId: fromCrateId, toCrateId: toCrateId)) {
                    let operation = PendingOperation(
                        type: .moveVinyl,
                        timestamp: Date(),
                        data: data
                    )
                    cacheManager.addPendingOperation(operation)
                }
            }
            print("⏳ [moveVinyls] Queued \(entryIds.count) move operations for sync when online")
            return
        }
        
        print("🌐 [moveVinyls] Online mode - executing bulk move operations")
        
        var successCount = 0
        var failureCount = 0
        
        // Process each vinyl move sequentially to avoid overwhelming the database
        for (index, entryId) in entryIds.enumerated() {
            print("🔄 [moveVinyls] Processing \(index + 1)/\(entryIds.count): \(entryId)")
            
            do {
                // Remove from old crate
                try await removeVinylFromCrate(vinylId: entryId, crateId: fromCrateId)
                
                // Add to new crate
                try await addVinylToCrate(vinylId: entryId, crateId: toCrateId)
                
                successCount += 1
                print("✅ [moveVinyls] Successfully moved vinyl \(index + 1)/\(entryIds.count)")
                
            } catch {
                failureCount += 1
                print("❌ [moveVinyls] Failed to move vinyl \(entryId): \(error)")
                
                // Continue with other vinyls rather than failing the entire operation
                // You might want to collect these errors and show them to the user
            }
        }
        
        print("🎯 [moveVinyls] Bulk move operation completed")
        print("   - Successful moves: \(successCount)")
        print("   - Failed moves: \(failureCount)")
        print("   - Total processed: \(entryIds.count)")
        
        if failureCount > 0 {
            let partialError = NSError(
                domain: "SonexDB",
                code: 422,
                userInfo: [
                    NSLocalizedDescriptionKey: "Some records could not be moved (\(failureCount) of \(entryIds.count) failed)",
                    "successCount": successCount,
                    "failureCount": failureCount,
                    "totalCount": entryIds.count
                ]
            )
            throw partialError
        }
    }
    
    func updateVinylSaleStatus(entryId: String, forSale: Bool, askingPrice: Double?) async throws {
        print("💰 [updateVinylSaleStatus] Updating sale status for vinyl \(entryId)")
        print("   - For Sale: \(forSale)")
        print("   - Asking Price: \(askingPrice?.description ?? "nil")")
        
        guard userID != nil else { 
            print("❌ [updateVinylSaleStatus] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        struct SalePatch: Encodable {
            let for_sale: Bool
            let asking_price: Double?
        }
        
        if !isOnline {
            print("📱 [updateVinylSaleStatus] Offline mode - queuing operation for later sync")
            
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
                print("⏳ [updateVinylSaleStatus] Queued sale status update for sync when online")
            }
            return
        }
        
        print("🌐 [updateVinylSaleStatus] Online mode - updating database")
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            print("👤 [updateVinylSaleStatus] Sonex user ID: \(sonexUserId)")
            
            try await supabase
                .from("vinyl_entries")
                .update(SalePatch(for_sale: forSale, asking_price: askingPrice))
                .eq("id", value: entryId)
                .eq("owner_id", value: sonexUserId)
                .execute()
            
            print("✅ [updateVinylSaleStatus] Successfully updated vinyl sale status in database")
            
            // Update For Sale crate
            if forSale {
                print("📦 [updateVinylSaleStatus] Adding vinyl to For Sale crate")
                do {
                    let forSaleCrateId = try await resolveForSaleCrateId()
                    try await addVinylToCrate(vinylId: entryId, crateId: forSaleCrateId)
                    print("✅ [updateVinylSaleStatus] Successfully added to For Sale crate")
                } catch {
                    print("❌ [updateVinylSaleStatus] Failed to add to For Sale crate: \(error)")
                    // Don't throw here, as the vinyl was updated successfully
                }
            } else {
                print("📦 [updateVinylSaleStatus] Removing vinyl from For Sale crate")
                do {
                    let forSaleCrateId = try await resolveForSaleCrateId()
                    try await removeVinylFromCrate(vinylId: entryId, crateId: forSaleCrateId)
                    print("✅ [updateVinylSaleStatus] Successfully removed from For Sale crate")
                } catch {
                    print("❌ [updateVinylSaleStatus] Failed to remove from For Sale crate: \(error)")
                    // Don't throw here, as the vinyl was updated successfully
                }
            }
            
            print("💰 [updateVinylSaleStatus] Sale status update completed successfully")
            
        } catch {
            print("❌ [updateVinylSaleStatus] Failed to update sale status: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [updateVinylSaleStatus] Localized error description: \(localizedError.errorDescription ?? "No description")")
            }
            throw error
        }
    }
    
    func deleteVinyl(entryId: String) async throws {
        print("🗑️ [deleteVinyl] Starting deletion for vinyl ID: \(entryId)")
        
        guard userID != nil else { 
            print("❌ [deleteVinyl] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        if !isOnline {
            print("📱 [deleteVinyl] Offline mode - queuing deletion for later sync")
            
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
                print("⏳ [deleteVinyl] Queued deletion operation for sync when online")
            }
            return
        }
        
        print("🌐 [deleteVinyl] Online mode - deleting from database")
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            print("👤 [deleteVinyl] Sonex user ID: \(sonexUserId)")
            
            // First fetch the vinyl entry to get cover art URL for cleanup
            let vinylEntries: [VinylEntry] = try await supabase
                .from("vinyl_entries")
                .select("*")
                .eq("id", value: entryId)
                .eq("owner_id", value: sonexUserId)
                .execute()
                .value
            
            let vinyl = vinylEntries.first
            print("📀 [deleteVinyl] Found vinyl entry: \(vinyl?.title ?? "Unknown")")
            
            // Delete the vinyl entry (this will cascade delete vinyl_crates relationships)
            try await supabase
                .from("vinyl_entries")
                .delete()
                .eq("id", value: entryId)
                .eq("owner_id", value: sonexUserId)
                .execute()
            
            print("✅ [deleteVinyl] Successfully deleted vinyl entry from database")
            
            // Clean up cover art from storage if it exists and is a Supabase URL
            if let coverArtUrl = vinyl?.coverArtUrl,
               !coverArtUrl.isEmpty,
               isSupabaseStorageUrl(coverArtUrl) {
                
                print("🖼️ [deleteVinyl] Cleaning up cover art from storage: \(coverArtUrl)")
                
                do {
                    try await deleteCoverArtFromStorage(url: coverArtUrl)
                    print("✅ [deleteVinyl] Successfully cleaned up cover art from storage")
                } catch {
                    print("⚠️ [deleteVinyl] Warning: Failed to clean up cover art from storage: \(error)")
                    // Don't throw here as the main deletion was successful
                }
            }
            
            print("🗑️ [deleteVinyl] Vinyl deletion completed successfully")
            
        } catch {
            print("❌ [deleteVinyl] Failed to delete vinyl: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [deleteVinyl] Localized error description: \(localizedError.errorDescription ?? "No description")")
            }
            throw error
        }
    }
    
    /// Helper method to check if a URL is from Supabase storage
    private func isSupabaseStorageUrl(_ urlString: String) -> Bool {
        return urlString.contains("supabase") && urlString.contains("/storage/v1/object/")
    }

    func updateVinylLocationNote(entryId: String, locationNote: String?) async throws {
        guard userID != nil else { throw SonexDBError.notAuthenticated }
        
        if !isOnline {
            // Queue for later if offline
            struct UpdateLocationNotePayload: Codable {
                let entryId: String
                let locationNote: String?
            }
            
            if let data = try? JSONEncoder().encode(UpdateLocationNotePayload(entryId: entryId, locationNote: locationNote)) {
                let operation = PendingOperation(
                    type: .updateLocationNote,
                    timestamp: Date(),
                    data: data
                )
                cacheManager.addPendingOperation(operation)
            }
            return
        }
        
        try await updateVinylLocationNoteOnServer(entryId: entryId, locationNote: locationNote)
    }
    
    private func updateVinylLocationNoteOnServer(entryId: String, locationNote: String?) async throws {
        struct LocationNotePatch: Encodable {
            let location_note: String?
        }
        
        try await supabase
            .from("vinyl_entries")
            .update(LocationNotePatch(location_note: locationNote))
            .eq("id", value: entryId)
            .eq("owner_id", value: try await getCurrentSonexUserId())
            .execute()
    }
    
    // MARK: - Crate Management Helpers
    
    /// Adds a vinyl entry to a crate using the vinyl_crates junction table
    private func addVinylToCrate(vinylId: String, crateId: String) async throws {
        print("➕ [addVinylToCrate] Adding vinyl \(vinylId) to crate \(crateId)")
        
        do {
            // Check if the relationship already exists
            print("🔍 [addVinylToCrate] Checking for existing relationship...")
            let existingRelations: [VinylCrateRelation] = try await supabase
                .from("vinyl_crates")
                .select("id")
                .eq("vinyl_id", value: vinylId)
                .eq("crate_id", value: crateId)
                .limit(1)
                .execute()
                .value
            
            print("🔍 [addVinylToCrate] Found \(existingRelations.count) existing relationships")
            
            // If relationship doesn't exist, create it
            if existingRelations.isEmpty {
                print("📝 [addVinylToCrate] Creating new vinyl-crate relationship")
                
                struct VinylCratePayload: Codable {
                    let vinyl_id: String
                    let crate_id: String
                }
                
                try await supabase
                    .from("vinyl_crates")
                    .insert(VinylCratePayload(vinyl_id: vinylId, crate_id: crateId))
                    .execute()
                
                print("✅ [addVinylToCrate] Successfully created vinyl-crate relationship")
            } else {
                print("ℹ️ [addVinylToCrate] Relationship already exists, skipping creation")
            }
            
            // Clear crates cache to force refresh
            print("🔄 [addVinylToCrate] Clearing crates cache")
            await clearCratesCache()
            
            // Clear vinyl entries cache for this crate
            print("🔄 [addVinylToCrate] Clearing vinyl entries cache for crate")
            await clearVinylEntriesCache(forCrate: crateId)
            
        } catch {
            print("❌ [addVinylToCrate] Failed to add vinyl to crate: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [addVinylToCrate] Localized error description: \(localizedError.errorDescription ?? "No description")")
            }
            throw error
        }
    }
    
    /// Removes a vinyl entry from a crate using the vinyl_crates junction table
    private func removeVinylFromCrate(vinylId: String, crateId: String) async throws {
        print("➖ [removeVinylFromCrate] Removing vinyl \(vinylId) from crate \(crateId)")
        
        do {
            // First, check if the relationship exists
            let existingRelations: [VinylCrateRelation] = try await supabase
                .from("vinyl_crates")
                .select("*")
                .eq("vinyl_id", value: vinylId)
                .eq("crate_id", value: crateId)
                .execute()
                .value
            
            print("🔍 [removeVinylFromCrate] Found \(existingRelations.count) existing relationships to remove")
            
            if existingRelations.isEmpty {
                print("⚠️ [removeVinylFromCrate] No relationship found to remove - vinyl may not be in this crate")
                return
            }
            
            // Now remove the relationship
            try await supabase
                .from("vinyl_crates")
                .delete()
                .eq("vinyl_id", value: vinylId)
                .eq("crate_id", value: crateId)
                .execute()
            
            print("✅ [removeVinylFromCrate] Successfully removed vinyl-crate relationship")
            
            // Verify removal
            let remainingRelations: [VinylCrateRelation] = try await supabase
                .from("vinyl_crates")
                .select("*")
                .eq("vinyl_id", value: vinylId)
                .eq("crate_id", value: crateId)
                .execute()
                .value
            
            if remainingRelations.isEmpty {
                print("✅ [removeVinylFromCrate] Verified: relationship successfully removed")
            } else {
                print("⚠️ [removeVinylFromCrate] Warning: \(remainingRelations.count) relationships still exist after deletion")
            }
            
            // Clear crates cache to force refresh
            print("🔄 [removeVinylFromCrate] Clearing crates cache")
            await clearCratesCache()
            
            // Clear vinyl entries cache for this crate
            print("🔄 [removeVinylFromCrate] Clearing vinyl entries cache for crate")
            await clearVinylEntriesCache(forCrate: crateId)
            
        } catch {
            print("❌ [removeVinylFromCrate] Failed to remove vinyl from crate: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [removeVinylFromCrate] Localized error description: \(localizedError.errorDescription ?? "No description")")
            }
            throw error
        }
    }
    
    /// Fetches all cover art URLs and vinyl entry IDs for a specific crate
    func fetchCrateArtwork(crateId: String) async throws -> [CrateArtworkItem] {
        guard userID != nil else { throw SonexDBError.notAuthenticated }
        guard isOnline else { throw SonexDBError.noNetworkConnection }
        
        // Fetch vinyl entries with their cover art URLs for this crate
        let artworkData: [CrateArtworkItem] = try await supabase
            .from("vinyl_entries")
            .select("""
                id,
                cover_art_url,
                title,
                artist,
                vinyl_crates!inner(added_at)
            """)
            .eq("vinyl_crates.crate_id", value: crateId)
            .order("vinyl_crates.added_at", ascending: false)
            .execute()
            .value
        
        return artworkData
    }
    
    /// Fetches summary information for all crates including artwork counts
    func fetchCratesSummary() async throws -> [CrateSummary] {
        guard userID != nil else { throw SonexDBError.notAuthenticated }
        guard isOnline else { throw SonexDBError.noNetworkConnection }
        
        let sonexUserId = try await getCurrentSonexUserId()
        
        // Fetch crates with vinyl count and sample artwork
        let summaries: [CrateSummary] = try await supabase
            .from("crates")
            .select("""
                id,
                name,
                sort_order,
                for_sale,
                created_at,
                vinyl_count:vinyl_crates(count),
                sample_artwork:vinyl_crates(vinyl_entries(cover_art_url))
            """)
            .eq("owner_id", value: sonexUserId)
            .order("sort_order", ascending: true)
            .execute()
            .value
        
        return summaries
    }
    
    /// Fetches the vinyl count for a specific crate
    func fetchVinylCountForCrate(crateId: String) async throws -> Int {
        guard userID != nil else { throw SonexDBError.notAuthenticated }
        guard isOnline else { throw SonexDBError.noNetworkConnection }
        
        let countResult: [CountResult] = try await supabase
            .from("vinyl_crates")
            .select("count", head: false, count: .exact)
            .eq("crate_id", value: crateId)
            .execute()
            .value
        
        return countResult.first?.count ?? 0
    }

    /// Fetches crates with record counts - optimized for collection view
    func fetchCratesWithCounts(forceRefresh: Bool = false) async throws -> [CrateWithCount] {
        print("📊 [fetchCratesWithCounts] Starting fetch with forceRefresh: \(forceRefresh)")
        
        guard userID != nil else { 
            print("❌ [fetchCratesWithCounts] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        // Return cached data if available and valid, unless force refresh is requested
        if !forceRefresh, isCratesCacheValid(), let cachedCratesWithCounts = _cachedCratesWithCounts {
            print("✅ [fetchCratesWithCounts] Returning cached crates with counts")
            return cachedCratesWithCounts
        }
        
        // If offline, return cached data if available
        if !isOnline {
            print("📱 [fetchCratesWithCounts] Offline mode")
            
            if let cachedCratesWithCounts = _cachedCratesWithCounts {
                print("✅ [fetchCratesWithCounts] Returning \(cachedCratesWithCounts.count) cached crates with counts")
                return cachedCratesWithCounts
            } else if let cachedCrates = _cachedCrates {
                // For offline mode, we can't accurately get record counts from vinyl_crates
                // So we'll return 0 counts and let the UI handle this gracefully
                let cratesWithCounts = cachedCrates.map { crate in
                    CrateWithCount(
                        id: crate.id,
                        ownerId: crate.owner_id ?? "",
                        name: crate.name,
                        sortOrder: crate.sortOrder,
                        createdAt: crate.createdAt,
                        forSale: crate.for_sale,
                        recordCount: 0 // Can't determine count while offline
                    )
                }
                print("✅ [fetchCratesWithCounts] Returning \(cratesWithCounts.count) cached crates with zero counts")
                return cratesWithCounts
            } else {
                print("❌ [fetchCratesWithCounts] No cached crates available offline")
                throw SonexDBError.noNetworkConnection
            }
        }
        
        print("🌐 [fetchCratesWithCounts] Online mode - fetching from database")
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            print("👤 [fetchCratesWithCounts] Sonex user ID: \(sonexUserId)")
            
            // Fetch basic crates first
            print("📦 [fetchCratesWithCounts] Fetching basic crate data...")
            let crates: [Crate] = try await supabase
                .from("crates")
                .select("*")
                .eq("owner_id", value: sonexUserId)
                .order("sort_order", ascending: true)
                .execute()
                .value
            
            print("✅ [fetchCratesWithCounts] Fetched \(crates.count) crates")
            
            // Then fetch vinyl counts for each crate separately
            var cratesWithCounts: [CrateWithCount] = []
            
            for (index, crate) in crates.enumerated() {
                print("🔢 [fetchCratesWithCounts] Fetching count for crate \(index + 1)/\(crates.count): '\(crate.name)' (ID: \(crate.id))")
                
                do {
                    let countResult: [CountResult] = try await supabase
                        .from("vinyl_crates")
                        .select("count", head: false, count: .exact)
                        .eq("crate_id", value: crate.id)
                        .execute()
                        .value
                    
                    let recordCount = countResult.first?.count ?? 0
                    print("📊 [fetchCratesWithCounts] Crate '\(crate.name)' has \(recordCount) records")
                    
                    let crateWithCount = CrateWithCount(
                        id: crate.id,
                        ownerId: crate.owner_id ?? "",
                        name: crate.name,
                        sortOrder: crate.sortOrder,
                        createdAt: crate.createdAt,
                        forSale: crate.for_sale,
                        recordCount: recordCount
                    )
                    
                    cratesWithCounts.append(crateWithCount)
                    
                } catch {
                    print("❌ [fetchCratesWithCounts] Failed to fetch count for crate '\(crate.name)': \(error)")
                    // Add crate with 0 count on error
                    let crateWithCount = CrateWithCount(
                        id: crate.id,
                        ownerId: crate.owner_id ?? "",
                        name: crate.name,
                        sortOrder: crate.sortOrder,
                        createdAt: crate.createdAt,
                        forSale: crate.for_sale,
                        recordCount: 0
                    )
                    cratesWithCounts.append(crateWithCount)
                }
            }
            
            print("🔄 [fetchCratesWithCounts] Updating cache with crates and counts")
            // Update cache with both basic crates and crates with counts
            await updateCratesWithCountsCache(cratesWithCounts)
            
            print("✅ [fetchCratesWithCounts] Successfully fetched crates with counts")
            return cratesWithCounts
            
        } catch {
            print("❌ [fetchCratesWithCounts] Failed to fetch crates with counts: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [fetchCratesWithCounts] Localized error description: \(localizedError.errorDescription ?? "No description")")
            }
            throw error
        }
    }
    
    /// Fetches the total number of vinyl records for the current user
    func fetchTotalUserRecords(forceRefresh: Bool = false) async throws -> Int {
        print("🔢 [fetchTotalUserRecords] Starting fetch with forceRefresh: \(forceRefresh)")
        
        guard userID != nil else { 
            print("❌ [fetchTotalUserRecords] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        // Return cached data if available and valid, unless force refresh is requested
        if !forceRefresh, isTotalRecordsCacheValid(), let cachedCount = _cachedTotalRecords {
            print("✅ [fetchTotalUserRecords] Returning cached total records count: \(cachedCount)")
            return cachedCount
        }
        
        // If offline, return cached data if available
        if !isOnline {
            print("📱 [fetchTotalUserRecords] Offline mode")
            if let cachedCount = _cachedTotalRecords {
                print("✅ [fetchTotalUserRecords] Returning cached total records count: \(cachedCount)")
                return cachedCount
            } else {
                print("❌ [fetchTotalUserRecords] No cached data available offline")
                throw SonexDBError.noNetworkConnection
            }
        }
        
        print("🌐 [fetchTotalUserRecords] Online mode - fetching from database")
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            
            // Get count directly from vinyl_entries table for accuracy
            let result: [CountResult] = try await supabase
                .from("vinyl_entries")
                .select("count", head: false, count: .exact)
                .eq("owner_id", value: sonexUserId)
                .execute()
                .value
            
            let totalCount = result.first?.count ?? 0
            print("📊 [fetchTotalUserRecords] Total records: \(totalCount)")
            
            // Update cache
            await updateTotalRecordsCache(totalCount)
            
            return totalCount
            
        } catch {
            print("❌ [fetchTotalUserRecords] Failed to fetch total records: \(error)")
            throw error
        }
    }
    
    /// Fetches the crates that a specific vinyl entry belongs to (excluding "For Sale" crate)
    func fetchCratesForVinyl(vinylId: String) async throws -> [Crate] {
        print("📦 [fetchCratesForVinyl] Fetching crates for vinyl ID: \(vinylId)")
        
        guard userID != nil else { 
            print("❌ [fetchCratesForVinyl] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated 
        }
        
        // If offline, we can't fetch from server
        guard isOnline else { 
            print("📱 [fetchCratesForVinyl] Offline - cannot fetch from server")
            throw SonexDBError.noNetworkConnection 
        }
        
        print("🌐 [fetchCratesForVinyl] Online - fetching from database")
        
        do {
            let sonexUserId = try await getCurrentSonexUserId()
            print("👤 [fetchCratesForVinyl] Sonex user ID: \(sonexUserId)")
            
            // Fetch crates that contain this vinyl entry via the junction table
            let crates: [Crate] = try await supabase
                .from("crates")
                .select("""
                    *,
                    vinyl_crates!inner(vinyl_id)
                """)
                .eq("vinyl_crates.vinyl_id", value: vinylId)
                .eq("owner_id", value: sonexUserId)
                .neq("name", value: "For Sale") // Exclude "For Sale" crate
                .order("sort_order", ascending: true)
                .execute()
                .value
            
            print("✅ [fetchCratesForVinyl] Successfully fetched \(crates.count) crates for vinyl")
            
            // Log crate names for debugging
            let crateNames = crates.map { $0.name }
            print("📦 [fetchCratesForVinyl] Crates found: \(crateNames)")
            
            return crates
            
        } catch {
            print("❌ [fetchCratesForVinyl] Failed to fetch crates for vinyl: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [fetchCratesForVinyl] Localized error description: \(localizedError.errorDescription ?? "No description")")
            }
            throw error
        }
    }
    
    // MARK: - Image Caching
    
    /// Retrieves a cached cover art image for a vinyl entry
    func getCachedCoverArt(for coverArtUrl: String?) async -> UIImage? {
        guard let coverArtUrl = coverArtUrl, !coverArtUrl.isEmpty else { return nil }
        
        do {
            return try await imageCacheManager.getImage(for: coverArtUrl)
        } catch {
            print("⚠️ [getCachedCoverArt] Failed to get cached image for URL: \(coverArtUrl) - \(error)")
            return nil
        }
    }
    
    /// Preloads cover art images for a list of vinyl entries
    func preloadCoverArt(for vinylEntries: [VinylEntry]) {
        Task {
            for vinyl in vinylEntries {
                if let coverArtUrl = vinyl.coverArtUrl, !coverArtUrl.isEmpty {
                    imageCacheManager.preloadImage(for: coverArtUrl)
                }
            }
        }
    }
    
    /// Preloads cover art for a specific crate
    func preloadCoverArtForCrate(_ crateId: String) async {
        do {
            let vinylEntries = try await fetchVinylEntries(inCrate: crateId)
            preloadCoverArt(for: vinylEntries)
        } catch {
            print("⚠️ [preloadCoverArtForCrate] Failed to preload cover art for crate \(crateId): \(error)")
        }
    }
    
    /// Clears all cached images
    func clearImageCache() async {
        await imageCacheManager.clearCache()
    }
    
    /// Gets the current image cache size
    func getImageCacheSize() async -> Int {
        return await imageCacheManager.getCacheSize()
    }
    
    /// Formats cache size for display
    func getFormattedImageCacheSize() async -> String {
        let sizeInBytes = await getImageCacheSize()
        return ByteCountFormatter.string(fromByteCount: Int64(sizeInBytes), countStyle: .file)
    }
    
    // MARK: - Image Storage
    
    /// Uploads an image to Supabase Storage and returns the public URL
    func uploadAlbumCoverImage(_ image: UIImage, for albumTitle: String, by artist: String) async throws -> String {
        print("📸 [uploadAlbumCoverImage] Starting upload for '\(albumTitle)' by '\(artist)'")
        
        guard let sonexUserId = userID?.lowercased() else {
            print("❌ [uploadAlbumCoverImage] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated
        }
        
        guard isOnline else {
            print("📱 [uploadAlbumCoverImage] Offline - cannot upload image")
            throw SonexDBError.noNetworkConnection
        }
        
        do {
            
            // Compress and convert image to JPEG data
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw SonexDBError.imageProcessingError("Failed to convert image to JPEG")
            }
            
            print("📊 [uploadAlbumCoverImage] Image data size: \(imageData.count) bytes")
            
            // Create a unique filename
            let timestamp = Int(Date().timeIntervalSince1970)
            let sanitizedTitle = albumTitle.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
            let sanitizedArtist = artist.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
            let filename = "\(sonexUserId)/covers/\(sanitizedArtist)_\(sanitizedTitle)_\(timestamp).jpg"
            
            print("📁 [uploadAlbumCoverImage] Filename: \(filename)")
            
            // Upload to Supabase Storage
            print("☁️ [uploadAlbumCoverImage] Uploading to Supabase storage...")
            
            let uploadResult = try await supabase.storage
                .from("album-covers")
                .upload(
                    _: filename,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )
            
            print("✅ [uploadAlbumCoverImage] Upload successful: \(uploadResult)")
            
            // Get the public URL
            let publicURL = try supabase.storage
                .from("album-covers")
                .getPublicURL(path: filename)
            
            let urlString = publicURL.absoluteString
            print("🔗 [uploadAlbumCoverImage] Public URL: \(urlString)")
            
            return urlString
            
        } catch {
            print("❌ [uploadAlbumCoverImage] Failed to upload image: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [uploadAlbumCoverImage] Localized error description: \(localizedError.errorDescription ?? "No description")")
            }
            throw error
        }
    }
    
    /// Updates the cover art URL for a vinyl entry
    func updateVinylCoverArt(entryId: String, coverArtUrl: String) async throws {
        print("🖼️ [updateVinylCoverArt] Updating cover art for vinyl ID: \(entryId)")
        print("🔗 [updateVinylCoverArt] New URL: \(coverArtUrl)")
        
        guard userID != nil else {
            print("❌ [updateVinylCoverArt] Not authenticated - userID is nil")
            throw SonexDBError.notAuthenticated
        }
        
        if !isOnline {
            print("📱 [updateVinylCoverArt] Offline mode - queuing operation for later sync")
            
            // Queue for later if offline
            struct UpdateCoverArtPayload: Codable {
                let entryId: String
                let coverArtUrl: String
            }
            
            if let data = try? JSONEncoder().encode(UpdateCoverArtPayload(entryId: entryId, coverArtUrl: coverArtUrl)) {
                let operation = PendingOperation(
                    type: .updateCoverArt,
                    timestamp: Date(),
                    data: data
                )
                cacheManager.addPendingOperation(operation)
                print("⏳ [updateVinylCoverArt] Queued cover art update for sync when online")
            }
            return
        }
        
        print("🌐 [updateVinylCoverArt] Online mode - updating database")
        
        try await updateVinylCoverArtOnServer(entryId: entryId, coverArtUrl: coverArtUrl)
    }
    
    private func updateVinylCoverArtOnServer(entryId: String, coverArtUrl: String) async throws {
        let sonexUserId = try await getCurrentSonexUserId()
        print("👤 [updateVinylCoverArtOnServer] Sonex user ID: \(sonexUserId)")
        
        struct CoverArtPatch: Encodable {
            let cover_art_url: String
        }
        
        try await supabase
            .from("vinyl_entries")
            .update(CoverArtPatch(cover_art_url: coverArtUrl))
            .eq("id", value: entryId)
            .eq("owner_id", value: sonexUserId)
            .execute()
        
        print("✅ [updateVinylCoverArtOnServer] Successfully updated cover art URL in database")
    }
    
    /// Updates cover art for registration data (for use during vinyl registration flow)
    func uploadAndSetCoverArt(for registrationData: VinylRegistrationData, image: UIImage) async throws -> String {
        print("📸 [uploadAndSetCoverArt] Starting upload for registration data")
        
        let coverArtUrl = try await uploadAlbumCoverImage(
            image,
            for: registrationData.title,
            by: registrationData.artist
        )
        
        print("✅ [uploadAndSetCoverArt] Upload successful, updating registration data")
        registrationData.coverArtUrl = coverArtUrl
        
        return coverArtUrl
    }
    
    /// Deletes cover art from Supabase storage using the full URL
    func deleteCoverArtFromStorage(url: String) async throws {
        print("🗑️ [deleteCoverArtFromStorage] Starting deletion for URL: \(url)")
        
        guard isOnline else {
            print("📱 [deleteCoverArtFromStorage] Offline - cannot delete from storage")
            throw SonexDBError.noNetworkConnection
        }
        
        // Extract the file path from the Supabase storage URL
        // URL format: https://[project].supabase.co/storage/v1/object/public/album-covers/[path]
        guard let filePathComponent = extractStoragePathFromUrl(url) else {
            print("❌ [deleteCoverArtFromStorage] Invalid storage URL format: \(url)")
            throw SonexDBError.imageProcessingError("Invalid storage URL format")
        }
        
        print("📁 [deleteCoverArtFromStorage] Extracted file path: \(filePathComponent)")
        
        do {
            // Delete from Supabase Storage
            print("☁️ [deleteCoverArtFromStorage] Deleting from Supabase storage...")
            
            let deleteResult = try await supabase.storage
                .from("album-covers")
                .remove(paths: [filePathComponent])
            
            print("✅ [deleteCoverArtFromStorage] Delete successful: \(deleteResult)")
            
        } catch {
            print("❌ [deleteCoverArtFromStorage] Failed to delete from storage: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [deleteCoverArtFromStorage] Localized error description: \(localizedError.errorDescription ?? "No description")")
            }
            throw error
        }
    }
    
    /// Helper method to extract the storage file path from a Supabase storage URL
    private func extractStoragePathFromUrl(_ urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let pathComponents = url.pathComponents.firstIndex(of: "album-covers") else {
            return nil
        }
        
        // Get everything after "album-covers" in the path
        let relevantComponents = Array(url.pathComponents[(pathComponents + 1)...])
        let filePath = relevantComponents.joined(separator: "/")
        
        return filePath.isEmpty ? nil : filePath
    }
}

// MARK: - Supporting Data Models

struct CreateDiscoverPostRPCParams: Codable, Sendable {
    let p_author_id: String
    let p_type: String
    let p_latitude: Double
    let p_longitude: Double
    let p_title: String?
    let p_description: String?
    let p_address: String?
    let p_metadata: [String: SonexShared.AnyCodable]?
    let p_expires_at: String?
}

struct VinylCrateRelation: Codable {
    let id: String
    let vinylId: String
    let crateId: String
    let addedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case vinylId = "vinyl_id"
        case crateId = "crate_id"
        case addedAt = "added_at"
    }
}

struct CrateArtworkItem: Codable, Identifiable {
    let id: String
    let coverArtUrl: String?
    let title: String
    let artist: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case coverArtUrl = "cover_art_url"
        case title
        case artist
    }
}

struct CrateSummary: Codable, Identifiable {
    let id: String
    let name: String
    let sortOrder: Int
    let forSale: Bool
    let createdAt: String
    let vinylCount: Int
    let sampleArtwork: [String?] // Array of cover art URLs
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case sortOrder = "sort_order"
        case forSale = "for_sale"
        case createdAt = "created_at"
        case vinylCount = "vinyl_count"
        case sampleArtwork = "sample_artwork"
    }
}

struct CrateWithCount: Codable, Identifiable {
    let id: String
    let ownerId: String
    let name: String
    let sortOrder: Int
    let createdAt: String?
    let forSale: Bool
    let recordCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case forSale = "for_sale"
        case recordCount = "record_count"
    }
    
    /// Convert to a regular Crate model
    var asCrate: Crate {
        var crate = Crate(
            owner_id: ownerId,
            name: name,
            sortOrder: sortOrder,
            createdAt: createdAt ?? "",
            for_sale: forSale
        )
        crate.id = id
        return crate
    }
}

// MARK: - Friendship Response Models

/// Helper struct for decoding friendship responses with addressee user data
private struct FriendshipWithUser: Codable {
    let id: UUID
    let status: FriendshipStatus
    let createdAt: String
    let addresseeUser: SonexUser?
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case createdAt = "created_at"
        case addresseeUser = "addressee_user"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle UUID that might come as a string from the database
        let idString = try container.decode(String.self, forKey: .id)
        guard let uuid = UUID(uuidString: idString) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Invalid UUID string")
        }
        self.id = uuid
        
        self.status = try container.decode(FriendshipStatus.self, forKey: .status)
        self.createdAt = try container.decode(String.self, forKey: .createdAt)
        self.addresseeUser = try container.decodeIfPresent(SonexUser.self, forKey: .addresseeUser)
    }
}

/// Helper struct for decoding friendship responses with requester user data
private struct FriendshipWithRequester: Codable {
    let id: UUID
    let status: FriendshipStatus
    let createdAt: String
    let requesterUser: SonexUser?
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case createdAt = "created_at"
        case requesterUser = "requester_user"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle UUID that might come as a string from the database
        let idString = try container.decode(String.self, forKey: .id)
        guard let uuid = UUID(uuidString: idString) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Invalid UUID string")
        }
        self.id = uuid
        
        self.status = try container.decode(FriendshipStatus.self, forKey: .status)
        self.createdAt = try container.decode(String.self, forKey: .createdAt)
        self.requesterUser = try container.decodeIfPresent(SonexUser.self, forKey: .requesterUser)
    }
}

/// Helper struct for decoding exchange responses with seller and buyer user data
private struct ExchangeWithUsers: Codable {
    let id: String
    let sellerId: String
    let buyerId: String
    let recordIds: [String]?
    let totalPrice: Double?
    let status: ExchangeStatus
    let completedAt: String?
    let seller: SonexUser?
    let buyer: SonexUser?
    
    enum CodingKeys: String, CodingKey {
        case id
        case sellerId = "seller_id"
        case buyerId = "buyer_id"
        case recordIds = "record_ids"
        case totalPrice = "total_price"
        case status
        case completedAt = "completed_at"
        case seller
        case buyer
    }
}

struct CountResult: Codable {
    let count: Int
}

// MARK: - Discover Post Response Models

/// Helper struct for decoding RSVP responses with discover post data
private struct RSVPWithDiscoverPost: Codable {
    let id: String
    let status: RSVPStatus
    let createdAt: String
    let discoverPost: DiscoverPost?
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case createdAt = "created_at"
        case discoverPost = "discover_post"
    }
}

/// Model combining a discover post with RSVP information
public struct DiscoverPostWithRSVP: Codable, Identifiable {
    public let post: DiscoverPost
    public let rsvpStatus: RSVPStatus
    public let rsvpCreatedAt: String
    
    public var id: String { post.id }
    
    public init(post: DiscoverPost, rsvpStatus: RSVPStatus, rsvpCreatedAt: String) {
        self.post = post
        self.rsvpStatus = rsvpStatus
        self.rsvpCreatedAt = rsvpCreatedAt
    }
}
// MARK: - Error Types

enum SonexDBError: LocalizedError {
    case notAuthenticated
    case unsortedCrateMissing
    case noNetworkConnection
    case externalServiceError(String)
    case imageProcessingError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:     return "No active session. Please sign in."
        case .unsortedCrateMissing: return "Default crate could not be found or created."
        case .noNetworkConnection:  return "No network connection. Please check your internet and try again."
        case .externalServiceError(let message): return "External service error: \(message)"
        case .imageProcessingError(let message): return "Image processing error: \(message)"
        }
    }
}

// MARK: - RSVP Models

/// RSVP status for events
public enum RSVPStatus: String, Codable, CaseIterable {
    case interested = "interested"
    case going = "going"
    case notGoing = "not_going"
    
    public var displayName: String {
        switch self {
        case .interested: return "Interested"
        case .going: return "Going"
        case .notGoing: return "Not Going"
        }
    }
    
    public var icon: String {
        switch self {
        case .interested: return "star"
        case .going: return "checkmark.circle"
        case .notGoing: return "xmark.circle"
        }
    }
    
    public var color: Color {
        switch self {
        case .interested: return .orange
        case .going: return .green
        case .notGoing: return .red
        }
    }
}

/// Event RSVP model
struct EventRSVP: Codable, Identifiable {
    let id: String
    let eventId: String
    let userId: String
    let status: RSVPStatus
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case status
        case createdAt = "created_at"
    }
}

// MARK: - SwiftUI Extensions

extension Image {
    /// Creates an AsyncImage view that uses the SonexDBManager's image cache
    @ViewBuilder
    static func cachedAsyncImage(
        url: String?,
        placeholder: @escaping () -> some View = { ProgressView().progressViewStyle(CircularProgressViewStyle()) }
    ) -> some View {
        CachedAsyncImageView(url: url, placeholder: placeholder)
    }
}

/// Custom AsyncImage view that integrates with SonexDBManager's image cache
struct CachedAsyncImageView<Placeholder: View>: View {
    let url: String?
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
            } else if isLoading {
                placeholder()
            } else {
                // Fallback placeholder for failed loads
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url = url, !url.isEmpty else {
            isLoading = false
            return
        }
        
        isLoading = true
        
        do {
            let cachedImage = try await SonexDBManager.shared.getCachedCoverArt(for: url)
            await MainActor.run {
                self.image = cachedImage
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.image = nil
                self.isLoading = false
            }
        }
    }
}
