//
//  ConfirmationView.swift
//  Sonex
//
//  Created by Assistant on 4/14/26.
//

import SwiftUI
import SonexShared

struct ConfirmationView: View {
    @Bindable var registrationData: VinylRegistrationData
    private let dbManager = SonexDBManager.shared
    @State private var nfcManager = NFCManager()
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isConfirming = false
    @State private var hasTagHash = false
    @State private var crateName: String = "Unsorted"
    @Environment(\.dismiss) private var dismiss
    
    let onComplete: (VinylEntry) -> Void
    
    var body: some View {
        ZStack {
            Color.sonexCharcoal.ignoresSafeArea()
            
            if isLoading {
                loadingView
            } else if let vinyl = registrationData.registeredVinyl {
                confirmationContent(for: vinyl)
            } else {
                // No album associated with this tag hash
                noAlbumView
            }
        }
        .task {
            await loadRegisteredVinyl()
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .sonexAmber))
                .scaleEffect(1.5)
            
            Text("Fetching your registered vinyl...")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
    
    @ViewBuilder
    private func confirmationContent(for vinyl: VinylEntry) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                albumArtworkSection(for: vinyl)
                albumInfoSection(for: vinyl)
                detailsSection(for: vinyl)
                settingsSection(for: vinyl)
                confirmButton
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func albumArtworkSection(for vinyl: VinylEntry) -> some View {
        VStack(spacing: 16) {
            AsyncImage(url: URL(string: vinyl.coverArtUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.5))
                    }
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text(vinyl.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    if vinyl.releaseEdition != .standard {
                        Text("NM/NM")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.sonexAmber)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                
                Text(vinyl.artist)
                    .font(.subheadline)
                    .foregroundStyle(Color.sonexAmber)
            }
        }
    }
    
    @ViewBuilder
    private func detailsSection(for vinyl: VinylEntry) -> some View {
        VStack(spacing: 0) {
            
            if let pressing = vinyl.pressing, !pressing.isEmpty,
               let matrixCode = vinyl.matrixCode, !matrixCode.isEmpty,
               let catalogNumber = vinyl.catalogNumber, !catalogNumber.isEmpty
            {
                sectionHeader("DETAILS")
                VStack(spacing: 0){
                    detailRow(title: "PRESSING", value: pressing)
                    detailRow(title: "MATRIX CODE", value: matrixCode)
                    detailRow(title: "CATALOG NUMBER", value: catalogNumber)
                    detailRow(title: "MATRIX / RUNOUT", value: "\(matrixCode)", isLast: true)
                }
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    @ViewBuilder
    private func albumInfoSection(for vinyl: VinylEntry) -> some View {
        HStack(spacing: 8) {
            if let label = vinyl.label, !label.isEmpty {
                Text("\(label)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                
            if let year = vinyl.year {
                HStack(spacing: 16) {
                    Text("\(year)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
            }
            
            
                    
                    Text("Electronic, Hip Hop, Funk/Soul")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
    
    @ViewBuilder
    private func settingsSection(for vinyl: VinylEntry) -> some View {
        VStack(spacing: 0) {
            sectionHeader("SETTINGS")
            
            VStack(spacing: 0) {
                settingsRow(title: "STORED IN", value: crateName, action: {})
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LISTING")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        Text(vinyl.forSale ? "Listed" : "Not Listed")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    if vinyl.forSale, let askingPrice = vinyl.askingPrice {
                        Text("$\(Int(askingPrice))")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.sonexAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.sonexAmber.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(height: 1)
            
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 12)
            
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private func detailRow(title: String, value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(value)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if !isLast {
                Divider()
                    .background(.white.opacity(0.2))
                    .padding(.horizontal, 16)
            }
        }
    }
    
    @ViewBuilder
    private func settingsRow(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(value)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.sonexAmber)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.white.opacity(0.1))
    }
    
    @ViewBuilder
    private var confirmButton: some View {
        Button(action: {
            confirmRegistration()
        }) {
            HStack {
                if isConfirming {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text(hasTagHash ? "Confirm" : "Close")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(.white)
            .background(hasTagHash ? .red : Color.sonexAmber)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isConfirming)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            
            Text("Failed to load vinyl entry")
                .font(.headline)
                .foregroundStyle(.white)
            
            if let error = errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                Task {
                    await loadRegisteredVinyl()
                }
            }
            .buttonStyle(.bordered)
            .tint(.sonexAmber)
        }
        .padding()
    }
    
    @ViewBuilder
    private var noAlbumView: some View {
        VStack(spacing: 24) {
            Image(systemName: "vinyl.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.sonexAmber)
            
            VStack(spacing: 8) {
                Text("No Album Found")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("This NFC tag is not associated with any album in your collection.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            confirmButton
        }
        .padding()
    }
    
    private func loadRegisteredVinyl() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let tagHash = registrationData.nfcTagHash else {
                throw NSError(domain: "ConfirmationView", code: 1, userInfo: [NSLocalizedDescriptionKey: "No NFC tag hash found"])
            }
            
            // Fetch the registered vinyl from the database
            let vinyl = try await dbManager.checkNFCTagRegistration(tagHash: tagHash)
            
            await MainActor.run {
                if let vinyl = vinyl {
                    // Tag is already registered to an album
                    registrationData.registeredVinyl = vinyl
                    hasTagHash = true
                    
                    // Fetch the crate name for this vinyl
                    Task {
                        await loadCrateName(for: vinyl)
                    }
                } else {
                    // Tag is available (no album associated with this tag hash)
                    registrationData.registeredVinyl = nil
                    hasTagHash = false
                    crateName = "Unsorted"
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                hasTagHash = false
                isLoading = false
                crateName = "Unsorted"
            }
        }
    }
    
    private func loadCrateName(for vinyl: VinylEntry) async {
        do {
            // Use a more targeted approach if available, otherwise fall back to checking all crates
            if let crateName = try await fetchCrateNameDirectly(for: vinyl.id) {
                await MainActor.run {
                    self.crateName = crateName
                }
            } else {
                await MainActor.run {
                    self.crateName = "Unsorted"
                }
            }
        } catch {
            print("Failed to load crate name: \(error)")
            await MainActor.run {
                crateName = "Unsorted"
            }
        }
    }
    
    private func fetchCrateNameDirectly(for vinylId: String) async throws -> String? {
        // First try a direct database query approach if available
        // This would be more efficient than loading all crates
        
        // As a fallback, use the existing approach to check all crates
        let allCrates = try await dbManager.fetchCratesWithCounts(forceRefresh: false)
        
        for crate in allCrates {
            let vinylsInCrate = try await dbManager.fetchVinylEntries(inCrate: crate.id)
            if vinylsInCrate.contains(where: { $0.id == vinylId }) {
                return crate.name
            }
        }
        
        return nil
    }
    
    private func confirmRegistration() {
        // If there's no tag hash associated with the album, just dismiss the view
        if !hasTagHash {
            dismiss()
            return
        }
        
        guard let vinyl = registrationData.registeredVinyl,
              let tagHash = vinyl.nfcTagHash else { return }
        
        isConfirming = true
        
        Task {
            do {
                // Write the Sonex URL to the NFC tag
                let sonexURL = "sonex://album/\(tagHash)"
                try await nfcManager.writeURL(sonexURL, to: tagHash)
                
                await MainActor.run {
                    isConfirming = false
                    onComplete(vinyl)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to write URL to NFC tag: \(error.localizedDescription)"
                    isConfirming = false
                }
            }
        }
    }
}
