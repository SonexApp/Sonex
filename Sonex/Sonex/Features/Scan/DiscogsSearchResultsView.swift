//
//  DiscogsSearchResultsView.swift
//  Sonex
//
//  Created by Assistant on 4/14/26.
//

import SwiftUI
import SonexShared

// Wrapper to hold search result and detailed information
struct EnhancedDiscogsRelease: Identifiable {
    let id: Int
    let searchResult: DiscogsSearchResult
    let detailedRelease: DiscogsRelease?
    let isLoadingDetails: Bool
    
    init(searchResult: DiscogsSearchResult) {
        self.id = searchResult.id
        self.searchResult = searchResult
        self.detailedRelease = nil
        self.isLoadingDetails = false
    }
    
    init(searchResult: DiscogsSearchResult, detailedRelease: DiscogsRelease?) {
        self.id = searchResult.id
        self.searchResult = searchResult
        self.detailedRelease = detailedRelease
        self.isLoadingDetails = false
    }
    
    init(searchResult: DiscogsSearchResult, isLoadingDetails: Bool) {
        self.id = searchResult.id
        self.searchResult = searchResult
        self.detailedRelease = nil
        self.isLoadingDetails = isLoadingDetails
    }
}

struct DiscogsSearchResultsView: View {
    @Bindable var registrationData: VinylRegistrationData
    @State private var discogsManager = DiscogsManager.shared
    @State private var enhancedReleases: [EnhancedDiscogsRelease] = []
    @State private var selectedRelease: EnhancedDiscogsRelease?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var hasMorePages = false
    
