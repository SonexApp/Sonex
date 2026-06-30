//
//  DiscoverTabView.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//
//  This file implements the Discover feature with MapKit integration,
//  location services, and discover posts functionality.
//
//  Features:
//  - MapKit integration with user location display
//  - Location permission handling and requests
//  - Discover posts display as interactive map annotations
//  - Floating add button for creating new posts
//  - Post type selection: Crate Drop, Event, DJ Set, Signing, Swap
//  - Location-based post filtering with 10km radius
//  - Address resolution using reverse geocoding
//  - Post expiration handling and display
//  - Interactive post detail sheets
//  - Background fetch from discover_posts table
//

import SwiftUI
import MapKit
import CoreLocation
import SonexShared

// MARK: - Location Model
// Using SonexLocation from SonexShared (which is PostGISPoint)
typealias SonexLocation = SonexShared.SonexLocation

// MARK: - Discover Post Type Extensions
extension DiscoverPostType {
    
    var icon: String {
        switch self {
        case .crateDrop: return "archivebox.fill"
        case .recordSwap: return "arrow.triangle.swap"
        case .collectionSale: return "tag.fill"
        case .scouting: return "magnifyingglass"
        case .djSet: return "music.mic"
        case .recordStore: return "storefront"
        case .dancingBar: return "figure.socialdance"
        case .listeningBar: return "hifispeaker.2"
        case .event: return "calendar"
        }
    }
    
    
    var description: String {
        switch self {
        case .crateDrop: return "Records dropped at a location for discovery"
        case .recordSwap: return "Bring some, swap some - meetup focused event"
        case .collectionSale: return "User downsizing their collection with Spin Tags"
        case .scouting: return "Searching for specific albums from wishlist"
        case .djSet: return "DJ performance or set"
        case .recordStore: return "Record store location"
        case .dancingBar: return "Venue for live music performances"
        case .listeningBar: return "Venue for listening to vinyl records"
        case .event: return "General event or meetup"
        }
    }
    
    /// Returns the types available for user creation
    static var userCreatableTypes: [DiscoverPostType] {
        return [.crateDrop, .recordSwap, .collectionSale, .scouting, .djSet]
    }
    
    /// Returns the types available for free users
    static var freeUserCreatableTypes: [DiscoverPostType] {
        return [.crateDrop]
    }
    
    /// Returns the types available for signature users only
    static var signatureUserOnlyTypes: [DiscoverPostType] {
        return [.recordSwap, .collectionSale, .scouting]
    }
    
    /// Returns whether this type supports RSVP functionality
    var supportsRSVP: Bool {
        switch self {
        case .recordSwap, .collectionSale, .djSet, .event:
            return true
        case .crateDrop, .scouting, .recordStore, .listeningBar, .dancingBar:
            return false
        }
    }
    
    /// Returns whether this type supports custom location (different from user location)
    var supportsCustomLocation: Bool {
        switch self {
        case .recordSwap, .djSet, .event:
            return true
        case .crateDrop, .collectionSale, .scouting, .recordStore, .listeningBar, .dancingBar:
            return false
        }
    }
    
    /// Returns whether this type supports crate linking
    var supportsCrateLinking: Bool {
        switch self {
        case .crateDrop, .recordSwap, .scouting:
            return true
        case .collectionSale, .djSet, .recordStore, .listeningBar, .dancingBar, .event:
            return false
        }
    }
    
    /// Returns whether this type supports record linking
    var supportsRecordLinking: Bool {
        switch self {
        case .scouting:
            return true
        case .crateDrop, .recordSwap, .collectionSale, .djSet, .recordStore, .listeningBar, .dancingBar, .event:
            return false
        }
    }
    
    /// Returns whether this type should have a hidden address until conditions are met
    var hasHiddenAddress: Bool {
        switch self {
        case .crateDrop, .collectionSale, .scouting:
            return true
        case .recordSwap, .djSet, .recordStore, .listeningBar, .dancingBar, .event:
            return false
        }
    }
    
    /// Returns whether this post type should show author information
    var showsAuthor: Bool {
        switch self {
        case .recordStore, .dancingBar, .listeningBar:
            return false
        case .crateDrop, .recordSwap, .collectionSale, .scouting, .djSet, .event:
            return true
        }
    }
    
    /// Returns whether RSVPs need approval for this type
    var requiresRSVPApproval: Bool {
        switch self {
        case .crateDrop, .collectionSale, .scouting:
            return true
        case .recordSwap, .djSet, .recordStore, .listeningBar, .dancingBar, .event:
            return false
        }
    }
}

