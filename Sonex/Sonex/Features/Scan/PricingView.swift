//
//  PricingView.swift
//  Sonex
//
//  Created by Assistant on 4/8/26.
//

import SwiftUI
import SonexShared

struct PricingView: View {
    @Bindable var registrationData: VinylRegistrationData
    @State private var dbManager = SonexDBManager.shared
    @State private var isRegistering = false
    @FocusState private var isPriceFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Album Cover and Title
                HStack(spacing: 16) {
                    if let coverArtUrl = registrationData.coverArtUrl,
                       let url = URL(string: coverArtUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            albumCoverPlaceholder
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        albumCoverPlaceholder
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(registrationData.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Text(registrationData.artist)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                        
                        if let grade = registrationData.mediaGrade {
                            HStack(spacing: 4) {
                                Text("\(grade.rawValue) condition")
                                Circle()
                                    .fill(.white.opacity(0.3))
                                    .frame(width: 4, height: 4)
//                                Text("US 1st pressing")
                            }
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                
                
                // Collection Type Info Section
                if registrationData.isWishlist {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .font(.title3)
                                .foregroundStyle(.pink)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("WISHLIST ITEM")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white.opacity(0.7))
                                
                                Text("Adding to Wishlist")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                Text("This record will be saved to your wishlist for future purchase")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.pink.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                
                // List for Sale Toggle
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LISTING")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white.opacity(0.7))
                            
                            Text("List for Sale")
                                .font(.headline)
                                .foregroundStyle(registrationData.isWishlist ? .white.opacity(0.5) : .white)
                            
                            Text(registrationData.isWishlist ? "Not available for wishlist items" : "Other collectors will see this record")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $registrationData.forSale)
                            .toggleStyle(SwitchToggleStyle(tint: Color.sonexAmber))
                            .disabled(registrationData.isWishlist)
                    }
                    .padding()
                    .background(Color.sonexSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Price input when listing for sale
                    if registrationData.forSale && !registrationData.isWishlist {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Your Price")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            
                            HStack(spacing: 12) {
                                PriceButton(price: 40, isSelected: registrationData.askingPrice == 40) {
                                    registrationData.askingPrice = 40
                                }
                                
                                PriceButton(price: 60, isSelected: registrationData.askingPrice == 60) {
                                    registrationData.askingPrice = 60
                                }
                                
                                PriceButton(price: 80, isSelected: registrationData.askingPrice == 80) {
                                    registrationData.askingPrice = 80
                                }
                            }
                            
                            // Custom price input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Or enter custom price:")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                
                                HStack {
                                    Text("$")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                    
                                    TextField("185", value: $registrationData.askingPrice, format: .number)
                                        .keyboardType(.decimalPad)
                                        .focused($isPriceFocused)
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.sonexSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding()
                        .background(Color.sonexSurface.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(.horizontal)
                .animation(.easeInOut(duration: 0.3), value: registrationData.forSale)
                
                Spacer(minLength: 100)
            }
            .padding(.vertical, 24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                
                Button(action: {
                    registerVinyl()
                }) {
                    HStack {
                        if isRegistering {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.sonexCharcoal))
                                .scaleEffect(0.8)
                        }
                        
                        Text(getButtonText())
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(Color.sonexCharcoal)
                    .background(Color.sonexAmber)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isRegistering)
                .padding(.horizontal)
            }
            .padding(.bottom)
            .background(Color.sonexCharcoal)
        }
        .onTapGesture {
            isPriceFocused = false
        }
    }
    
    private var albumCoverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.sonexSurface)
            .frame(width: 60, height: 60)
            .overlay {
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
            }
    }
    
    private func mapToSonexReleaseEdition(_ edition: VinylRegistrationData.ReleaseEdition) -> ReleaseEdition {
        let mappedEdition: ReleaseEdition
        switch edition {
        case .standard:
            mappedEdition = .standard
        case .limitedEdition:
            mappedEdition = .limitedEdition
        case .reissue:
            mappedEdition = .reissue
        }
        
        print("🔄 Mapping release edition: '\(edition.rawValue)' -> '\(mappedEdition)'")
        return mappedEdition
    }
    
    private func getButtonText() -> String {
        if registrationData.isWishlist {
            return "Add to Wishlist"
        } else if registrationData.forSale {
            return "Add to Collection & List for Sale"
        } else {
            return "Add to Collection"
        }
    }
    
    private func registerVinyl() {
        guard !isRegistering else { return }
        
        isRegistering = true
        
        Task {
            do {
                // Debug: Log the release edition before saving
                let mappedEdition = mapToSonexReleaseEdition(registrationData.releaseEdition)
                print("💾 About to save vinyl with release edition: '\(mappedEdition.rawValue)'")
                
                // Determine which crate to use
                let targetCrateId: String
                let crateName: String
                if registrationData.isWishlist {
                    targetCrateId = try await dbManager.resolveWishlistCrateId()
                    crateName = "Wishlist"
                } else {
                    // Use unsorted crate for owned items
                    targetCrateId = try await dbManager.resolveUnsortedCrateId()
                    crateName = "Unsorted"
                }
                
                print("📦 [registerVinyl] Adding \(registrationData.isWishlist ? "wishlist" : "owned") item to \(crateName) crate")
                
                let vinyl = try await dbManager.registerVinyl(
                    title: registrationData.title,
                    artist: registrationData.artist,
                    crateId: targetCrateId,
                    discogsId: registrationData.discogsId,
                    nfcTagHash: registrationData.nfcTagHash,
                    label: registrationData.label.isEmpty ? nil : registrationData.label,
                    year: registrationData.year,
                    pressing: registrationData.pressing.isEmpty ? nil : registrationData.pressing,
                    format: registrationData.format.isEmpty ? nil : registrationData.format + " " + (registrationData.vinylSize ?? ""),
                    mediaGrade: registrationData.mediaGrade,
                    gradeNotes: registrationData.gradeNotes.isEmpty ? nil : registrationData.gradeNotes,
                    coverArtUrl: registrationData.coverArtUrl,
                    forSale: registrationData.forSale,
                    askingPrice: registrationData.askingPrice,
                    catalogNumber: registrationData.catalogNumber.isEmpty ? nil : registrationData.catalogNumber,
                    matrixCode: registrationData.matrixCode.isEmpty ? nil : registrationData.matrixCode,
                    barcode: registrationData.barcode.isEmpty ? nil : registrationData.barcode,
                    releaseEdition: mappedEdition,
                    editionNotes: registrationData.editionNotes.isEmpty ? nil : registrationData.editionNotes,
                    sleeveGrade: registrationData.sleeveGrade
                )
                
                await MainActor.run {
                    print("🎵 Successfully registered vinyl: \(vinyl.title)")
                    print("📄 Current step before nextStep(): \(registrationData.currentStep)")
                    registrationData.registeredVinyl = vinyl
                    registrationData.nextStep()
                    print("📄 Current step after nextStep(): \(registrationData.currentStep)")
                    isRegistering = false
                }
            } catch {
                await MainActor.run {
                    print("❌ Failed to register vinyl: \(error)")
                    print("📄 Current step during error: \(registrationData.currentStep)")
                    // Handle error - could show alert
                    isRegistering = false
                }
            }
            
            registrationData.nextStep()
        }
    }
}

struct PriceButton: View {
    let price: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("$\(price)")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundStyle(isSelected ? Color.sonexCharcoal : .white)
                .background(isSelected ? Color.sonexAmber : Color.sonexSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