    // Batch fetching state
    @State private var batchFetchTask: Task<Void, Never>?
    @State private var fetchedReleaseDetails: [Int: DiscogsRelease] = [:]
    @State private var currentlyFetchingBatch = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    registrationData.currentStep = .albumInfo
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                Text("Release Search")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Invisible spacer for balance
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Searching Discogs...")
                        .tint(.white)
                        .foregroundStyle(.white)
                    Spacer()
                }
            } else if let errorMessage = errorMessage {
                VStack {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundStyle(.orange)
                        
                        Text(errorMessage)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            searchDiscogs()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.9))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Album Info Card (similar to AlbumScanResultsView but more compact)
                        albumInfoCard
                        
                        // Releases Section
                        if !enhancedReleases.isEmpty {
                            releasesSection
                        }
                    }
                    .padding(.bottom, 120) // Space for bottom button
                }
            }
            
            // Bottom Button (fixed at bottom)
            if !isLoading && errorMessage == nil {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    VStack(spacing: 12) {
                        // Primary action button
                        Button(action: {
                            if let selectedRelease = selectedRelease {
                                registrationData.discogsId = "\(selectedRelease.searchResult.id)"
                                registrationData.nextStep()
                            }
                        }) {
                            HStack {
                                Text("Select Release")
                                    .fontWeight(.semibold)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .foregroundStyle(.white)
                            .background(selectedRelease != nil ? Color.red.opacity(0.9) : Color.gray.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(selectedRelease == nil)
                        
                        // Secondary "Cannot find" button
                        Button(action: {
                            // Set discogsId to the masterId of the first result if available, otherwise nil
                            if let firstResult = enhancedReleases.first,
                               let masterId = firstResult.searchResult.masterId {
                                registrationData.discogsId = "\(masterId)"
                            } else {
                                registrationData.discogsId = nil
                            }
                            registrationData.nextStep()
                        }) {
                            Text("Cannot find matching release on Discogs")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.black.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                }
                .background(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.red.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.2),
                    Color.red.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            searchDiscogs()
        }
        .onDisappear {
            // Cancel any ongoing batch fetch when leaving the view
            batchFetchTask?.cancel()
        }
    }
    
    @ViewBuilder
    private var albumInfoCard: some View {
        HStack(spacing: 16) {
            // Album Art on the left
            if let coverArtUrl = registrationData.coverArtUrl,
               let url = URL(string: coverArtUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.sonexSurface.opacity(0.6))
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .fill(Color.sonexSurface.opacity(0.6))
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Album Info on the right
            VStack(alignment: .leading, spacing: 6) {
                Text(registrationData.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(registrationData.artist)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let year = registrationData.year {
                    Text("Dec 8, \(year)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Text(registrationData.mediaType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 32)
        .padding(.top, 16)
    }
    
    @ViewBuilder
    private var releasesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("RELEASES (\(enhancedReleases.count)\(hasMorePages ? "+ more available" : ""))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 32)
                
                Spacer()
            }
            
            // Releases List
            VStack(spacing: 8) {
                ForEach(enhancedReleases) { enhancedRelease in
                    releaseRow(enhancedRelease)
                }
                
                // Load More button if there are more pages
                if hasMorePages && !isLoadingMore {
                    HStack(spacing: 12) {
                        Button(action: {
                            loadMoreReleases()
                        }) {
                            Text("Load More")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(Color.black.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Button(action: {
                            loadAllReleases()
                        }) {
                            Text("Load All (\(totalPages * 50) total)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(Color.red.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.top, 8)
                }
                
                // Loading indicator for loading more
                if isLoadingMore {
                    ProgressView("Loading more results...")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 32)
        }
    }
    
    @ViewBuilder
    private func releaseRow(_ enhancedRelease: EnhancedDiscogsRelease) -> some View {
        Button(action: {
            selectedRelease = enhancedRelease
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    // Main release info line - Format and Country
                    VStack(alignment:.leading, spacing: 4) {
                        if let detailedFormat = enhancedRelease.detailedRelease?.formats.first {
                            // Use detailed format information if available
                            VStack(spacing: 4) {
                                Text(detailedFormat.name)
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                
                                if let descriptions = detailedFormat.descriptions, !descriptions.isEmpty {
                                    Text("(\(descriptions.joined(separator: ", ")))")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                            }
                        } else if let format = enhancedRelease.searchResult.format?.first {
                            // Fall back to search result format
                            Text(format)
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                        }
                        
                        if let country = enhancedRelease.searchResult.country {
                            Text("\(country)")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                        }
                    }
                    
                    // Label and catalog number line
                    VStack(spacing: 4) {
                        if let detailedLabels = enhancedRelease.detailedRelease?.labels.first {
                            // Use detailed label information with catalog number
                            Text(detailedLabels.name)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            if let catno = detailedLabels.catno, !catno.isEmpty {
                                Text("\(catno)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.red.opacity(0.9))
                            }
                        } else if let label = enhancedRelease.searchResult.label?.first {
                            // Fall back to search result label
                            Text(label)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            // Show placeholder catalog if we don't have detailed info yet
                            if enhancedRelease.isLoadingDetails {
                                Text("– Loading...")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                    
                    // Release date
                    if let year = enhancedRelease.searchResult.year {
                        Text("Dec 8, \(year)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    // Notes if available
                    if let notes = enhancedRelease.detailedRelease?.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    // Loading indicator for detailed info
                    if enhancedRelease.isLoadingDetails {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white.opacity(0.6))
                    }
                    
                    // Selection indicator (radio button style)
                    ZStack {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.5), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if selectedRelease?.id == enhancedRelease.id {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 16, height: 16)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(
                Color.black.opacity(selectedRelease?.id == enhancedRelease.id ? 0.4 : 0.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // Trigger batch fetch if this release doesn't have details yet
            if enhancedRelease.detailedRelease == nil && !enhancedRelease.isLoadingDetails {
                startBatchFetchIfNeeded()
            }
        }
    }
    
    // MARK: - Batch Release Detail Fetching
    
    private func startBatchFetchIfNeeded() {
        // Only start if we're not already fetching and there are releases to fetch
        guard !currentlyFetchingBatch else { return }
        
        let releasesToFetch = enhancedReleases.filter { release in
            release.detailedRelease == nil && 
            !release.isLoadingDetails &&
            fetchedReleaseDetails[release.id] == nil
        }
        
        guard !releasesToFetch.isEmpty else { return }
        
        // Cancel any existing batch fetch task
        batchFetchTask?.cancel()
        
        // Start new batch fetch
        batchFetchTask = Task {
            await performBatchFetch(for: releasesToFetch)
        }
    }
    
    private func performBatchFetch(for releases: [EnhancedDiscogsRelease]) async {
        await MainActor.run {
            currentlyFetchingBatch = true
            
            // Mark releases as loading
            for release in releases {
                if let index = enhancedReleases.firstIndex(where: { $0.id == release.id }) {
                    enhancedReleases[index] = EnhancedDiscogsRelease(
                        searchResult: release.searchResult,
                        isLoadingDetails: true
                    )
                }
            }
        }
        
        // Get visible releases first (approximate first 10 as priority)
        let releaseIds = releases.map { $0.id }
        let visibleIds = Array(releaseIds.prefix(10))
        
        print("Starting batch fetch for \(releaseIds.count) releases (prioritizing \(visibleIds.count) visible ones)")
        
        let detailedReleases = await discogsManager.fetchPrioritizedReleaseDetails(
            releaseIds: releaseIds,
            priorityIds: visibleIds
        )
        
        await MainActor.run {
            // Store fetched details
            for (releaseId, detailedRelease) in detailedReleases {
                fetchedReleaseDetails[releaseId] = detailedRelease
            }
            
            // Update enhanced releases with the fetched details
            updateEnhancedReleasesWithFetchedDetails()
            
            currentlyFetchingBatch = false
        }
    }
    
    private func updateEnhancedReleasesWithFetchedDetails() {
        var hasMatches = false
        var updatedReleases: [EnhancedDiscogsRelease] = []
        
        for release in enhancedReleases {
            if let detailedRelease = fetchedReleaseDetails[release.id] {
                let updatedRelease = EnhancedDiscogsRelease(
                    searchResult: release.searchResult,
                    detailedRelease: detailedRelease
                )
                updatedReleases.append(updatedRelease)
                
                // Check for catalog match
                if selectedRelease == nil {
                    let matchFound = checkForCatalogMatchInRelease(updatedRelease)
                    if matchFound {
                        selectedRelease = updatedRelease
                        hasMatches = true
                    }
                }
            } else {
                updatedReleases.append(release)
            }
        }
        
        enhancedReleases = updatedReleases
        
        
        print("Updated \(fetchedReleaseDetails.count) releases with detailed info")
    }
    
    private func checkForCatalogMatchInRelease(_ release: EnhancedDiscogsRelease) -> Bool {
        guard !registrationData.catalogNumber.isEmpty,
              let detailedRelease = release.detailedRelease else {
            return false
        }
        
        for label in detailedRelease.labels {
            if let catno = label.catno,
               catno.localizedCaseInsensitiveCompare(registrationData.catalogNumber) == .orderedSame {
                print("Found catalog match in batch: \(catno)")
                return true
            }
        }
        return false
    }
    
    // Legacy method for backwards compatibility - now calls batch fetch
    private func fetchDetailedReleaseInfo(for enhancedRelease: EnhancedDiscogsRelease) {
        startBatchFetchIfNeeded()
    }
    
    private func searchDiscogs() {
        guard !registrationData.artist.isEmpty && !registrationData.title.isEmpty else {
            errorMessage = "Artist and title are required for Discogs search"
            return
        }
        
        isLoading = true
        errorMessage = nil
        selectedRelease = nil
        enhancedReleases = []
        currentPage = 1
        totalPages = 1
        hasMorePages = false
        
        // Reset batch fetching state
        batchFetchTask?.cancel()
        fetchedReleaseDetails.removeAll()
        currentlyFetchingBatch = false
        
        Task {
            do {
                let response = try await discogsManager.search(
                    artist: registrationData.artist,
                    title: registrationData.title,
                    page: currentPage,
                    perPage: 50, // Increase per page to get more results faster
                    format: registrationData.mediaType.rawValue,
                )
                
                await MainActor.run {
                    // Convert search results to enhanced releases
                    self.enhancedReleases = response.results.map { searchResult in
                        EnhancedDiscogsRelease(searchResult: searchResult)
                    }
                    
                    // Update pagination state
                    self.totalPages = response.pagination.pages
                    self.hasMorePages = response.pagination.page < response.pagination.pages
                    
                    self.isLoading = false
                    
                    if response.results.isEmpty {
                        self.errorMessage = "No releases found on Discogs for '\(registrationData.artist) - \(registrationData.title)'"
                    }
                    
                    print("Searching Discogs for: Artist='\(registrationData.artist)', Title='\(registrationData.title)', Format='\(registrationData.mediaType.rawValue)'")
                    print("Loaded \(response.results.count) releases from page \(response.pagination.page) of \(response.pagination.pages) (total: \(response.pagination.items) items)")
                    
                    // Auto-select release with matching catalog number if available
                    self.preselectMatchingCatalogRelease()
                    
                    // Start batch fetching release details
                    self.startBatchFetchIfNeeded()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    if let discogsError = error as? DiscogsError {
                        switch discogsError {
                        case .notAuthenticated:
                            self.errorMessage = "Please connect your Discogs account in Settings to search releases"
                        default:
                            self.errorMessage = discogsError.localizedDescription
                        }
                    } else {
                        self.errorMessage = "Failed to search Discogs: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func loadMoreReleases() {
        guard !isLoadingMore && hasMorePages else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        Task {
            do {
                let response = try await discogsManager.search(
                    artist: registrationData.artist,
                    title: registrationData.title,
                    page: currentPage,
                    perPage: 50,
                    format: registrationData.mediaType.rawValue,
                )
                
                await MainActor.run {
                    // Append new results to existing releases
                    let newReleases = response.results.map { searchResult in
                        EnhancedDiscogsRelease(searchResult: searchResult)
                    }
                    self.enhancedReleases.append(contentsOf: newReleases)
                    
                    // Update pagination state
                    self.hasMorePages = response.pagination.page < response.pagination.pages
                    self.isLoadingMore = false
                    
                    // Check for catalog matches in newly loaded releases if nothing is selected yet
                    if self.selectedRelease == nil {
                        self.preselectMatchingCatalogRelease()
                    }
                    
                    // Start batch fetching for new releases
                    self.startBatchFetchIfNeeded()
                    
                    print("Loaded \(response.results.count) more releases from page \(response.pagination.page) of \(response.pagination.pages) (total loaded: \(self.enhancedReleases.count))")
                }
            } catch {
                await MainActor.run {
                    self.isLoadingMore = false
                    print("Failed to load more releases: \(error)")
                    // Optionally show error, but don't clear existing results
                }
            }
        }
    }
    
    private func loadAllReleases() {
        guard !isLoadingMore && hasMorePages else { return }
        
        isLoadingMore = true
        
        Task {
            var allNewReleases: [EnhancedDiscogsRelease] = []
            var pageToLoad = currentPage + 1
            
            // Load all remaining pages
            while pageToLoad <= totalPages {
                do {
                    let response = try await discogsManager.search(
                        artist: registrationData.artist,
                        title: registrationData.title,
                        page: pageToLoad,
                        perPage: 50,
                        format: registrationData.mediaType.rawValue,
                    )
                    
                    let newReleases = response.results.map { searchResult in
                        EnhancedDiscogsRelease(searchResult: searchResult)
                    }
                    allNewReleases.append(contentsOf: newReleases)
                    
                    print("Loaded page \(pageToLoad) of \(totalPages) (\(response.results.count) releases)")
                    pageToLoad += 1
                    
                    // Small delay to avoid overwhelming the API
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                } catch {
                    print("Failed to load page \(pageToLoad): \(error)")
                    break
                }
            }
            
            await MainActor.run {
                // Append all new releases
                self.enhancedReleases.append(contentsOf: allNewReleases)
                self.currentPage = self.totalPages
                self.hasMorePages = false
                self.isLoadingMore = false
                
                // Check for catalog matches in newly loaded releases if nothing is selected yet
                if self.selectedRelease == nil {
                    self.preselectMatchingCatalogRelease()
                }
                
                // Start batch fetching for all releases
                self.startBatchFetchIfNeeded()
                
                print("Loaded all releases. Total: \(self.enhancedReleases.count)")
            }
        }
    }
    
    private func preselectMatchingCatalogRelease() {
        guard !registrationData.catalogNumber.isEmpty else { 
            print("No catalog number to match")
            return 
        }
        
        print("Looking for catalog number match: '\(registrationData.catalogNumber)'")
        
        // First, try to find a match in already loaded detailed releases
        for enhancedRelease in enhancedReleases {
            if let detailedRelease = enhancedRelease.detailedRelease {
                for label in detailedRelease.labels {
                    if let catno = label.catno,
                       catno.localizedCaseInsensitiveCompare(registrationData.catalogNumber) == .orderedSame {
                        print("Found catalog match in detailed release: \(catno)")
                        selectedRelease = enhancedRelease
                        return
                    }
                }
            }
        }
        
        print("No immediate catalog match found, will check as detailed info loads")
    }
    
    private func checkForCatalogMatch(_ enhancedRelease: EnhancedDiscogsRelease) {
        guard !registrationData.catalogNumber.isEmpty,
              selectedRelease == nil, // Only auto-select if nothing is selected yet
              let detailedRelease = enhancedRelease.detailedRelease else { 
            return 
        }
        
        for label in detailedRelease.labels {
            if let catno = label.catno,
               catno.localizedCaseInsensitiveCompare(registrationData.catalogNumber) == .orderedSame {
                print("Found catalog match while loading detailed info: \(catno)")
                selectedRelease = enhancedRelease
                return
            }
        }
    }
}


