//
//  GradingView.swift
//  Sonex
//
//  Created by Assistant on 4/8/26.
//

import SwiftUI
import SonexShared

struct GradingView: View {
    @Bindable var registrationData: VinylRegistrationData
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Album Cover
                if let coverArtUrl = registrationData.coverArtUrl,
                   let url = URL(string: coverArtUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        albumCoverPlaceholder
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    albumCoverPlaceholder
                }
                
                // Grading Section
                VStack(spacing: 20) {
                    // Media Grading
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MEDIA")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            ForEach(VinylGrade.allCases, id: \.self) { grade in
                                GradeButton(
                                    grade: grade,
                                    isSelected: registrationData.mediaGrade == grade
                                ) {
                                    registrationData.mediaGrade = grade
                                }
                            }
                        }
                    }
                    
                    // Sleeve / Cover Grading
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SLEEVE / COVER")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            ForEach(VinylGrade.allCases, id: \.self) { grade in
                                GradeButton(
                                    grade: grade,
                                    isSelected: registrationData.sleeveGrade == grade
                                ) {
                                    registrationData.sleeveGrade = grade
                                }
                            }
                        }
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTES (optional)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        TextField("e.g., light ring wear on sleeve, plays beautifully", text: $registrationData.gradeNotes, axis: .vertical)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.sonexSurface)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .lineLimit(3...6)
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
            .padding(.vertical, 24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if let mediaGrade = registrationData.mediaGrade {
                    Text("Media: \(mediaGrade.displayName)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Button(action: {
                    registrationData.nextStep()
                }) {
                    Text("Get Estimated Value")
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
    }
    
    private var albumCoverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.sonexSurface)
            .frame(width: 80, height: 80)
            .overlay {
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
            }
    }
    
    private var isFormValid: Bool {
        registrationData.mediaGrade != nil
    }
}

struct GradeButton: View {
    let grade: VinylGrade
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(grade.rawValue)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(grade.displayName)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .foregroundStyle(isSelected ? Color.sonexCharcoal : .white)
            .background(isSelected ? Color.sonexAmber : Color.sonexSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? Color.sonexAmber : Color.clear,
                        lineWidth: 2
                    )
            )
        }
    }
}

#Preview {
    GradingView(registrationData: VinylRegistrationData())
        .background(Color.sonexCharcoal)
}