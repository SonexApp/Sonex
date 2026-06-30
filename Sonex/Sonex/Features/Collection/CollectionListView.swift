//
//  CollectionListView.swift
//  Sonex
//
//  Created by Ricardo Payares on 4/8/26.
//

import SwiftUI
import SonexShared

// MARK: - Search Result Data Structure
struct VinylSearchResult: Identifiable {
    let id = UUID()
    let vinyl: VinylEntry
    let crateName: String
}

struct CollectionListView: View {
    @State private var crates: [CrateWithCount] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showingAddCrate = false
    @State private var totalRecords = 0
    @State private var searchResults: [VinylSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var filteredCrates: [CrateWithCount] {
        let filtered = searchText.isEmpty ? crates : crates.filter { crate in
            crate.name.localizedCaseInsensitiveContains(searchText)
        }
        
        // Sort with priority crates first (Unsorted, For Sale, Wishlist)
        return filtered.sorted { lhs, rhs in
            let priorityOrder = ["Unsorted", "For Sale", "Wishlist"]
            
            let lhsIndex = priorityOrder.firstIndex(of: lhs.name) ?? Int.max
            let rhsIndex = priorityOrder.firstIndex(of: rhs.name) ?? Int.max
            
            if lhsIndex != rhsIndex {
                return lhsIndex < rhsIndex
            }
            
            // For non-priority crates, sort by sortOrder then by name
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            
            return lhs.name < rhs.name
        }
    }
    
    var body: some View {
        ZStack {
            Color.sonexCharcoal.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with stats
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        StatView(
                            label: "RECORDS",
                            value: "\(totalRecords)",
                            color: .white
                        )
                        
                        
                        StatView(
                            label: "CRATES",
                            value: "\(crates.count)",
                            color: .white
                        )
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.6))
                        
                        TextField("Search your collection...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.white)
                            .onChange(of: searchText) { _ in
                                performSearchWithDebounce()
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.sonexSurface)
                    .cornerRadius(20)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                
                // Content based on search state
                if !searchText.isEmpty {
                    // Search results view
                    VStack(spacing: 0) {
                        // Search results header
                        HStack {
                            Text("SEARCH RESULTS")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .fontWeight(.medium)
                            
                            if isSearching {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(Color.sonexAmber)
                                    .padding(.leading, 8)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                        
                        // Search results list
                        if searchResults.isEmpty && !isSearching {
                            VStack(spacing: 12) {
                                Image(systemName: "music.note.list")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.4))
                                Text("No records found")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.6))
                                Text("Try adjusting your search terms")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .frame(maxHeight: .infinity)
                            .padding()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(searchResults) { result in
                                        SearchResultRowView(result: result)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 100) // Space for dock and FAB
                            }
                        }
                    }
                } else {
                    // Crates section header
                    HStack {
                        Text("CRATES")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    
                    // Crates grid
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(Color.sonexAmber)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(filteredCrates) { crate in
                                    NavigationLink(destination: SingleCrateView(crate: crate)) {
                                        CrateView(crate: crate)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 100) // Space for dock and FAB
                        }
                    }
                }
            }
            
            // Floating Add Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showingAddCrate = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.sonexAmber)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 120) // Above the dock
                }
            }
        }
        .navigationTitle("My Collection")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadCrates()
        }
        .refreshable {
            await loadCrates(forceRefresh: true)
        }
        .sheet(isPresented: $showingAddCrate) {
            AddCrateSheet {
                Task {
                    await loadCrates(forceRefresh: true)
                }
            }
        }
    }
    
    @MainActor
    private func loadCrates(forceRefresh: Bool = false) async {
        isLoading = true
        
        do {
            print("📦 Loading crates with forceRefresh: \(forceRefresh)")
            
            // Use the new bulk fetch method that gets crates with their record counts
            async let cratesWithCountsTask = SonexDBManager.shared.fetchCratesWithCounts(forceRefresh: forceRefresh)
            async let totalRecordsTask = SonexDBManager.shared.fetchTotalUserRecords(forceRefresh: forceRefresh)
            
            // Execute both queries concurrently
            let cratesWithCounts = try await cratesWithCountsTask
            let userTotalRecords = try await totalRecordsTask
            
            print("✅ Successfully loaded \(cratesWithCounts.count) crates with \(userTotalRecords) total records")
            
            // Assign the crates with counts directly
            crates = cratesWithCounts
            totalRecords = userTotalRecords
            
        } catch {
            print("❌ Failed to load crates: \(error)")
            
            // Print more detailed error information
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("🔍 Type mismatch - Expected: \(type), Context: \(context)")
                case .valueNotFound(let value, let context):
                    print("🔍 Value not found - Value: \(value), Context: \(context)")
                case .keyNotFound(let key, let context):
                    print("🔍 Key not found - Key: \(key), Context: \(context)")
                case .dataCorrupted(let context):
                    print("🔍 Data corrupted - Context: \(context)")
                @unknown default:
                    print("🔍 Unknown decoding error: \(decodingError)")
                }
            }
            
            // For offline functionality, try to load from cache
            do {
                print("🔄 Attempting to load cached crates...")
                crates = try await SonexDBManager.shared.fetchCratesWithCounts(forceRefresh: false)
                totalRecords = crates.reduce(0) { total, crate in
                    total + crate.recordCount
                }
                print("✅ Successfully loaded \(crates.count) cached crates")
            } catch {
                print("❌ Failed to load cached crates: \(error)")
                // Keep existing data if available
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Search Methods
    
    private func performSearchWithDebounce() {
        // Cancel any existing search task
        searchTask?.cancel()
        
        // Create a new debounced search task
        searchTask = Task {
            // Wait for 300ms to debounce
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            // Check if the task was cancelled
            guard !Task.isCancelled else { return }
            
            await searchVinylEntries()
        }
    }
    
    private func performSearch() {
        Task {
            await searchVinylEntries()
        }
    }
    
    @MainActor
    private func searchVinylEntries() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clear results if query is empty
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        // Don't search if query is too short
        guard query.count >= 2 else {
            return
        }
        
        isSearching = true
        searchResults = []
        
        do {
            print("🔍 Starting search for query: '\(query)'")
            
            // Get all crates excluding "For Sale"
            let allCrates = crates.filter { $0.name != "For Sale" }
            
            var allResults: [VinylSearchResult] = []
            
            // Search through each crate
            for crate in allCrates {
                do {
                    let vinylEntries = try await SonexDBManager.shared.fetchVinylEntries(inCrate: crate.id)
                    
                    // Filter vinyl entries that match the search query
                    let matchingEntries = vinylEntries.filter { vinyl in
                        vinyl.title.localizedCaseInsensitiveContains(query) ||
                        vinyl.artist.localizedCaseInsensitiveContains(query)
                    }
                    
                    // Convert to search results
                    let resultsFromCrate = matchingEntries.map { vinyl in
                        VinylSearchResult(vinyl: vinyl, crateName: crate.name)
                    }
                    
                    allResults.append(contentsOf: resultsFromCrate)
                    
                    print("✅ Found \(matchingEntries.count) matches in crate '\(crate.name)'")
                    
                } catch {
                    print("❌ Failed to search in crate '\(crate.name)': \(error)")
                }
            }
            
            // Sort results by artist, then by title
            allResults.sort { lhs, rhs in
                if lhs.vinyl.artist != rhs.vinyl.artist {
                    return lhs.vinyl.artist < rhs.vinyl.artist
                }
                return lhs.vinyl.title < rhs.vinyl.title
            }
            
            searchResults = allResults
            print("✅ Search completed. Found \(allResults.count) total matches")
            
        } catch {
            print("❌ Search failed: \(error)")
            searchResults = []
        }
        
        isSearching = false
    }
}