// MARK: - Discover View Model
@MainActor
@Observable
class DiscoverViewModel: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let dbManager = SonexDBManager.shared
    
    var userLocation: SonexLocation?
    var currentUser: SonexUser?
    var discoverPosts: [DiscoverPost] = [] {
        didSet {
            print("🔄 [DiscoverViewModel] discoverPosts updated: \(discoverPosts.count) posts")
            for (index, post) in discoverPosts.enumerated() {
                let hasCoordinates = post.latitude != nil && post.longitude != nil
                print("📋 [DiscoverViewModel] Post \(index + 1): \(post.title ?? post.type.displayName) - Has coordinates: \(hasCoordinates)")
                if let lat = post.latitude, let lng = post.longitude {
                    print("  📍 Coordinates: \(lat), \(lng)")
                }
            }
        }
    }
    var showingLocationAlert = false
    var isLoadingPosts = false
    
    // Filter options for signature users
    var selectedPostTypes: Set<DiscoverPostType> = Set(DiscoverPostType.allCases)
    var showingTypeFilter = false
    var maxSearchRadius: Double {
        // Free users limited to 10km, signature users unlimited within reason
        currentUser?.isSignature == true ? 50000 : 10000 // 50km vs 10km
    }
    var effectiveSearchRadius: Double = 10000 // Default to 10km
    
    // UI State
    var showingUpgradePrompt = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // Update every 100 meters
        effectiveSearchRadius = maxSearchRadius
    }
    
    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            showingLocationAlert = true
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        @unknown default:
            showingLocationAlert = true
        }
    }
    
    func loadCurrentUser() async {
        do {
            currentUser = try await dbManager.fetchCurrentUser()
            print("👤 [DiscoverViewModel] Loaded current user - Signature: \(currentUser?.isSignature ?? false)")
            
            // Update search radius based on user tier
            effectiveSearchRadius = maxSearchRadius
        } catch {
            print("❌ [DiscoverViewModel] Failed to load current user: \(error)")
        }
    }
    
    func loadDiscoverPosts(near location: SonexLocation? = nil) async {
        isLoadingPosts = true
        defer { isLoadingPosts = false }
        
        do {
            print("🔄 [DiscoverViewModel] Loading discover posts...")
            
            // Use the enhanced method with type filtering for signature users
            let posts: [DiscoverPost]
            if currentUser?.isSignature == true && selectedPostTypes.count < DiscoverPostType.allCases.count {
                posts = try await dbManager.fetchDiscoverPosts(
                    near: location,
                    radius: effectiveSearchRadius,
                    types: Array(selectedPostTypes)
                )
            } else {
                posts = try await dbManager.fetchDiscoverPosts(
                    near: location,
                    radius: effectiveSearchRadius
                )
            }
            
            print("✅ [DiscoverViewModel] Loaded \(posts.count) discover posts")
            
            // Debug: Print details about each post
            for (index, post) in posts.enumerated() {
                print("📍 [DiscoverViewModel] Post \(index + 1): \(post.title ?? "No title") - Location: \(post.latitude ?? 0), \(post.longitude ?? 0)")
            }
            
            discoverPosts = posts
        } catch {
            print("❌ [DiscoverViewModel] Failed to load discover posts: \(error)")
            if let localizedError = error as? LocalizedError {
                print("❌ [DiscoverViewModel] Error description: \(localizedError.errorDescription ?? "Unknown error")")
            }
        }
    }
    
    func refreshDiscoverPosts() async {
        await loadDiscoverPosts(near: userLocation)
    }
    
    func createDiscoverPost(
        type: DiscoverPostType,
        title: String?,
        description: String?,
        expiresAt: Date?,
        location: SonexLocation? = nil,
        metadata: [String: SonexShared.AnyCodable]? = nil,
        recordId: String? = nil
    ) async throws {
        let postLocation = location ?? userLocation
        guard let postLocation = postLocation else {
            throw DiscoverError.locationRequired
        }
        
        // Try to get address for the location
        let address = await reverseGeocode(location: postLocation)
        
        let post = try await dbManager.createDiscoverPost(
            type: type,
            title: title,
            description: description,
            location: postLocation,
            address: address,
            metadata: metadata,
            expiresAt: expiresAt
        )
        
        // If this is an RSVP-enabled event and the user is creating it, 
        // automatically RSVP them as "going"
        if type.supportsRSVP {
            try await dbManager.createRSVP(eventId: post.id, status: .going)
        }
        
        // Automatically refresh posts after creation
        await refreshDiscoverPosts()
    }
    
    func updateTypeFilter(_ types: Set<DiscoverPostType>) {
        selectedPostTypes = types
        Task {
            await loadDiscoverPosts(near: userLocation)
        }
    }
    
    func resetTypeFilter() {
        selectedPostTypes = Set(DiscoverPostType.allCases)
        Task {
            await loadDiscoverPosts(near: userLocation)
        }
    }
    
    private func reverseGeocode(location: SonexLocation) async -> String? {
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        guard let request = MKReverseGeocodingRequest(location: clLocation) else {
            print("Failed to create reverse geocoding request")
            return nil
        }
        
        do {
            let mapItems = try await request.mapItems
            guard let mapItem = mapItems.first else { return nil }
            
            var addressComponents: [String] = []
            
            // Use MKMapItem's placemark for address information
            let placemark = mapItem.placemark
            
            if let name = placemark.name {
                addressComponents.append(name)
            }
            if let thoroughfare = placemark.thoroughfare {
                addressComponents.append(thoroughfare)
            }
            if let locality = placemark.locality {
                addressComponents.append(locality)
            }
            if let administrativeArea = placemark.administrativeArea {
                addressComponents.append(administrativeArea)
            }
            
            return addressComponents.joined(separator: ", ")
        } catch {
            print("Reverse geocoding failed: \(error)")
            return nil
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let newLocation = SonexLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        // Only update if location has changed significantly (avoid unnecessary updates)
        if let currentLocation = userLocation {
            let distance = sqrt(pow(currentLocation.latitude - newLocation.latitude, 2) + 
                              pow(currentLocation.longitude - newLocation.longitude, 2))
            // Update if more than ~100m change (rough approximation)
            if distance > 0.001 {
                print("📍 [DiscoverViewModel] Location updated: \(newLocation.latitude), \(newLocation.longitude)")
                userLocation = newLocation
            }
        } else {
            print("📍 [DiscoverViewModel] Initial location set: \(newLocation.latitude), \(newLocation.longitude)")
            userLocation = newLocation
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            showingLocationAlert = true
        default:
            break
        }
    }
}

// MARK: - Discover Post Marker View
struct DiscoverPostMarker: View {
    let post: DiscoverPost
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            ZStack {
                Circle()
                    .fill(post.type.color.gradient)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.9), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                Image(systemName: post.type.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            DiscoverPostDetailView(post: post)
        }
    }
}

// MARK: - Discover Post Detail View
struct DiscoverPostDetailView: View {
    let post: DiscoverPost
    @Environment(\.dismiss) private var dismiss
    @State private var dbManager = SonexDBManager.shared
    @State private var userRSVP: EventRSVP?
    @State private var rsvpCount = 0
    @State private var isLoadingRSVP = false
    @State private var linkedCrate: CrateWithCount?
    @State private var linkedRecord: VinylEntry?
    @State private var showingCrateView = false
    @State private var showingRecordView = false
    @State private var showingRSVPSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // Description
                    if let description = post.description {
                        descriptionSection(description)
                    }
                    
                    // Location info
                    if let address = post.address {
                        locationSection(address)
                    }
                    
                    // Crate preview (if linked)
                    if post.type.supportsCrateLinking {
                        cratePreviewSection
                    }
                    
                    // Record preview (if linked)
                    if post.type.supportsRecordLinking {
                        recordPreviewSection
                    }
                    
                    // RSVP section (for event types)
                    if post.type.supportsRSVP {
                        rsvpSection
                    }
                    
                    // Expiration info
                    expirationSection
                    
