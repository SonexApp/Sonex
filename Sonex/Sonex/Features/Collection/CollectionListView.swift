//
//  CollectionListView.swift
//  Sonex
//
//  Created by Ricardo Payares on 4/8/26.
//

import SwiftUI
import SonexShared

struct CollectionListView: View {
    @State private var crates: [Crate] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showingAddCrate = false
    @State private var totalRecords = 0
    @State private var estimatedValue: Double = 18640.0 // Placeholder from mockup
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var filteredCrates: [Crate] {
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
                            label: "EST.",
                            value: "$\(String(format: "%.0f", estimatedValue))",
                            color: Color.sonexAmber
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.sonexSurface)
                    .cornerRadius(20)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                
                // Crates section header
                HStack {
                    Text("CRATES")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button("SORT") {
                        // TODO: Implement sort options
                    }
                    .font(.caption)
                    .foregroundColor(Color.sonexAmber)
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
                                CrateView(crate: crate)
                                    .onTapGesture {
                                        // TODO: Navigate to crate detail
                                    }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100) // Space for dock and FAB
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
            AddCrateSheet()
        }
    }
    
    @MainActor
    private func loadCrates(forceRefresh: Bool = false) async {
        isLoading = true
        
        do {
            crates = try await SonexDBManager.shared.fetchCrates(forceRefresh: forceRefresh)
            // TODO: Calculate total records from vinyl entries
            totalRecords = crates.reduce(0) { total, crate in
                total + (crate.vinyl_entry_ids.count ?? 0)
            }
        } catch {
            print("Failed to load crates: \(error)")
            // For offline functionality, we could load from local cache here
        }
        
        isLoading = false
    }
}

// MARK: - Supporting Views

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
    let crate: Crate
    
    var body: some View {
        VStack(spacing: 0) {
            // Record spines section
            VStack(spacing: 0) {
                // Colorful record spines
                RecordSpinesView(count: crate.vinyl_entry_ids.count ?? 0)
                    .frame(height: 40)
                
                // Crate body
                ZStack {
                    // Crate image background
                    Image("crate") // Using the crate asset from your project
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 80)
                        .clipped()
                    
                    // Crate label overlay
                    VStack {
                        Spacer()
                        
                        Text(crate.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(getCrateLabelColor())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(getCrateLabelBackground())
                            .cornerRadius(4)
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
                    .frame(width: CGFloat.random(in: 3...8))
            }
            
            if count == 0 {
                // Empty state - show a few muted spines
                ForEach(0..<5, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: CGFloat.random(in: 3...6))
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
