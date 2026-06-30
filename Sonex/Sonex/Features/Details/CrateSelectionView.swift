//
//  CrateSelectionView.swift
//  Sonex
//
//  Created by Assistant on 4/18/26.
//

import SwiftUI
import SonexShared

struct CrateSelectionView: View {
    let selectedVinyls: [String]
    let currentCrateId: String
    let onMove: (String) -> Void
    
    @State private var availableCrates: [CrateWithCount] = []
    @State private var isLoading = true
    @State private var dbManager = SonexDBManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(TabRouter.self) private var tabRouter
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if availableCrates.isEmpty {
                    emptyStateView
                } else {
                    crateGridView
                }
            }
            .navigationTitle("Select Crate")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .task {
            await loadCrates()
        }
        .onAppear {
            tabRouter.hideDock()
        }
        .onDisappear {
            tabRouter.showDock()
        }
    }
    
    // MARK: - Views
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.sonexAmber))
                .scaleEffect(1.5)
            Text("Loading crates…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: 60))
                .foregroundStyle(Color.sonexAmber)
            VStack(spacing: 8) {
                Text("No Other Crates")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Create more crates to organize your collection.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var crateGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(availableCrates, id: \.id) { crate in
                    Button(action: {
                        onMove(crate.id)
                        dismiss()
                    }) {
                        CrateView(crate: crate)
                    }
                    .buttonStyle(CrateCardButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadCrates() async {
        do {
            let allCrates = try await dbManager.fetchCratesWithCounts()
            await MainActor.run {
                // Filter out the current crate, For Sale crate, and Unsorted crate
                self.availableCrates = allCrates.filter { crate in
                    crate.id != currentCrateId && 
                    crate.name != "For Sale" && 
                    crate.name != "Unsorted" &&
                    crate.name != "Wishlist"
                }
                self.isLoading = false
            }
        } catch {
            print("Failed to load crates: \(error)")
            await MainActor.run {
                self.availableCrates = []
                self.isLoading = false
            }
        }
    }
}

// MARK: - Button Style

struct CrateCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    CrateSelectionView(
        selectedVinyls: ["1", "2", "3"],
        currentCrateId: "current-crate-id",
        onMove: { _ in }
    )
}
