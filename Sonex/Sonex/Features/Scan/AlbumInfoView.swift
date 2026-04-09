//
//  AlbumInfoView.swift
//  Sonex
//
//  Created by Assistant on 4/8/26.
//

import SwiftUI
import SonexShared

struct AlbumInfoView: View {
    @Bindable var registrationData: VinylRegistrationData
    @FocusState private var focusedField: Field?
    
    enum Field: CaseIterable {
        case artist, title, label, year, pressing
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Album Cover Placeholder
                if let coverArtUrl = registrationData.coverArtUrl,
                   let url = URL(string: coverArtUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        albumCoverPlaceholder
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    albumCoverPlaceholder
                }
                
                // Form Fields
                VStack(spacing: 16) {
                    VinylTextField(
                        title: "ARTIST",
                        text: $registrationData.artist,
                        placeholder: "Miles Davis"
                    )
                    .focused($focusedField, equals: .artist)
                    .submitLabel(.next)
                    
                    VinylTextField(
                        title: "ALBUM TITLE",
                        text: $registrationData.title,
                        placeholder: "Kind of Blue"
                    )
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    
                    VinylTextField(
                        title: "LABEL",
                        text: $registrationData.label,
                        placeholder: "Columbia"
                    )
                    .focused($focusedField, equals: .label)
                    .submitLabel(.next)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("YEAR")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white.opacity(0.7))
                            
                            TextField("1959", value: $registrationData.year, format: .number)
                                .focused($focusedField, equals: .year)
                                .keyboardType(.numberPad)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.sonexSurface)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        VinylTextField(
                            title: "FORMAT",
                            text: $registrationData.format,
                            placeholder: "LP"
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PRESSING / EDITION (optional)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        TextField("US Original (1959)", text: $registrationData.pressing)
                            .focused($focusedField, equals: .pressing)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.sonexSurface)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .submitLabel(.done)
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
            .padding(.vertical, 24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Text("Matched via Discogs • 3 pressings found")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                
                Button(action: {
                    registrationData.nextStep()
                }) {
                    Text("Continue to Grading")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(Color.sonexCharcoal)
                        .background(Color.sonexAmber)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!isFormValid)
            }
            .padding()
            .background(Color.sonexCharcoal)
        }
        .onSubmit {
            focusNextField()
        }
    }
    
    private var albumCoverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.sonexSurface)
            .frame(width: 120, height: 120)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("No Cover")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
    }
    
    private var isFormValid: Bool {
        !registrationData.artist.isEmpty && !registrationData.title.isEmpty
    }
    
    private func focusNextField() {
        switch focusedField {
        case .artist:
            focusedField = .title
        case .title:
            focusedField = .label
        case .label:
            focusedField = .year
        case .year:
            focusedField = .pressing
        case .pressing, .none:
            focusedField = nil
        }
    }
}

struct VinylTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.7))
            
            TextField(placeholder, text: $text)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.sonexSurface)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    AlbumInfoView(registrationData: VinylRegistrationData())
        .background(Color.sonexCharcoal)
}
