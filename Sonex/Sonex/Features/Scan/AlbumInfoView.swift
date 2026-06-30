//
//  AlbumInfoView.swift
//  Sonex
//
//  Created by Assistant on 4/8/26.
//

import SwiftUI
import SonexShared
import VisionKit
import Vision
import AVFoundation

struct AlbumInfoView: View {
    @Bindable var registrationData: VinylRegistrationData
    @FocusState private var focusedField: Field?
    @State private var musicBrainzManager = MusicBrainzAPIManager.shared
    @State private var artistSuggestions: [MusicBrainzArtist] = []
    @State private var albumSuggestions: [MusicBrainzRelease] = []
    @State private var isSearchingArtists = false
    @State private var isSearchingAlbums = false
    @State private var isLoadingData = false
    @State private var searchTask: Task<Void, Never>?
    @State private var albumSearchTask: Task<Void, Never>?
    @State private var showingCamera = false
    @State private var isProcessingImage = false
    @State private var textRecognitionManager = TextRecognitionManager.shared
    @State private var geminiManager = GeminiManager.shared
    @State private var cameraPermissionManager = CameraPermissionManager.shared
    @State private var showingPermissionAlert = false
    @State private var showingRateLimitAlert = false
    @State private var rateLimitMessage = ""
    @State private var currentStep: InputStep = .basic
    
    enum Field: CaseIterable {
        case artist, title, label, catalogNumber, barcode
    }
    
    enum InputStep {
        case basic      // Collection type, scan, artist, album title, label
        case details    // Catalog number, matrix code, barcode, release, size
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    ownedWishlistToggle
                    albumCoverSection
                    
                    switch currentStep {
                    case .basic:
                        basicInputSection
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    case .details:
                        detailsInputSection
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                    
                    Spacer(minLength: 120)
                }
                .padding(.vertical, 24)
            }
            
            bottomButtonSection
        }
//        .background(backgroundGradient)
        .onAppear {
            // Ensure vinyl is always selected
            registrationData.mediaType = .vinyl
        }
        .sheet(isPresented: $showingCamera) {
            CameraCaptureView(isPresented: $showingCamera) { image in
                Task {
                    await processImageForAlbumSuggestion(image)
                }
            }
            .ignoresSafeArea()
        }
        .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                cameraPermissionManager.openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable camera access in Settings to scan album covers for automatic text recognition.")
        }
        .alert("API Rate Limit", isPresented: $showingRateLimitAlert) {
            Button("OK") { }
        } message: {
            Text(rateLimitMessage)
        }
    }
}

