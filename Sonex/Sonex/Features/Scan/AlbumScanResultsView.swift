//
//  AlbumScanResultsView.swift
//  Sonex
//
//  Created by Assistant on 4/12/26.
//

import SwiftUI
import SonexShared

struct AlbumScanResultsView: View {
    @Bindable var registrationData: VinylRegistrationData
    @State private var showCameraView = false
    @State private var isUploadingImage = false
    @State private var uploadError: String?
    @State private var imageRefreshId = UUID() // Force AsyncImage refresh
    
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
                
                Text("Album Info")
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
            
            Spacer()
            
            // Album Details Card
            VStack(spacing: 0) {
                // Cover Art with Camera Button
                ZStack(alignment: .topTrailing) {
                    if let coverArtUrl = registrationData.coverArtUrl,
                       let url = URL(string: coverArtUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.blue.opacity(0.3))
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                )
                        }
                        .frame(width: 280, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.vertical, 16)
                        .id(imageRefreshId) // Force refresh when ID changes
                        .onAppear {
                            print("🖼️ [AsyncImage] onAppear - URL: \(coverArtUrl)")
                        }
                    } else {
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 280, height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.vertical, 16)
                            .overlay(
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.6))
                                    Text("No Cover Art")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            )
                    }
                    
                    // Camera Button
                    Button(action: {
                        showCameraView = true
                    }) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(.black.opacity(0.7))
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.top, 24)
                    .padding(.trailing, 8)
                    .disabled(isUploadingImage)
                    
                    // Loading overlay for upload
                    if isUploadingImage {
                        Rectangle()
                            .fill(.black.opacity(0.5))
                            .frame(width: 280, height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                VStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                    Text("Uploading...")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.top, 8)
                                }
                            )
                    }
                }
                
                // Album Info
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(registrationData.title.uppercased())
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        
                        Text(registrationData.artist)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if !registrationData.label.isEmpty && !registrationData.catalogNumber.isEmpty {
                            Text("\(registrationData.label) - \(registrationData.catalogNumber)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        
                        HStack {
                            Text(registrationData.mediaType.rawValue)
                            
                            if registrationData.releaseEdition == .limitedEdition {
                                Text("Limited Edition")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        
                        if !registrationData.editionNotes.isEmpty {
                            Text("\(registrationData.editionNotes)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        
                        if let year = registrationData.year {
                            HStack {
                                Text("\(Calendar.current.monthSymbols[5]) 6, \(year)")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .background(Color.sonexSurface.opacity(0.8))
            }
            .background(Color.sonexSurface.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Continue Button
            Button(action: {
                registrationData.nextStep()
            }) {
                HStack {
                    Text("Continue to Release Search")
                        .fontWeight(.semibold)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(.white)
                .background(Color.red.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .background(Color.black)
        .fullScreenCover(isPresented: $showCameraView) {
            AlbumCoverCameraView(isPresented: $showCameraView) { capturedImage in
                Task {
                    await uploadCoverArt(capturedImage)
                }
            }
        }
        .alert("Upload Error", isPresented: .constant(uploadError != nil)) {
            Button("OK") {
                uploadError = nil
            }
        } message: {
            Text(uploadError ?? "")
        }
        .onChange(of: isUploadingImage) { oldValue, newValue in
            print("🔄 [UI] isUploadingImage changed from \(oldValue) to \(newValue)")
        }
        .onChange(of: registrationData.coverArtUrl) { oldValue, newValue in
            print("🔄 [UI] coverArtUrl changed from '\(oldValue ?? "nil")' to '\(newValue ?? "nil")'")
        }
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func uploadCoverArt(_ image: UIImage) async {
        print("🚀 [uploadCoverArt] Starting upload process...")
        print("🔄 [uploadCoverArt] Setting isUploadingImage to true")
        isUploadingImage = true
        uploadError = nil
        
        defer {
            print("🔄 [uploadCoverArt] Setting isUploadingImage to false (defer)")
            isUploadingImage = false
        }
        
        do {
            // Check if there's an existing cover art URL that needs to be removed from storage
            if let existingUrl = registrationData.coverArtUrl,
               !existingUrl.isEmpty,
               isSupabaseStorageUrl(existingUrl) {
                
                print("🗑️ Removing existing cover art from storage: \(existingUrl)")
                
                do {
                    try await SonexDBManager.shared.deleteCoverArtFromStorage(url: existingUrl)
                    print("✅ Successfully removed existing cover art from storage")
                } catch {
                    print("⚠️ Warning: Failed to remove existing cover art from storage: \(error)")
                    // Continue with upload even if deletion fails
                }
            }
            
            print("☁️ [uploadCoverArt] Starting upload to storage...")
            let coverArtUrl = try await SonexDBManager.shared.uploadAndSetCoverArt(
                for: registrationData,
                image: image
            )
            
            print("✅ Successfully uploaded cover art: \(coverArtUrl)")
            print("🔄 [uploadCoverArt] Updating registrationData.coverArtUrl to: \(coverArtUrl)")
            
            // Force UI update by explicitly setting the cover art URL and refreshing AsyncImage
            await MainActor.run {
                print("🎯 [uploadCoverArt] MainActor: Updating coverArtUrl")
                registrationData.coverArtUrl = coverArtUrl
                imageRefreshId = UUID() // Force AsyncImage to refresh
                print("🔄 [uploadCoverArt] MainActor: Generated new imageRefreshId: \(imageRefreshId)")
            }
            
        } catch {
            print("❌ Failed to upload cover art: \(error)")
            await MainActor.run {
                print("❌ [uploadCoverArt] MainActor: Setting upload error")
                uploadError = error.localizedDescription
            }
        }
        
        print("🏁 [uploadCoverArt] Upload process completed")
    }
    
    private func isSupabaseStorageUrl(_ urlString: String) -> Bool {
        // Check if the URL is from Supabase storage
        // Typical Supabase storage URLs contain patterns like:
        // - supabase.co/storage/v1/object/public/
        // - supabase.in/storage/v1/object/public/
        return urlString.contains("supabase") && urlString.contains("/storage/v1/object/")
    }
}


