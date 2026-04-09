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
    let onComplete: (VinylEntry) -> Void
    
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
                                Text("US 1st pressing")
                            }
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Market Estimate
                VStack(spacing: 16) {
                    Text("DISCOGS MARKET ESTIMATE")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text("$185")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.sonexAmber)
                    
                    // Price breakdown
                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text("LAST SALE")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                            Text("$178")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.sonexAmber)
                        }
                        
                        VStack(spacing: 4) {
                            Text("MEDIAN / AVG")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                            Text("$182")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        
                        VStack(spacing: 4) {
                            Text("SALES / 30D")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                            Text("47")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal)
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
                                .foregroundStyle(.white)
                            
                            Text("Other collectors will see this record")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $registrationData.forSale)
                            .toggleStyle(SwitchToggleStyle(tint: Color.sonexAmber))
                    }
                    .padding()
                    .background(Color.sonexSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Price input when listing for sale
                    if registrationData.forSale {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Your Price")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            
                            HStack(spacing: 12) {
                                PriceButton(price: 120, isSelected: registrationData.askingPrice == 120) {
                                    registrationData.askingPrice = 120
                                }
                                
                                PriceButton(price: 185, isSelected: registrationData.askingPrice == 185) {
                                    registrationData.askingPrice = 185
                                }
                                
                                PriceButton(price: 210, isSelected: registrationData.askingPrice == 210) {
                                    registrationData.askingPrice = 210
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
                // Accept Offers toggle (shown when listing for sale)
                if registrationData.forSale {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accept Offers")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                            Text("Other collectors can make offers below asking")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: .constant(true))
                            .toggleStyle(SwitchToggleStyle(tint: Color.sonexAmber))
                    }
                    .padding(.horizontal)
                }
                
                Button(action: {
                    registerVinyl()
                }) {
                    HStack {
                        if isRegistering {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.sonexCharcoal))
                                .scaleEffect(0.8)
                        }
                        
                        Text(registrationData.forSale ? "Add to Collection & List for Sale" : "Add to Collection")
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
    
    private func registerVinyl() {
        guard !isRegistering else { return }
        
        isRegistering = true
        
        Task {
            do {
                let vinyl = try await dbManager.registerVinyl(
                    title: registrationData.title,
                    artist: registrationData.artist,
                    nfcTagHash: registrationData.nfcTagHash,
                    label: registrationData.label.isEmpty ? nil : registrationData.label,
                    year: registrationData.year,
                    pressing: registrationData.pressing.isEmpty ? nil : registrationData.pressing,
                    format: registrationData.format.isEmpty ? nil : registrationData.format,
                    grade: registrationData.mediaGrade,
                    gradeNotes: registrationData.gradeNotes.isEmpty ? nil : registrationData.gradeNotes,
                    coverArtUrl: registrationData.coverArtUrl,
                    forSale: registrationData.forSale,
                    askingPrice: registrationData.askingPrice
                )
                
                await MainActor.run {
                    onComplete(vinyl)
                    isRegistering = false
                }
            } catch {
                await MainActor.run {
                    // Handle error - could show alert
                    print("Failed to register vinyl: \(error)")
                    isRegistering = false
                }
            }
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

#Preview {
    PricingView(registrationData: VinylRegistrationData()) { _ in }
        .background(Color.sonexCharcoal)
}