// MARK: - View Components
extension AlbumInfoView {
    private var ownedWishlistToggle: some View {
        VStack(spacing: 16) {
            HStack {
                Text("COLLECTION TYPE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Status indicator
                HStack(spacing: 4) {
                    Image(systemName: registrationData.isWishlist ? "heart.fill" : "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(registrationData.isWishlist ? .pink : .green)
                    
                    Text(registrationData.isWishlist ? "Wishlist" : "Owned")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 32)
            
            HStack(spacing: 0) {
                Button(action: {
                    registrationData.isWishlist = false
                    // Reset for sale when switching to owned if it was disabled due to wishlist
                    if !registrationData.isWishlist {
                        // User can now set for sale if they want
                    }
                    // Reset to basic step when switching collection type
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .basic
                    }
                }) {
                    Text("Owned")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(!registrationData.isWishlist ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(!registrationData.isWishlist ? Color.sonexAmber : Color.gray.opacity(0.3))
                }
                
                Button(action: {
                    registrationData.isWishlist = true
                    // Disable for sale when switching to wishlist
                    registrationData.forSale = false
                    // Reset to basic step when switching collection type
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .basic
                    }
                }) {
                    Text("Wishlist")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(registrationData.isWishlist ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(registrationData.isWishlist ? Color.sonexAmber : Color.gray.opacity(0.3))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 32)
        }
    }
    
    private var albumCoverSection: some View {
        albumCoverDisplay
    }
    
    private var albumCoverDisplay: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.sonexSurface.opacity(0.6))
            .frame(width: 140, height: 140)
            .overlay {
                Image("Vinyl-graphic")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.black.opacity(0.8))
            }
            .overlay(cameraButtonOverlay)
    }
    
    private var cameraButtonOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    Task {
                        await handleCameraButtonTap()
                    }
                }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.black.opacity(0.8))
                        .clipShape(Circle())
                }
                .disabled(isProcessingImage || !textRecognitionManager.isSupported)
                .opacity((isProcessingImage || !textRecognitionManager.isSupported) ? 0.5 : 1.0)
                .padding(8)
            }
        }
    }
    

    // MARK: - Basic Input Section (Step 1)
    private var basicInputSection: some View {
        VStack(spacing: 24) {
            searchSectionHeader
            basicFormFieldsSection
        }
    }
    
    private var searchSectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BASIC INFORMATION")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if textRecognitionManager.isSupported {
                Text("Use the camera button above to scan album text for auto-suggestions")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 16)
    }
    
    private var basicFormFieldsSection: some View {
        VStack(spacing: 16) {
            artistFieldWithAutocomplete
            albumTitleFieldWithAutocomplete
            labelField
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Details Input Section (Step 2)
    private var detailsInputSection: some View {
        VStack(spacing: 24) {
            detailsSectionHeader
            detailsFormFieldsSection
        }
    }
    
    private var detailsSectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DETAILED INFORMATION")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Complete the record details for your owned collection")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 32)
        .padding(.top, 16)
    }
    
    private var detailsFormFieldsSection: some View {
        VStack(spacing: 16) {
            catalogNumberField
            matrixCodeField
            barcodeField
            releaseEditionSelector
            editionNotesField
            vinylSizeSelector
        }
        .padding(.horizontal, 32)
    }
    
    private var artistFieldWithAutocomplete: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ARTIST")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.7))
            
            VStack(spacing: 0) {
                TextField("Artist Name", text: $registrationData.artist)
                    .focused($focusedField, equals: .artist)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.sonexSurface)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: registrationData.artist) {
                        searchArtists()
                        // Clear album suggestions when artist changes
                        albumSuggestions = []
                        albumSearchTask?.cancel()
                    }
                
                artistSuggestionsDropdown
            }
        }
    }
    
    private var artistSuggestionsDropdown: some View {
        Group {
            if !artistSuggestions.isEmpty && focusedField == .artist {
                VStack(spacing: 0) {
                    ForEach(artistSuggestions.prefix(5)) { artist in
                        Button(action: {
                            registrationData.artist = artist.name
                            artistSuggestions = []
                            // Clear album suggestions when artist is selected
                            albumSuggestions = []
                            albumSearchTask?.cancel()
                            focusedField = .title
                        }) {
                            HStack {
                                Text(artist.displayName)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.sonexSurface.opacity(0.8))
                        }
                        
                        if artist.id != artistSuggestions.prefix(5).last?.id {
                            Divider()
                                .background(Color.white.opacity(0.2))
                        }
                    }
                }
                .background(Color.sonexSurface.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    private var albumTitleFieldWithAutocomplete: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ALBUM TITLE")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.7))
            
            VStack(spacing: 0) {
                HStack {
                    TextField("Album Title", text: $registrationData.title)
                        .focused($focusedField, equals: .title)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.sonexSurface)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onChange(of: registrationData.title) {
                            searchAlbumTitles()
                        }
                    
                    if isSearchingAlbums && !registrationData.title.isEmpty {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white.opacity(0.7))
                            .padding(.trailing, 8)
                    }
                }
                
                albumTitleHintView
                albumSuggestionsDropdown
            }
        }
    }
    
    private var albumTitleHintView: some View {
        Group {
            if registrationData.artist.isEmpty && !registrationData.title.isEmpty && focusedField == .title {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text("Enter artist name first for album suggestions")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private var albumSuggestionsDropdown: some View {
        Group {
            if !albumSuggestions.isEmpty && focusedField == .title && !registrationData.artist.isEmpty {
                VStack(spacing: 0) {
                    ForEach(albumSuggestions.prefix(5)) { album in
                        Button(action: {
                            registrationData.title = album.title
                            // Auto-fill additional data if available
                            if let year = album.year {
                                registrationData.year = year
                            }
                            if let labelName = album.labelName {
                                registrationData.label = labelName
                            }
                            if let barcode = album.barcode {
                                registrationData.barcode = barcode
                            }
                            if let catalogNumber = album.labelInfo?.first?.catalogNumber {
                                registrationData.catalogNumber = catalogNumber
                            }
                            albumSuggestions = []
                            focusedField = .label
                        }) {
                            albumSuggestionRow(album: album)
                        }
                        
                        if album.id != albumSuggestions.prefix(5).last?.id {
                            Divider()
                                .background(Color.white.opacity(0.2))
                        }
                    }
                }
                .background(Color.sonexSurface.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    private func albumSuggestionRow(album: MusicBrainzRelease) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    if let year = album.year {
                        Text("\(year)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    if let labelName = album.labelName {
                        Text("\(labelName)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.sonexSurface.opacity(0.8))
    }
    
    private var labelField: some View {
        AlbumTextField(
            title: "LABEL",
            text: $registrationData.label,
            placeholder: "Record Label",
            focusState: $focusedField,
            field: .label
        )
    }
    
    private var catalogNumberField: some View {
        AlbumTextField(
            title: "CATALOG NUMBER",
            text: $registrationData.catalogNumber,
            placeholder: "Catalog Number",
            focusState: $focusedField,
            field: .catalogNumber
        )
    }
    
    private var matrixCodeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MATRIX CODE (optional)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.7))
            
            TextField("Matrix Code", text: $registrationData.matrixCode)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.sonexSurface)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var barcodeField: some View {
        AlbumTextField(
            title: "BARCODE",
            text: $registrationData.barcode,
            placeholder: "Barcode (if available)",
            focusState: $focusedField,
            field: .barcode
        )
    }
    
    private var releaseEditionSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RELEASE")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                Text("Selected: \(registrationData.releaseEdition.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            HStack(spacing: 8) {
                ForEach(VinylRegistrationData.ReleaseEdition.allCases, id: \.self) { edition in
                    Button(action: {
                        print("🎛️ Selected release edition: \(edition.rawValue)")
                        registrationData.releaseEdition = edition
                        print("🎛️ Registration data now has: \(registrationData.releaseEdition.rawValue)")
                    }) {
                        Text(edition.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(registrationData.releaseEdition == edition ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(registrationData.releaseEdition == edition ? Color.white.opacity(0.9) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var editionNotesField: some View {
        if registrationData.releaseEdition == .limitedEdition || registrationData.releaseEdition == .reissue {
            VStack(alignment: .leading, spacing: 8) {
                Text("EDITION NOTES")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.7))
                
                TextField("Special edition details", text: $registrationData.editionNotes)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.sonexSurface)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
    
    private var vinylSizeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECORD SIZE")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.7))
            
            HStack(spacing: 8) {
                ForEach(VinylRegistrationData.VinylSize.allCases, id: \.self) { size in
                    Button(action: {
    //                    print("🎛️ Selected size: \(size.rawValue)")
                        registrationData.vinylSize = size.rawValue
    //                    print("🎛️ Registration data now has: \(registrationData.vinylSize)")
                    }) {
                        Text(size.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(registrationData.vinylSize == size.rawValue ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(registrationData.vinylSize == size.rawValue ? Color.white.opacity(0.9) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
        
    }
    
    private var bottomButtonSection: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.2))
            
            HStack(spacing: 16) {
                // Back button for details step
                if currentStep == .details {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = .basic
                        }
                    }) {
                        Text("Back")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(.white)
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                
                // Main action button
                Button(action: {
                    Task {
                        await handleMainButtonAction()
                    }
                }) {
                    HStack {
                        if isLoadingData || isProcessingImage {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text(getMainButtonText())
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.black)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!isMainButtonEnabled || isLoadingData || isProcessingImage)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.2),
                Color.red.opacity(0.8)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Helper Methods
extension AlbumInfoView {
    // MARK: - Button Logic
    func handleMainButtonAction() async {
        switch currentStep {
        case .basic:
            if registrationData.isWishlist {
                // For wishlist items, fetch data and proceed directly to final step
                await fetchCompleteReleaseData()
            } else {
                // For owned items, move to details step
                await fetchBasicReleaseData()
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = .details
                }
            }
        case .details:
            // Complete the registration process
            await fetchCompleteReleaseData()
        }
    }
    
    var isMainButtonEnabled: Bool {
        switch currentStep {
        case .basic:
            return isBasicFormValid
        case .details:
            return isBasicFormValid // Details are optional for owned items
        }
    }
    
    func getMainButtonText() -> String {
        if isProcessingImage {
            return "Processing Image..."
        }
        
        switch currentStep {
        case .basic:
            if registrationData.isWishlist {
                return "Add to Wishlist"
            } else {
                return "Continue"
            }
        case .details:
            return "Add to Collection"
        }
    }
    
    var isBasicFormValid: Bool {
        !registrationData.artist.isEmpty && !registrationData.title.isEmpty
    }
    
    // MARK: - API Methods
    func fetchBasicReleaseData() async {
        isLoadingData = true
        
        do {
            // Search for releases to get basic data
            let releases = try await musicBrainzManager.searchReleases(
                artist: registrationData.artist,
                title: registrationData.title
            )
            
            if let firstRelease = releases.first {
                // Update registration data with basic MusicBrainz info
                registrationData.musicBrainzId = firstRelease.id
                
                if registrationData.year == nil, let year = firstRelease.year {
                    registrationData.year = year
                }
                
                if registrationData.label.isEmpty, let label = firstRelease.labelName {
                    registrationData.label = label
                }
                
                // Try to get cover art
                if let coverArtUrl = try? await musicBrainzManager.getCoverArtURL(releaseId: firstRelease.id) {
                    registrationData.coverArtUrl = coverArtUrl
                }
            }
            
            // Set format to Vinyl
            registrationData.format = "Vinyl"
            
        } catch {
            print("Error fetching basic release data: \(error)")
            
            // Even if API fails, set format to Vinyl
            registrationData.format = "Vinyl"
        }
        
        isLoadingData = false
    }
    func handleCameraButtonTap() async {
        guard textRecognitionManager.isSupported else {
            return
        }
        
        if cameraPermissionManager.isAuthorized {
            showingCamera = true
        } else if cameraPermissionManager.canRequestPermission {
            let granted = await cameraPermissionManager.requestCameraPermission()
            if granted {
                showingCamera = true
            } else {
                showingPermissionAlert = true
            }
        } else {
            showingPermissionAlert = true
        }
    }
    
    @MainActor
    func processImageForAlbumSuggestion(_ image: UIImage) async {
        isProcessingImage = true
        
        do {
            // Step 1: Extract text from the image
            let recognizedWords = try await textRecognitionManager.recognizeText(from: image)
            print("🔍 Recognized words: \(recognizedWords)")
            
            // Check if we have enough text to work with
            guard !recognizedWords.isEmpty else {
                print("🔍 No text recognized from image")
                isProcessingImage = false
                return
            }
            
            // Step 2: Get AI suggestion with rate limiting
            let suggestion = try await geminiManager.suggestAlbumFromText(recognizedWords)
            
            if let suggestion = suggestion {
                print("🤖 AI Suggestion: \(suggestion.artist) - \(suggestion.album) (confidence: \(suggestion.confidence))")
                
                // Step 3: Pre-fill the form with AI suggestions
                registrationData.artist = suggestion.artist
                registrationData.title = suggestion.album
                
                // Clear any existing suggestions to show the new data
                artistSuggestions = []
                albumSuggestions = []
                
            } else {
                print("🤖 AI could not identify album with sufficient confidence")
            }
            
        } catch {
            print("🔍 Error processing image: \(error)")
            
            // Handle specific error cases
            if case GeminiError.apiError(let statusCode) = error {
                print("🚫 Gemini API Error \(statusCode): \(error.localizedDescription)")
                
                if statusCode == 429 {
                    print("💡 Rate limit hit. Try again in a few moments.")
                    rateLimitMessage = "You've reached the API rate limit. Please wait a few moments before scanning another image."
                    showingRateLimitAlert = true
                } else if statusCode == 401 || statusCode == 403 {
                    rateLimitMessage = "API authentication failed. Please check your API key configuration."
                    showingRateLimitAlert = true
                } else {
                    rateLimitMessage = "API request failed with error \(statusCode). Please try again later."
                    showingRateLimitAlert = true
                }
            }
            
            // Could show an alert here for user feedback
            // For now, we'll fail silently but log the error
        }
        
        isProcessingImage = false
    }
    
    // MARK: - Camera and Image Processing
    func searchArtists() {
        searchTask?.cancel()
        
        guard !registrationData.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            artistSuggestions = []
            return
        }
        
        searchTask = Task {
            isSearchingArtists = true
            
            do {
                try await Task.sleep(for: .milliseconds(300)) // Debounce
                
                if !Task.isCancelled {
                    let suggestions = try await musicBrainzManager.searchArtists(query: registrationData.artist)
                    
                    await MainActor.run {
                        if !Task.isCancelled {
                            self.artistSuggestions = suggestions
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.artistSuggestions = []
                }
            }
            
            await MainActor.run {
                isSearchingArtists = false
            }
        }
    }
    
    func searchAlbumTitles() {
        albumSearchTask?.cancel()
        
        guard !registrationData.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !registrationData.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            albumSuggestions = []
            return
        }
        
        albumSearchTask = Task {
            isSearchingAlbums = true
            
            do {
                try await Task.sleep(for: .milliseconds(300)) // Debounce
                
                if !Task.isCancelled {
                    let suggestions = try await musicBrainzManager.searchAlbumTitles(
                        artist: registrationData.artist,
                        titleQuery: registrationData.title
                    )
                    
                    await MainActor.run {
                        if !Task.isCancelled {
                            self.albumSuggestions = suggestions
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.albumSuggestions = []
                    print("Album search error: \(error)")
                }
            }
            
            await MainActor.run {
                isSearchingAlbums = false
            }
        }
    }
    
    func fetchCompleteReleaseData() async {
        isLoadingData = true
        
        do {
            // Search for releases
            let releases = try await musicBrainzManager.searchReleases(
                artist: registrationData.artist,
                title: registrationData.title
            )
            
            if let firstRelease = releases.first {
                // Update registration data with complete MusicBrainz info
                registrationData.musicBrainzId = firstRelease.id
                
                if registrationData.year == nil, let year = firstRelease.year {
                    registrationData.year = year
                }
                
                if registrationData.label.isEmpty, let label = firstRelease.labelName {
                    registrationData.label = label
                }
                
                if registrationData.barcode.isEmpty, let barcode = firstRelease.barcode {
                    registrationData.barcode = barcode
                }
                
                if registrationData.catalogNumber.isEmpty,
                   let catalogNumber = firstRelease.labelInfo?.first?.catalogNumber {
                    registrationData.catalogNumber = catalogNumber
                }
                
                // Try to get cover art if not already set
                if registrationData.coverArtUrl == nil,
                   let coverArtUrl = try? await musicBrainzManager.getCoverArtURL(releaseId: firstRelease.id) {
                    registrationData.coverArtUrl = coverArtUrl
                }
            }
            
            // Set format to Vinyl
            registrationData.format = "Vinyl"
            
            // Proceed to next step
            registrationData.nextStep()
            
        } catch {
            print("Error fetching complete release data: \(error)")
            
            // Even if API fails, set format to Vinyl
            registrationData.format = "Vinyl"
            
            // Still proceed to next step even if API fails
            registrationData.nextStep()
        }
        
        isLoadingData = false
    }


}

struct AlbumTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    @FocusState.Binding var focusState: AlbumInfoView.Field?
    let field: AlbumInfoView.Field
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.7))
            
            TextField(placeholder, text: $text)
                .focused($focusState, equals: field)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.sonexSurface)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    @Previewable @State var sampleData = VinylRegistrationData()
    AlbumInfoView(registrationData: sampleData)
}