                    Spacer(minLength: 24)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Discover Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await loadPostDetails()
        }
        .sheet(isPresented: $showingRSVPSheet) {
            RSVPView(
                post: post,
                currentRSVP: userRSVP,
                onRSVPUpdate: { newRSVP in
                    userRSVP = newRSVP
                    Task { await loadRSVPCount() }
                }
            )
        }
        .sheet(isPresented: $showingCrateView) {
            if let crate = linkedCrate {
                var crateInstance = Crate(
                    owner_id: crate.ownerId,
                    name: crate.name,
                    sortOrder: crate.sortOrder,
                    createdAt: crate.createdAt ?? ISO8601DateFormatter().string(from: Date()),
                    for_sale: crate.forSale
                )
                PublicCrateView(crate: crateInstance)
            }
        }
        .sheet(isPresented: $showingRecordView) {
            if let record = linkedRecord {
                RecordDetailView(record: record)
            }
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            Circle()
                .fill(post.type.color.gradient)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: post.type.icon)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                )
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(post.title ?? post.type.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(post.type.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if post.type.showsAuthor, let authorName = getAuthorDisplayName() {
                    NavigationLink(destination: UserDetailsView(userId: post.authorId ?? "")) {
                        HStack(spacing: 4) {
                            Text("by \(authorName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func locationSection(_ address: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.headline)
            
            if post.type.hasHiddenAddress {
                if post.type == .collectionSale {
                    // For collection sales, show address after event starts
                    if let expiresAt = post.expiresAt,
                       let eventDate = ISO8601DateFormatter().date(from: expiresAt),
                       eventDate <= Date() {
                        Label(address, systemImage: "location")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Label("Address will be revealed when event starts", systemImage: "location")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // For crate drops and scouting, hide address completely
                    Label("Address hidden for privacy", systemImage: "location")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Label(address, systemImage: "location")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var recordPreviewSection: some View {
        if let recordId = post.recordId {
            VStack(alignment: .leading, spacing: 16) {
                Text("Looking For")
                    .font(.headline)
                
                if let record = linkedRecord {
                    RecordPreviewCard(record: record) {
                        showingRecordView = true
                    }
                } else {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                        Text("Loading record...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 80)
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .task {
                await loadLinkedRecord(recordId: recordId)
            }
        }
    }
    
    @ViewBuilder
    private var cratePreviewSection: some View {
        if let crateId = getCrateIdFromMetadata() {
            VStack(alignment: .leading, spacing: 16) {
                Text("Linked Crate")
                    .font(.headline)
                
                if let crate = linkedCrate {
                    CratePreviewCard(crate: crate) {
                        showingCrateView = true
                    }
                } else {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                        Text("Loading crate...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 80)
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .task {
                await loadLinkedCrate(crateId: crateId)
            }
        }
    }
    
    @ViewBuilder
    private var rsvpSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("RSVP")
                    .font(.headline)
                
                Spacer()
                
                if rsvpCount > 0 {
                    Text("\(rsvpCount) interested")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            Button {
                showingRSVPSheet = true
            } label: {
                HStack(spacing: 8) {
                    if let rsvp = userRSVP {
                        Image(systemName: rsvp.status.icon)
                        Text(rsvp.status.displayName)
                    } else {
                        Image(systemName: "plus.circle")
                        Text("RSVP to Event")
                    }
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(userRSVP?.status.color ?? .blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoadingRSVP)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var expirationSection: some View {
        if let expiresAt = post.expiresAt {
            VStack(alignment: .leading, spacing: 8) {
                Text(post.type == .crateDrop ? "Expires" : "Event Start")
                    .font(.headline)
                
                if let expirationDate = ISO8601DateFormatter().date(from: expiresAt) {
                    if expirationDate > Date() {
                        Label(
                            expirationDate.formatted(.relative(presentation: .named)),
                            systemImage: post.type == .crateDrop ? "clock" : "calendar"
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    } else {
                        Label(
                            post.type == .crateDrop ? "Expired" : "Event Started",
                            systemImage: post.type == .crateDrop ? "clock.badge.xmark" : "calendar.badge.checkmark"
                        )
                        .font(.subheadline)
                        .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadPostDetails() async {
        if post.type.supportsRSVP {
            await loadUserRSVP()
            await loadRSVPCount()
        }
    }
    
    private func loadUserRSVP() async {
        isLoadingRSVP = true
        defer { isLoadingRSVP = false }
        
        do {
            userRSVP = try await dbManager.getCurrentUserRSVP(for: post.id)
        } catch {
            print("Failed to load user RSVP: \(error)")
        }
    }
    
    private func loadRSVPCount() async {
        do {
            let rsvps = try await dbManager.fetchRSVPs(for: post.id)
            await MainActor.run {
                rsvpCount = rsvps.filter { $0.status != .notGoing }.count
            }
        } catch {
            print("Failed to load RSVP count: \(error)")
        }
    }
    
    private func loadLinkedRecord(recordId: String) async {
        do {
            // Try to fetch the specific record by ID
            // Since we don't have a direct fetchVinylEntry(by id:) method,
            // we'll need to search through all crates or use a different approach
            
            // First, try to get all crates and search through them
            let crates = try await dbManager.fetchCratesWithCounts()
            var foundRecord: VinylEntry?
            
            for crate in crates {
                let entries = try await dbManager.fetchVinylEntries(inCrate: crate.id)
                if let record = entries.first(where: { $0.id == recordId }) {
                    foundRecord = record
                    break
                }
            }
            
            await MainActor.run {
                if let record = foundRecord {
                    linkedRecord = record
                } else {
                    // Create a fallback record if not found
                    linkedRecord = VinylEntry(
                        id: recordId,
                        ownerId: post.authorId ?? "",
                        discogsId: nil,
                        nfcTagHash: nil,
                        title: "Unknown Record",
                        artist: "Unknown Artist",
                        label: nil,
                        year: nil,
                        format: nil,
                        mediaGrade: nil,
                        gradeNotes: nil,
                        coverArtUrl: nil,
                        forSale: false,
                        askingPrice: nil,
                        createdAt: post.createdAt ?? ISO8601DateFormatter().string(from: Date()),
                        catalogNumber: nil,
                        matrixCode: nil,
                        barcode: nil,
                        releaseEdition: .standard,
                        editionNotes: nil,
                        sleeveGrade: nil
                    )
                }
            }
        } catch {
            print("Failed to load linked record: \(error)")
            // Create a fallback record if needed
            await MainActor.run {
                linkedRecord = VinylEntry(
                    id: recordId,
                    ownerId: post.authorId ?? "",
                    discogsId: nil,
                    nfcTagHash: nil,
                    title: "Unknown Record",
                    artist: "Unknown Artist",
                    label: nil,
                    year: nil,
                    format: nil,
                    mediaGrade: nil,
                    gradeNotes: nil,
                    coverArtUrl: nil,
                    forSale: false,
                    askingPrice: nil,
                    createdAt: post.createdAt ?? ISO8601DateFormatter().string(from: Date()),
                    catalogNumber: nil,
                    matrixCode: nil,
                    barcode: nil,
                    releaseEdition: .standard,
                    editionNotes: nil,
                    sleeveGrade: nil
                )
            }
        }
    }
    
    private func loadLinkedCrate(crateId: String) async {
        do {
            // Fetch the actual crate with record count from the database
            let crates = try await dbManager.fetchCratesWithCounts()
            if let crate = crates.first(where: { $0.id == crateId }) {
                await MainActor.run {
                    linkedCrate = crate
                }
            } else {
                // Fallback: try to fetch basic crate info and get record count separately
                let vinylEntries = try await dbManager.fetchVinylEntries(inCrate: crateId)
                let recordCount = vinylEntries.count
                
                await MainActor.run {
                    linkedCrate = CrateWithCount(
                        id: crateId,
                        ownerId: post.authorId ?? "",
                        name: extractCrateName() ?? "Linked Crate",
                        sortOrder: 0,
                        createdAt: post.createdAt,
                        forSale: false,
                        recordCount: recordCount
                    )
                }
            }
        } catch {
            print("Failed to load linked crate: \(error)")
            // Fallback to mock data if database fetch fails
            await MainActor.run {
                linkedCrate = CrateWithCount(
                    id: crateId,
                    ownerId: post.authorId ?? "",
                    name: extractCrateName() ?? "Linked Crate",
                    sortOrder: 0,
                    createdAt: post.createdAt,
                    forSale: false,
                    recordCount: 0
                )
            }
        }
    }
    
    private func getCrateIdFromMetadata() -> String? {
        // Extract crate_id from metadata if it exists
        if let metadata = post.metadata,
           let crateIdValue = metadata["crate_id"] {
            // Use a mirror to access the internal value property safely
            let mirror = Mirror(reflecting: crateIdValue)
            if let value = mirror.children.first(where: { $0.label == "value" })?.value {
                return value as? String
            }
        }
        return nil
    }
    
    private func extractCrateName() -> String? {
        // Try to extract crate name from title or metadata
        return post.title
    }
    
    private func getAuthorDisplayName() -> String? {
        // This would typically come from the post's author relationship
        // For now, return a placeholder or extract from metadata
        return "Author" // Placeholder
    }
}

// MARK: - Supporting Views

// MARK: - Record Preview Card
struct RecordPreviewCard: View {
    let record: VinylEntry
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Album artwork
                AsyncImage(url: URL(string: record.coverArtUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    case .failure(_), .empty:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            )
                    @unknown default:
                        Rectangle()
                            .fill(Color(.systemGray5))
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(record.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if let year = record.year {
                        Text("\(year)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Record Detail View
struct RecordDetailView: View {
    let record: VinylEntry
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Album artwork and basic info
                    HStack(alignment: .top, spacing: 20) {
                        AsyncImage(url: URL(string: record.coverArtUrl ?? "")) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fill)
                            case .failure(_), .empty:
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.largeTitle)
                                            .foregroundColor(.secondary)
                                    )
                            @unknown default:
                                Rectangle()
                                    .fill(Color(.systemGray5))
                            }
                        }
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(record.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(record.artist)
                                .font(.title3)
                                .foregroundColor(.secondary)
                            
                            if let label = record.label {
                                Text(label)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let year = record.year {
                                Text("\(year)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Additional details
                    if let format = record.format {
                        detailRow(title: "Format", value: format)
                    }
                    
                    if let catalogNumber = record.catalogNumber {
                        detailRow(title: "Catalog Number", value: catalogNumber)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Record Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.body)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Crate Preview Card
struct CratePreviewCard: View {
    let crate: CrateWithCount
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Crate icon (fallback to SF Symbol if crate.png doesn't exist)
                Group {
                    if let image = UIImage(named: "crate.png") {
                        Image(uiImage: image)
                            .resizable()
                    } else {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.orange)
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(crate.name)
                        .font(.headline)
                    
                    Text("\(crate.recordCount) records")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - RSVP View
struct RSVPView: View {
    let post: DiscoverPost
    let currentRSVP: EventRSVP?
    let onRSVPUpdate: (EventRSVP?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var dbManager = SonexDBManager.shared
    @State private var selectedStatus: RSVPStatus = .interested
    @State private var isSubmitting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: post.type.icon)
                            .font(.system(size: 48))
                            .foregroundColor(post.type.color)
                        
                        Text("RSVP to \(post.type.displayName)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(post.title ?? "Event")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // RSVP Options
                    VStack(spacing: 16) {
                        ForEach([RSVPStatus.going, .interested], id: \.self) { status in
                            RSVPOptionButton(
                                status: status,
                                isSelected: selectedStatus == status,
                                onTap: { selectedStatus = status }
                            )
                        }
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        if currentRSVP != nil {
                            Button("Remove RSVP") {
                                Task {
                                    await removeRSVP()
                                }
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .disabled(isSubmitting)
                        }
                        
                        Button {
                            Task {
                                await submitRSVP()
                            }
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(currentRSVP == nil ? "Submit RSVP" : "Update RSVP")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isSubmitting ? Color.gray : Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isSubmitting)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("RSVP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            selectedStatus = currentRSVP?.status ?? .interested
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func submitRSVP() async {
        isSubmitting = true
        defer { isSubmitting = false }
        
        do {
            try await dbManager.createRSVP(eventId: post.id, status: selectedStatus)
            
            // Create updated RSVP for callback
            let updatedRSVP = EventRSVP(
                id: UUID().uuidString,
                eventId: post.id,
                userId: "", // Would be filled by the server
                status: selectedStatus,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            
            onRSVPUpdate(updatedRSVP)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func removeRSVP() async {
        isSubmitting = true
        defer { isSubmitting = false }
        
        do {
            try await dbManager.removeRSVP(for: post.id)
            onRSVPUpdate(nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - RSVP Option Button
struct RSVPOptionButton: View {
    let status: RSVPStatus
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: status.icon)
                    .foregroundColor(isSelected ? .white : status.color)
                    .font(.system(size: 20, weight: .medium))
                
                Text(status.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .medium))
                }
            }
            .padding()
            .background(
                isSelected 
                ? AnyView(LinearGradient(
                    colors: [status.color, status.color.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                : AnyView(Color.clear.background(.ultraThinMaterial))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Public Crate View
struct PublicCrateView: View {
    let crate: Crate
    @State private var vinylEntries: [VinylEntry] = []
    @State private var isLoading = true
    @State private var dbManager = SonexDBManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.2)
                        Text("Loading crate...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else if vinylEntries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.house")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("This crate is empty")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("No records have been added to this crate yet.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(vinylEntries, id: \.id) { vinyl in
                            PublicVinylCard(vinyl: vinyl)
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(crate.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadVinylEntries()
        }
    }
    
    private func loadVinylEntries() async {
        do {
            let entries = try await dbManager.fetchVinylEntries(inCrate: crate.id)
            await MainActor.run {
                self.vinylEntries = entries
                self.isLoading = false
            }
        } catch {
            print("Failed to load vinyl entries: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Public Vinyl Card
struct PublicVinylCard: View {
    let vinyl: VinylEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover Art
            AsyncImage(url: URL(string: vinyl.coverArtUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                case .failure(_):
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.title)
                                .foregroundColor(.secondary)
                        )
                case .empty:
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        )
                @unknown default:
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.title)
                                .foregroundColor(.secondary)
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Title and Artist
            VStack(alignment: .leading, spacing: 2) {
                Text(vinyl.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(vinyl.artist)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
// MARK: - Create Discover Post View
struct CreateDiscoverPostView: View {
    let viewModel: DiscoverViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedType: DiscoverPostType = .crateDrop
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var eventStart: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var useCustomLocation = false
    @State private var customLocation: SonexLocation?
    @State private var customAddress: String = ""
    @State private var isSearchingLocation = false
    @State private var locationSearchError: String?
    @State private var showingLocationError = false
    @State private var trackRSVPs = true
    @State private var selectedCrate: CrateWithCount?
    @State private var selectedRecord: VinylEntry?
    @State private var showingCrateSelection = false
    @State private var showingRecordSelection = false
    @State private var selectedExpirationOption: CrateDropExpiration = .oneHour
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var dbManager = SonexDBManager.shared
    @State private var userCrates: [CrateWithCount] = []
    @State private var wishlistRecords: [VinylEntry] = []
    @State private var currentUser: SonexUser?
    
    enum CrateDropExpiration: String, CaseIterable {
        case oneHour = "1 hour"
        case threeHours = "3 hours"
        case fiveHours = "5 hours"
        
        var timeInterval: TimeInterval {
            switch self {
            case .oneHour: return 3600
            case .threeHours: return 10800
            case .fiveHours: return 18000
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                typeSection
                
                if selectedType.supportsCustomLocation {
                    locationSection
                }
                
                if selectedType.supportsCrateLinking {
                    crateSection
                }
                
                if selectedType.supportsRecordLinking {
                    recordSection
                }
                
                detailsSection
                
                if selectedType.supportsRSVP {
                    rsvpSection
                }
                
                if selectedType == .crateDrop {
                    crateDropSection
                } else {
                    eventTimingSection
                }
                
                Section {
                    Button(action: {
                        Task {
                            await createPost()
                        }
                    }) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isCreating ? "Creating..." : "Create Post")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isCreating || !isFormValid ? Color.gray : Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isCreating || !isFormValid)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Discover Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingCrateSelection) {
                CrateSelectionSheet(
                    crates: userCrates,
                    selectedCrate: selectedCrate,
                    onSelection: { crate in
                        selectedCrate = crate
                        showingCrateSelection = false
                    }
                )
            }
            .sheet(isPresented: $showingRecordSelection) {
                RecordSelectionSheet(
                    records: wishlistRecords,
                    selectedRecord: selectedRecord,
                    onSelection: { record in
                        selectedRecord = record
                        showingRecordSelection = false
                    }
                )
            }
        }
        .task {
            await loadUserData()
            setupDefaultValues()
        }
        .onChange(of: selectedType) { _, newType in
            setupDefaultValues()
        }
        .onChange(of: customAddress) { oldValue, newValue in
            // Clear the selected location if the user manually edits the address
            if customLocation != nil && newValue != oldValue {
                customLocation = nil
            }
        }
    }
    
    // MARK: - Form Sections
    
    private var availablePostTypes: [DiscoverPostType] {
        if currentUser?.isSignature == true {
            return DiscoverPostType.userCreatableTypes
        } else {
            return DiscoverPostType.freeUserCreatableTypes
        }
    }
    
    private var typeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("Post Type")
                    .font(.headline)
                
                Picker("Type", selection: $selectedType) {
                    ForEach(availablePostTypes, id: \.self) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.menu)
                
                Text(selectedType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Show upgrade prompt for non-signature users
                if currentUser?.isSignature != true && !DiscoverPostType.signatureUserOnlyTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Signature Features")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        
                        ForEach(DiscoverPostType.signatureUserOnlyTypes, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Upgrade to Sonex Signature") {
                            // Handle upgrade
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    }
                    .padding()
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .listRowBackground(Color.clear)
    }
    
    @ViewBuilder
    private var locationSection: some View {
        Section("Location") {
            if selectedType == .recordSwap {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Use Public Locations")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                    
                    Text("For safety, we recommend using public locations like record stores, cafes, or community centers for record swaps.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            
            Toggle("Use custom location", isOn: $useCustomLocation)
            
            if useCustomLocation {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TextField("Address or location name", text: $customAddress)
                            .textInputAutocapitalization(.words)
                            .onSubmit {
                                Task {
                                    await searchForLocation()
                                }
                            }
                        
                        Button {
                            Task {
                                await searchForLocation()
                            }
                        } label: {
                            if isSearchingLocation {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                        .disabled(customAddress.isEmpty || isSearchingLocation)
                    }
                    
                    // Location search results
                    if let location = customLocation {
                        locationPreviewCard(for: location)
                    } else if customAddress.isEmpty {
                        Text("Enter an address to search for a location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("Will use your current location")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .alert("Location Search Failed", isPresented: $showingLocationError) {
            Button("OK") { }
        } message: {
            Text(locationSearchError ?? "Unable to find the specified location. Please try a different address.")
        }
    }
    
    @ViewBuilder
    private var recordSection: some View {
        Section("Looking For") {
            if let record = selectedRecord {
                HStack {
                    AsyncImage(url: URL(string: record.coverArtUrl ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                        case .failure(_), .empty:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .overlay(
                                    Image(systemName: "music.note")
                                        .foregroundColor(.secondary)
                                )
                        @unknown default:
                            Rectangle()
                                .fill(Color(.systemGray5))
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text(record.artist)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button("Change") {
                        showingRecordSelection = true
                    }
                    .font(.caption)
                }
            } else {
                Button("Select Record from Wishlist") {
                    showingRecordSelection = true
                }
            }
            
            Text("Select a record from your wishlist that you're looking for")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var crateSection: some View {
        Section("Linked Crate") {
            if let crate = selectedCrate {
                HStack {
                    VStack(alignment: .leading) {
                        Text(crate.name)
                            .font(.subheadline.weight(.medium))
                        Text("\(crate.recordCount) records")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Change") {
                        showingCrateSelection = true
                    }
                    .font(.caption)
                }
            } else {
                Button("Select Crate") {
                    showingCrateSelection = true
                }
            }
            
            if selectedType == .crateDrop {
                Text("For crate drops, this will be automatically set to your 'For Sale' crate")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if selectedType == .recordSwap {
                Text("Link a crate to generate interest in your swap meet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if selectedType == .scouting {
                Text("Link your 'For Sale' crate for potential swap offers")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var detailsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("Details")
                    .font(.headline)
                
                TextField("Title", text: $title, prompt: Text("Enter post title"))
                    .textFieldStyle(.roundedBorder)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter post description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .listRowBackground(Color.clear)
    }
    
    @ViewBuilder
    private var rsvpSection: some View {
        Section("RSVP") {
            Toggle("Allow RSVPs", isOn: $trackRSVPs)
            
            if trackRSVPs {
                Text("Users will be able to RSVP as 'Going' or 'Interested'")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var crateDropSection: some View {
        Section("Expiration") {
            Picker("Expires in", selection: $selectedExpirationOption) {
                ForEach(CrateDropExpiration.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            
            Text("Crate drop will expire after the selected time")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var eventTimingSection: some View {
        Section("Event Start") {
            DatePicker("Starts at", 
                      selection: $eventStart, 
                      in: Date()...,
                      displayedComponents: [.date, .hourAndMinute])
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        switch selectedType {
        case .crateDrop:
            return selectedCrate != nil
        case .scouting:
            return selectedRecord != nil
        case .recordSwap, .collectionSale, .djSet, .event:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .recordStore, .dancingBar, .listeningBar:
            return false // These types cannot be created by users
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadUserData() async {
        do {
            let crates = try await dbManager.fetchCratesWithCounts()
            let user = try await dbManager.fetchCurrentUser()
            
            // Load wishlist records for scouting posts
            var wishlistEntries: [VinylEntry] = []
            if let wishlistCrate = crates.first(where: { $0.name.lowercased() == "wishlist" }) {
                wishlistEntries = try await dbManager.fetchVinylEntries(inCrate: wishlistCrate.id)
            }
            
            await MainActor.run {
                self.userCrates = crates
                self.currentUser = user
                self.wishlistRecords = wishlistEntries
            }
        } catch {
            print("Failed to load user data: \(error)")
        }
    }
    
    private func setupDefaultValues() {
        switch selectedType {
        case .crateDrop:
            if let forSaleCrate = userCrates.first(where: { $0.name == "For Sale" }) {
                selectedCrate = forSaleCrate
            }
            
            // Prefill title and description for crate drops
            if let user = currentUser, let crate = selectedCrate {
                title = "\(user.displayName ?? user.username)'s \(crate.name)"
                description = "Check out records from my \(crate.name.lowercased()) collection!"
            }
            
        case .scouting:
            if let forSaleCrate = userCrates.first(where: { $0.name == "For Sale" }) {
                selectedCrate = forSaleCrate
            }
            selectedRecord = nil // Clear any previously selected record
            
        case .recordSwap:
            // Clear crate drop specific fields
            if selectedCrate?.name == "For Sale" {
                selectedCrate = nil
            }
            // Clear prefilled title/description for non-crate drops
            if title.contains("'s For Sale") {
                title = ""
                description = ""
            }
            
        case .collectionSale, .djSet, .event:
            // Clear crate drop specific fields
            if selectedCrate?.name == "For Sale" {
                selectedCrate = nil
            }
            // Clear prefilled title/description for non-crate drops
            if title.contains("'s For Sale") {
                title = ""
                description = ""
            }
            
        case .recordStore, .listeningBar, .dancingBar:
            break
        }
    }
    
    private func searchForLocation() async {
        guard !customAddress.isEmpty else { return }
        
        isSearchingLocation = true
        locationSearchError = nil
        
        defer {
            isSearchingLocation = false
        }
        
        do {
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.geocodeAddressString(customAddress)
            
            guard let placemark = placemarks.first,
                  let coordinate = placemark.location?.coordinate else {
                await MainActor.run {
                    locationSearchError = "No results found for '\(customAddress)'. Please try a more specific address."
                    showingLocationError = true
                    customLocation = nil
                }
                return
            }
            
            await MainActor.run {
                customLocation = SonexLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                
                // Update the address field with the formatted result if available
                if let formattedAddress = formatPlacemark(placemark) {
                    customAddress = formattedAddress
                }
                
                print("📍 [CreateDiscoverPostView] Found location: \(coordinate.latitude), \(coordinate.longitude)")
            }
        } catch {
            await MainActor.run {
                locationSearchError = "Failed to search for location: \(error.localizedDescription)"
                showingLocationError = true
                customLocation = nil
                print("❌ [CreateDiscoverPostView] Geocoding failed: \(error)")
            }
        }
    }
    
    private func formatPlacemark(_ placemark: CLPlacemark) -> String? {
        var components: [String] = []
        
        if let name = placemark.name {
            components.append(name)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        if let country = placemark.country {
            components.append(country)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    @ViewBuilder
    private func locationPreviewCard(for location: SonexLocation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Selected Location", systemImage: "location.fill")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.green)
                
                Spacer()
                
                Button("Clear") {
                    customLocation = nil
                    customAddress = ""
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            
            // Map Preview
            Map(bounds: MapCameraBounds(
                minimumDistance: 1000,
                maximumDistance: 10000
            )) {
                Marker("Selected Location", 
                       coordinate: CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                       ))
                .tint(.red)
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .allowsHitTesting(false)
            
            // Coordinates
            Text("Coordinates: \(location.latitude, specifier: "%.4f"), \(location.longitude, specifier: "%.4f")")
                .font(.caption2)
                .foregroundColor(.secondary)
                .monospaced()
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func createPost() async {
        isCreating = true
        defer { isCreating = false }
        
        do {
            let location: SonexLocation
            let address: String?
            
            if useCustomLocation, let customLoc = customLocation {
                location = customLoc
                address = customAddress.isEmpty ? nil : customAddress
            } else {
                guard let userLocation = viewModel.userLocation else {
                    throw DiscoverError.locationRequired
                }
                location = userLocation
                address = nil
            }
            
            let expiresAt: Date?
            if selectedType == .crateDrop {
                expiresAt = Date().addingTimeInterval(selectedExpirationOption.timeInterval)
            } else {
                expiresAt = eventStart
            }
            
            // Prepare metadata with crate ID and/or record ID if selected
            var metadata: [String: SonexShared.AnyCodable]?
            if let crate = selectedCrate {
                metadata = ["crate_id": SonexShared.AnyCodable(crate.id)]
            }
            
            let recordId: String?
            if selectedType.supportsRecordLinking, let record = selectedRecord {
                recordId = record.id
            } else {
                recordId = nil
            }
            
            // Use the enhanced createDiscoverPost method that automatically refreshes
            try await viewModel.createDiscoverPost(
                type: selectedType,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                expiresAt: expiresAt,
                location: location,
                metadata: metadata,
                recordId: recordId
            )
            
            // Create RSVP for the creator if RSVP tracking is enabled
            if selectedType.supportsRSVP && trackRSVPs {
                // This is now handled automatically in the viewModel's createDiscoverPost method
            }
            
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            print("Failed to create post: \(error)")
        }
    }
}

// MARK: - Crate Selection Sheet
struct CrateSelectionSheet: View {
    let crates: [CrateWithCount]
    let selectedCrate: CrateWithCount?
    let onSelection: (CrateWithCount) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(crates, id: \.id) { crate in
                    Button {
                        onSelection(crate)
                    } label: {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(crate.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Text("\(crate.recordCount) records")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedCrate?.id == crate.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Select Crate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Discover View
struct DiscoverTabView: View {
    @State private var viewModel = DiscoverViewModel()
    @State private var showingNewPost = false
    @State private var mapCameraPosition = MapCameraPosition.automatic
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Map View
                mapView
                
                // Search radius indicator for free users
                if viewModel.currentUser?.isSignature == false {
                    VStack {
                        HStack {
                            Spacer()
                            SearchRadiusIndicator(
                                radiusInMeters: viewModel.maxSearchRadius,
                                isSignatureUser: viewModel.currentUser?.isSignature ?? false
                            )
                            .padding(.trailing, 16)
                            .padding(.top, 16)
                        }
                        Spacer()
                    }
                }
                
                // Floating Add Button
                floatingAddButton
            }
            .onAppear {
                print("🚀 [DiscoverTabView] View appeared - requesting location permission")
                Task {
                    await viewModel.loadCurrentUser()
                    viewModel.requestLocationPermission()
                    print("🔄 [DiscoverTabView] Loading initial discover posts...")
                    await viewModel.loadDiscoverPosts()
                }
            }
            .onChange(of: viewModel.userLocation) { _, newLocation in
                print("📍 [DiscoverTabView] User location changed: \(newLocation?.latitude ?? 0), \(newLocation?.longitude ?? 0)")
                if let location = newLocation {
                    mapCameraPosition = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(
                            latitude: location.latitude,
                            longitude: location.longitude
                        ),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                    
                    // Load posts near user location
                    Task {
                        print("🔄 [DiscoverTabView] Loading posts near user location...")
                        await viewModel.loadDiscoverPosts(near: location)
                    }
                }
            }
            .onChange(of: viewModel.discoverPosts) { _, newPosts in
                print("🗺️ [DiscoverTabView] Discover posts changed in view: \(newPosts.count) posts")
            }
            .sheet(isPresented: $showingNewPost) {
                CreateDiscoverPostView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingTypeFilter) {
                PostTypeFilterSheet(
                    selectedTypes: $viewModel.selectedPostTypes,
                    isSignatureUser: viewModel.currentUser?.isSignature ?? false,
                    onApply: viewModel.updateTypeFilter
                )
            }
            .alert("Location Permission Required", isPresented: $viewModel.showingLocationAlert) {
                Button("Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please allow location access to discover vinyl events and posts near you.")
            }
            .alert("Upgrade to Signature", isPresented: $viewModel.showingUpgradePrompt) {
                Button("Learn More") {
                    // Handle upgrade flow
                }
                Button("Not Now", role: .cancel) { }
            } message: {
                Text("Get unlimited discover radius and advanced filtering with Sonex Signature.")
            }
        }
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if viewModel.currentUser?.isSignature == true {
                    Button {
                        viewModel.showingTypeFilter = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            if viewModel.selectedPostTypes.count < DiscoverPostType.allCases.count {
                                Text("\(viewModel.selectedPostTypes.count)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.blue, in: Capsule())
                                    .foregroundColor(.white)
                            }
                        }
                    }
                } else {
                    Button {
                        viewModel.showingUpgradePrompt = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.sonexAmber)
                            Text("Upgrade")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh") {
                    Task {
                        print("🔄 [DiscoverTabView] Manual refresh triggered")
                        await viewModel.refreshDiscoverPosts()
                    }
                }
                .disabled(viewModel.isLoadingPosts)
            }
        }
    }
    
    // MARK: - View Components
    
    private var mapView: some View {
        Map(position: $mapCameraPosition) {
            // User location marker
            if let userLocation = viewModel.userLocation {
                Marker("You", 
                       coordinate: CLLocationCoordinate2D(
                        latitude: userLocation.latitude,
                        longitude: userLocation.longitude
                       ))
                .tint(.sonexAmber)
                
                // Search radius circle for free users
                if viewModel.currentUser?.isSignature == false {
                    MapCircle(
                        center: CLLocationCoordinate2D(
                            latitude: userLocation.latitude,
                            longitude: userLocation.longitude
                        ),
                        radius: viewModel.maxSearchRadius
                    )
                    .foregroundStyle(.blue.opacity(0.1))
                    .stroke(.blue, lineWidth: 2)
                }
            }
            
            // Discover posts markers
            ForEach(viewModel.discoverPosts) { post in
                if let latitude = post.latitude, let longitude = post.longitude {
                    Annotation(
                        post.title ?? post.type.displayName,
                        coordinate: CLLocationCoordinate2D(
                            latitude: latitude,
                            longitude: longitude
                        )
                    ) {
                        DiscoverPostMarker(post: post)
                            .onAppear {
                                print("📍 [Map] Displaying annotation for post: \(post.title ?? "No title") at \(latitude), \(longitude)")
                            }
                    }
                } else {
                    let _ = print("⚠️ [Map] Skipping post with no coordinates: \(post.title ?? "No title")")
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
                .mapControlVisibility(viewModel.currentUser?.isSignature == true ? .visible : .hidden)
            MapCompass()
            MapScaleView()
        }
        .onTapGesture { location in
            // Signature users can relocate on the map
            if viewModel.currentUser?.isSignature == true {
                handleMapTap(at: location)
            }
        }
    }
    
    private func handleMapTap(at screenLocation: CGPoint) {
        // For signature users, allow map relocation
        // This would require converting screen coordinates to map coordinates
        // For now, we'll just show that it's a signature feature
        print("🎯 [DiscoverTabView] Signature user tapped map for relocation")
    }
    
    private var floatingAddButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    showingNewPost = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(.blue.gradient, in: Circle())
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 100) // Account for tab bar
            }
        }
    }
}

// MARK: - Post Type Filter Sheet
struct PostTypeFilterSheet: View {
    @Binding var selectedTypes: Set<DiscoverPostType>
    let isSignatureUser: Bool
    let onApply: (Set<DiscoverPostType>) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var workingSelection: Set<DiscoverPostType>
    
    init(selectedTypes: Binding<Set<DiscoverPostType>>, isSignatureUser: Bool, onApply: @escaping (Set<DiscoverPostType>) -> Void) {
        self._selectedTypes = selectedTypes
        self.isSignatureUser = isSignatureUser
        self.onApply = onApply
        self._workingSelection = State(initialValue: selectedTypes.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            if !isSignatureUser {
                // Upgrade prompt for free users
                VStack(spacing: 24) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.sonexAmber)
                    
                    Text("Premium Feature")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Post type filtering is available for Sonex Signature members. Upgrade to filter discover posts by event type and see more posts in your area.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Upgrade to Signature") {
                        // Handle upgrade flow
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.sonexAmber)
                    
                    Spacer()
                }
                .padding()
            } else {
                // Filter interface for signature users
                Form {
                    Section {
                        ForEach(DiscoverPostType.allCases, id: \.self) { postType in
                            HStack {
                                Button {
                                    if workingSelection.contains(postType) {
                                        workingSelection.remove(postType)
                                    } else {
                                        workingSelection.insert(postType)
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: postType.icon)
                                            .font(.title3)
                                            .foregroundColor(postType.color)
                                            .frame(width: 24)
                                        
                                        Text(postType.displayName)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: workingSelection.contains(postType) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(workingSelection.contains(postType) ? .blue : .gray)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text("Post Types")
                    } footer: {
                        Text("Select the types of discover posts you want to see on the map.")
                    }
                    
                    Section {
                        Button("Select All") {
                            workingSelection = Set(DiscoverPostType.allCases)
                        }
                        
                        Button("Deselect All") {
                            workingSelection.removeAll()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("Filter Posts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            if isSignatureUser {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        selectedTypes = workingSelection
                        onApply(workingSelection)
                        dismiss()
                    }
                    .disabled(workingSelection.isEmpty)
                }
            }
        }
    }
}

// MARK: - Search Radius Indicator
struct SearchRadiusIndicator: View {
    let radiusInMeters: Double
    let isSignatureUser: Bool
    
    private var radiusText: String {
        if radiusInMeters >= 1000 {
            let km = radiusInMeters / 1000
            return String(format: "%.0fkm radius", km)
        } else {
            return String(format: "%.0fm radius", radiusInMeters)
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.circle")
                .foregroundColor(isSignatureUser ? .sonexAmber : .blue)
            
            Text(radiusText)
                .font(.caption)
                .fontWeight(.medium)
            
            if !isSignatureUser {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Record Selection Sheet
struct RecordSelectionSheet: View {
    let records: [VinylEntry]
    let selectedRecord: VinylEntry?
    let onSelection: (VinylEntry) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if records.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.house")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Wishlist Records")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Add records to your wishlist to use them in scouting posts")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(records, id: \.id) { record in
                        Button {
                            onSelection(record)
                        } label: {
                            HStack(spacing: 16) {
                                AsyncImage(url: URL(string: record.coverArtUrl ?? "")) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(1, contentMode: .fill)
                                    case .failure(_), .empty:
                                        Rectangle()
                                            .fill(Color(.systemGray5))
                                            .overlay(
                                                Image(systemName: "music.note")
                                                    .foregroundColor(.secondary)
                                            )
                                    @unknown default:
                                        Rectangle()
                                            .fill(Color(.systemGray5))
                                    }
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.title)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    
                                    Text(record.artist)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    
                                    if let year = record.year {
                                        Text("\(year)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedRecord?.id == record.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Select Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Error Types
enum DiscoverError: LocalizedError {
    case locationRequired
    case networkError
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .locationRequired:
            return "Location access is required to create discover posts"
        case .networkError:
            return "Network error occurred"
        case .unauthorized:
            return "You must be signed in to create posts"
        }
    }
}