// MARK: - Supporting Views

struct SearchResultRowView: View {
    let result: VinylSearchResult
    
    var body: some View {
        NavigationLink(destination: AlbumDetailsView(vinyl: result.vinyl)) {
            HStack(spacing: 12) {
                // Album artwork placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.sonexSurface)
                    .frame(width: 50, height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                    .overlay {
                        if let coverArtUrl = result.vinyl.coverArtUrl, !coverArtUrl.isEmpty {
                            AsyncImage(url: URL(string: coverArtUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "music.note")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "music.note")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                
                // Album info
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.vinyl.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(result.vinyl.artist)
                        .font(.subheadline)
                        .foregroundColor(Color.sonexAmber)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text("in \(result.crateName)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        if let year = result.vinyl.year {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                            
                            Text(String(year))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                // Navigation arrow
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.sonexSurface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatView: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .fontWeight(.medium)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(color)
                .fontWeight(.semibold)
        }
    }
}

struct CrateView: View {
    let crate: CrateWithCount
    
    var body: some View {
        VStack(spacing: 0) {
            // Record spines section
            VStack(spacing: 0) {
                // Colorful record spines
                RecordSpinesView(count: crate.recordCount)
                    .frame(height: 40)
                    .padding(.horizontal, 20)
                
                // Crate body
                ZStack {
                    // Crate image background
                    Image("crate") // Using the crate asset from your project
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 100)
                        .clipped()
                    
                    // Crate label overlay
                    VStack {
                        Text(crate.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(getCrateLabelColor())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(getCrateLabelBackground())
                            .cornerRadius(4)
                        
                        // Record count
                        Text("\(crate.recordCount) records")
                            .font(.caption2)
                            .fontWeight(.regular)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.6))
                            .cornerRadius(3)
                            .padding(.bottom, 8)
                    }
                }
                .frame(height: 80)
            }
            .background(Color.sonexSurface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
    }
    
    private func getCrateLabelColor() -> Color {
        switch crate.name {
        case "For Sale":
            return Color.sonexAmber
        case "Funk":
            return .orange
        default:
            return .white
        }
    }
    
    private func getCrateLabelBackground() -> Color {
        return .black.opacity(0.8)
    }
}

struct RecordSpinesView: View {
    let count: Int
    
    // Predefined colors for record spines
    private let spineColors: [Color] = [
        .red, .blue, .green, .purple, .orange, .pink,
        .yellow, .cyan, .mint, .indigo, .teal, .brown
    ]
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<min(count, 20), id: \.self) { index in
                Rectangle()
                    .fill(spineColors[index % spineColors.count])
                    .frame(width: CGFloat.random(in: 2...5))
            }
            
            if count == 0 {
                // Empty state - show a few muted spines
                ForEach(0..<5, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: CGFloat.random(in: 2...4))
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

struct AddCrateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var crateName = ""
    @State private var isCreating = false
    
    let onCrateCreated: () -> Void
    
    init(onCrateCreated: @escaping () -> Void = {}) {
        self.onCrateCreated = onCrateCreated
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Create a new crate to organize your vinyl collection")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Crate Name")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        TextField("Enter crate name", text: $crateName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.sonexSurface)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: createCrate) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "plus")
                            }
                            
                            Text(isCreating ? "Creating..." : "Create Crate")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.sonexAmber)
                        .cornerRadius(12)
                    }
                    .disabled(crateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("New Crate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func createCrate() {
        Task {
            isCreating = true
            
            do {
                let trimmedName = crateName.trimmingCharacters(in: .whitespacesAndNewlines)
                _ = try await SonexDBManager.shared.createCrate(named: trimmedName)
                await MainActor.run {
                    dismiss()
                    onCrateCreated()
                }
            } catch {
                print("Failed to create crate: \(error)")
                // TODO: Show error alert
            }
            
            isCreating = false
        }
    }
}

#Preview {
    NavigationView {
        CollectionListView()
    }
    .preferredColorScheme(.dark)
}
