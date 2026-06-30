//
//  AlbumDetailsView.swift
//  Sonex
//
//  Created by Assistant on 4/14/26.
//  Updated: 4/21/26 - Added camera functionality for updating cover art
//

import SwiftUI
import SonexShared

struct AlbumDetailsView: View {
    @State private var vinyl: VinylEntry
    @State private var dbManager = SonexDBManager.shared
    @State private var showingLocationEditor = false
    @State private var editedLocationNote: String = ""
    @State private var isUpdatingLocation = false
    @State private var showingGradeNotesEditor = false
    @State private var editedGradeNotes: String = ""
    @State private var isUpdatingGradeNotes = false
    @State private var showingEditionNotesEditor = false
    @State private var editedEditionNotes: String = ""
    @State private var isUpdatingEditionNotes = false
    @State private var showingCrateSelection = false
    @State private var showingPricingEditor = false
    @State private var vinylCrates: [Crate] = []
    @State private var isLoadingCrates = false
    @State private var showCameraView = false
    @State private var isUploadingImage = false
    @State private var uploadError: String?
    @State private var imageRefreshId = UUID() // Force AsyncImage refresh
    @State private var currentUser: SonexUser?
    @State private var vinylOwner: SonexUser?
    @State private var isLoadingOwner = false
    @State private var existsInUserCollection = false
    @State private var isCheckingUserCollection = false
    @State private var isAddingToWishlist = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeletingRecord = false
    @Environment(\.dismiss) private var dismiss
    @Environment(TabRouter.self) private var tabRouter
    
    init(vinyl: VinylEntry) {
        self._vinyl = State(initialValue: vinyl)
    }
    
    // Computed properties for convenience
    private var isCurrentUserOwner: Bool {
        guard let currentUser = currentUser else { return false }
        return vinyl.ownerId == currentUser.id
    }
    
    private var shouldShowOwnerControls: Bool {
        isCurrentUserOwner
    }
    
    private var isInWishlistCrate: Bool {
        vinylCrates.contains { $0.name == "Wishlist" }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        albumArtworkSection
                        albumInfoSection
                        detailsSection
                        
                        // Hide notes and artifacts sections for wishlist items
                        if !isInWishlistCrate {
                            notesSection
                        }
                        
                        settingsSection
                        
                        // Delete section - only visible to owner
                        if shouldShowOwnerControls {
                            deleteSection
                        }
                        
                        // Hide artifacts section for wishlist items
                        if !isInWishlistCrate {
                            artifactsSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Album Details")
            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Close") {
//                        dismiss()
//                    }
//                    .foregroundStyle(.white)
//                }
//            }
        }
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
        .onAppear() {
            tabRouter.hideDock()
        }
        .onDisappear {
            tabRouter.showDock()
        }
        .onChange(of: isUploadingImage) { oldValue, newValue in
            print("🔄 [UI] isUploadingImage changed from \(oldValue) to \(newValue)")
        }
        .onChange(of: vinyl.coverArtUrl) { oldValue, newValue in
            print("🔄 [UI] coverArtUrl changed from '\(oldValue ?? "nil")' to '\(newValue ?? "nil")'")
            // Force AsyncImage refresh when cover art URL changes
            imageRefreshId = UUID()
        }
        .task {
            await loadInitialData()
        }
    }
    
    @ViewBuilder
    private var albumArtworkSection: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: vinyl.coverArtUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            if isUploadingImage {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                            } else {
                                Image(systemName: "music.note")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                }
                .frame(width: 350, height: 350)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .id(imageRefreshId) // Force refresh when ID changes
                .overlay {
                    // Loading overlay for upload
                    if isUploadingImage {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.black.opacity(0.5))
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
                
                // Camera Button - Only visible to owner and not for wishlist items
                if shouldShowOwnerControls && !isInWishlistCrate {
                    Button(action: {
                        showCameraView = true
                    }) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(.black.opacity(0.7))
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                    .disabled(isUploadingImage)
                }
            }
            
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text(vinyl.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    // Hide grade display for wishlist items
                    if !isInWishlistCrate {
                        Text("\(vinyl.mediaGrade?.rawValue ?? "N/A")/\(vinyl.sleeveGrade?.rawValue ?? "N/A")")
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
                    .multilineTextAlignment(.center)
                
                if let format = vinyl.format {
                    Text(format)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    @ViewBuilder
    private var detailsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("DETAILS")
            
            VStack(spacing: 0) {
                // Owner information - show if current user is not the owner
                if !isCurrentUserOwner {
                    let ownerName = vinylOwner?.displayName ?? vinylOwner?.username ?? "Unknown Owner"
                    
                    NavigationLink(destination: UserDetailsView(userId: vinyl.ownerId)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("OWNER")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.6))
                                Text(ownerName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // NFC Tag status
                let isTagged = vinyl.nfcTagHash != nil && !(vinyl.nfcTagHash?.isEmpty ?? true)
                detailRow(title: "NFC TAG", value: isTagged ? "Tagged" : "Not Tagged")
                
                detailRow(title: "PRESSING", value: vinyl.releaseEdition.rawValue.capitalized)
                
                // Hide barcode for wishlist items
                if !isInWishlistCrate, let barcode = vinyl.barcode, !barcode.isEmpty {
                    let hasMatrixCatalog = vinyl.matrixCode?.isEmpty == false && vinyl.catalogNumber?.isEmpty == false
                    detailRow(title: "BARCODE", value: barcode, isLast: !hasMatrixCatalog)
                }
                
                if let matrixCode = vinyl.matrixCode, !matrixCode.isEmpty,
                   let catalogNumber = vinyl.catalogNumber, !catalogNumber.isEmpty {
                    detailRow(title: "MATRIX / CATALOG", value: "\(matrixCode) - \(catalogNumber)", isLast: true)
                }
                
                // This ensures we always have at least one view in the VStack
                if vinyl.pressing?.isEmpty != false && vinyl.createdAt == nil && 
                   (vinyl.matrixCode?.isEmpty != false || vinyl.catalogNumber?.isEmpty != false) &&
                   vinyl.barcode?.isEmpty != false {
                    HStack {
                        Text("No additional details available")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        Spacer()
                    }
                }
            }
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    @ViewBuilder
    private var albumInfoSection: some View {
        VStack(alignment: .center, spacing: 8) {
            // Combine label and year in a single line
            HStack(spacing: 8) {
                if let label = vinyl.label, !label.isEmpty {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                
                if let label = vinyl.label, !label.isEmpty, let year = vinyl.year {
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                if let year = vinyl.year {
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            
            // Format display is now hidden - removed the format section entirely
        }
    }
    
    @ViewBuilder
    private var notesSection: some View {
        VStack(spacing: 0) {
            sectionHeader("NOTES")
            
            VStack(spacing: 0) {
                // Location Notes
                if shouldShowOwnerControls {
                    Button(action: {
                        editedLocationNote = vinyl.locationNote ?? ""
                        showingLocationEditor = true
                    }) {
                        noteEditorRow(
                            title: "LOCATION",
                            value: vinyl.locationNote,
                            placeholder: "Location notes will help you find this record in your collection"
                        )
                    }
                } else {
                    staticNoteRow(
                        title: "LOCATION",
                        value: vinyl.locationNote,
                        placeholder: "No location notes"
                    )
                }
                
                Divider()
                    .background(.white.opacity(0.2))
                    .padding(.horizontal, 16)
                
                // Grade Notes
                if shouldShowOwnerControls {
                    Button(action: {
                        editedGradeNotes = vinyl.gradeNotes ?? ""
                        showingGradeNotesEditor = true
                    }) {
                        noteEditorRow(
                            title: "GRADING",
                            value: vinyl.gradeNotes,
                            placeholder: "Add notes about the condition and grading of this record"
                        )
                    }
                } else {
                    staticNoteRow(
                        title: "GRADING",
                        value: vinyl.gradeNotes,
                        placeholder: "No grading notes"
                    )
                }
                
                Divider()
                    .background(.white.opacity(0.2))
                    .padding(.horizontal, 16)
                
                // Edition Notes
                if shouldShowOwnerControls {
                    Button(action: {
                        editedEditionNotes = vinyl.editionNotes ?? ""
                        showingEditionNotesEditor = true
                    }) {
                        noteEditorRow(
                            title: "EDITION",
                            value: vinyl.editionNotes,
                            placeholder: "Add notes about this specific edition or pressing",
                            isLast: true
                        )
                    }
                } else {
                    staticNoteRow(
                        title: "EDITION",
                        value: vinyl.editionNotes,
                        placeholder: "No edition notes",
                        isLast: true
                    )
                }
            }
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .sheet(isPresented: $showingLocationEditor) {
            if shouldShowOwnerControls {
                LocationNoteEditorView(
                    locationNote: $editedLocationNote,
                    vinylTitle: vinyl.title,
                    isUpdating: $isUpdatingLocation,
                    onSave: { newLocationNote in
                        Task {
                            await updateLocationNote(newLocationNote)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingGradeNotesEditor) {
            if shouldShowOwnerControls {
                GradeNotesEditorView(
                    gradeNotes: $editedGradeNotes,
                    vinylTitle: vinyl.title,
                    isUpdating: $isUpdatingGradeNotes,
                    onSave: { newGradeNotes in
                        Task {
                            await updateGradeNotes(newGradeNotes)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingEditionNotesEditor) {
            if shouldShowOwnerControls {
                EditionNotesEditorView(
                    editionNotes: $editedEditionNotes,
                    vinylTitle: vinyl.title,
                    isUpdating: $isUpdatingEditionNotes,
                    onSave: { newEditionNotes in
                        Task {
                            await updateEditionNotes(newEditionNotes)
                        }
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private var settingsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("SETTINGS")
            
            VStack(spacing: 0) {
                if shouldShowOwnerControls {
                    // Owner view - show crate management
                    let primaryCrateName: String = {
                        if isLoadingCrates {
                            return "Loading..."
                        } else if let firstCrate = vinylCrates.first {
                            return firstCrate.name
                        } else {
                            return "No crate assigned"
                        }
                    }()
                    
                    if isInWishlistCrate {
                        // Static row for wishlist items - no crate movement allowed
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("STORED IN")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.6))
                                Text(primaryCrateName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Text("Wishlist items")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                    } else {
                        settingsRow(title: "STORED IN", value: primaryCrateName, action: {
                            showingCrateSelection = true
                        })
                    }
                    
                    // NFC Tag Management - Only for owners
                    let isTagged = vinyl.nfcTagHash != nil && !(vinyl.nfcTagHash?.isEmpty ?? true)
                    
                    if isInWishlistCrate {
                        // Special call to action for wishlist items
                        Button(action: {
                            // TODO: Implement "add to collection" functionality
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("BOUGHT THIS ALBUM?")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                    Text("Add to Collection")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.sonexAmber)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color.white.opacity(0.1))
                    } else if isTagged {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NFC TAG")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.6))
                                Text("Tagged")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Button("Remove") {
                                // TODO: Implement tag removal
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                    } else {
                        Button(action: {
                            // TODO: Implement tag addition
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("NFC TAG")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                    Text("Not Tagged")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                Text("+ Add Tag")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color.sonexAmber)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color.white.opacity(0.1))
                    }
                } else {
                    // Non-owner view - show collection status
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("IN YOUR COLLECTION")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                            
                            if isCheckingUserCollection {
                                Text("Checking...")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                            } else {
                                Text(existsInUserCollection ? "Yes" : "No")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        Spacer()
                        
                        if !existsInUserCollection {
                            Button(action: {
                                Task {
                                    await addToWishlist()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    if isAddingToWishlist {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "plus")
                                    }
                                    Text("Wishlist")
                                }
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color.sonexAmber)
                            }
                            .disabled(isAddingToWishlist)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                }
                
                if shouldShowOwnerControls && !isInWishlistCrate {
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
                            HStack(spacing: 8) {
                                Text("$\(Int(askingPrice))")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.sonexAmber)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.sonexAmber.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                Button("Edit") {
                                    showingPricingEditor = true
                                }
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color.sonexAmber)
                            }
                        } else if vinyl.forSale {
                            Button("Set Price") {
                                showingPricingEditor = true
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.sonexAmber)
                        } else {
                            Button("List") {
                                showingPricingEditor = true
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.sonexAmber)
                        }
                        
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    
                    if !isInWishlistCrate {
                        Button(action: {
                            // Handle add artifacts
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ARTIFACTS")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                    Text("0 linked")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                Text("+ Add")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color.sonexAmber)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color.white.opacity(0.1))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .sheet(isPresented: $showingCrateSelection) {
            if shouldShowOwnerControls && !isInWishlistCrate {
                CrateSelectionView(
                    selectedVinyls: [vinyl.id],
                    currentCrateId: vinylCrates.first?.id ?? "",
                    onMove: { newCrateId in
                        Task {
                            await moveVinylToCrateById(newCrateId)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingPricingEditor) {
            if shouldShowOwnerControls && !isInWishlistCrate {
                PricingEditorView(
                    vinyl: vinyl,
                    onSave: { newPrice, forSale in
                        Task {
                            await updateVinylPricing(newPrice: newPrice, forSale: forSale)
                        }
                    },
                    onDelist: {
                        Task {
                            await delistVinyl()
                        }
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private var deleteSection: some View {
        VStack(spacing: 0) {
            sectionHeader("DANGER ZONE")
            
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isInWishlistCrate ? "REMOVE FROM WISHLIST" : "DELETE RECORD")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        Text(isInWishlistCrate ? "Remove this item from your wishlist" : "Permanently remove this record from your collection")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    if isDeletingRecord {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isInWishlistCrate ? "heart.slash" : "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(isDeletingRecord)
        }
        .confirmationDialog(isInWishlistCrate ? "Remove from Wishlist" : "Delete Record", isPresented: $showingDeleteConfirmation) {
            Button(isInWishlistCrate ? "Remove from Wishlist" : "Delete Record", role: .destructive) {
                Task {
                    await deleteRecord()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if isInWishlistCrate {
                Text("Are you sure you want to remove \"\(vinyl.title)\" by \(vinyl.artist) from your wishlist?")
            } else {
                Text("Are you sure you want to permanently delete \"\(vinyl.title)\" by \(vinyl.artist) from your collection? This action cannot be undone.")
            }
        }
    }
    
    @ViewBuilder
    private var artifactsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("ARTIFACTS")
            
            
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
                    .foregroundColor(Color.sonexAmber)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.white.opacity(0.1))
    }
    
    @ViewBuilder
    private func noteEditorRow(title: String, value: String?, placeholder: String, isLast: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                
                if let value = value, !value.isEmpty {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                } else {
                    Text(placeholder)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer()
            Text("Edit")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color.sonexAmber)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private func staticNoteRow(title: String, value: String?, placeholder: String, isLast: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                
                if let value = value, !value.isEmpty {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                } else {
                    Text(placeholder)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Helper Methods
    
    private func loadInitialData() async {
        await loadCurrentUser()
        await loadVinylOwner()
        await loadVinylCrates()
        if !isCurrentUserOwner {
            await checkIfVinylExistsInUserCollection()
        }
    }
    
    private func loadCurrentUser() async {
        do {
            let user = try await dbManager.fetchCurrentUser()
            await MainActor.run {
                self.currentUser = user
            }
        } catch {
            print("Failed to load current user: \(error)")
        }
    }
    
    private func loadVinylOwner() async {
        // Only load owner if it's not the current user
        guard let currentUser = currentUser, vinyl.ownerId != currentUser.id else { return }
        
        isLoadingOwner = true
        defer { isLoadingOwner = false }
        
        do {
            let owner = try await dbManager.fetchUserById(vinyl.ownerId)
            await MainActor.run {
                self.vinylOwner = owner
            }
        } catch {
            print("Failed to load vinyl owner: \(error)")
            // Create a placeholder owner on error
            let placeholderOwner = SonexUser(
                id: vinyl.ownerId,
                userId: vinyl.ownerId,
                username: "Unknown User",
                displayName: nil
            )
            await MainActor.run {
                self.vinylOwner = placeholderOwner
            }
        }
    }
    
    private func checkIfVinylExistsInUserCollection() async {
        isCheckingUserCollection = true
        defer { 
            Task { @MainActor in
                isCheckingUserCollection = false
            }
        }
        
        do {
            let exists = try await dbManager.checkVinylExistsInCollection(
                title: vinyl.title,
                artist: vinyl.artist
            )
            await MainActor.run {
                existsInUserCollection = exists
            }
        } catch {
            print("Failed to check user collection: \(error)")
            await MainActor.run {
                existsInUserCollection = false
            }
        }
    }
    
    private func addToWishlist() async {
        isAddingToWishlist = true
        defer {
            Task { @MainActor in
                isAddingToWishlist = false
            }
        }
        
        do {
            guard let currentUserId = currentUser?.id else {
                throw SonexDBError.notAuthenticated
            }
            
            // Create a new vinyl entry for the user's wishlist
            let wishlistEntry = try await dbManager.registerVinyl(
                title: vinyl.title,
                artist: vinyl.artist,
                discogsId: vinyl.discogsId,
                nfcTagHash: nil, // No NFC tag for wishlist items
                label: vinyl.label,
                year: vinyl.year,
                pressing: vinyl.pressing,
                format: vinyl.format,
                mediaGrade: nil, // No grading for wishlist items
                gradeNotes: nil,
                coverArtUrl: vinyl.coverArtUrl,
                forSale: false,
                askingPrice: nil,
                catalogNumber: vinyl.catalogNumber,
                matrixCode: vinyl.matrixCode,
                barcode: vinyl.barcode,
                releaseEdition: vinyl.releaseEdition,
                editionNotes: nil,
                sleeveGrade: nil,
                locationNote: nil
            )
            
            // Move to wishlist crate
            let wishlistCrateId = try await dbManager.resolveWishlistCrateId()
            let unsortedCrateId = try await dbManager.resolveUnsortedCrateId()
            try await dbManager.moveVinyl(
                entryId: wishlistEntry.id,
                fromCrate: unsortedCrateId,
                toCrate: wishlistCrateId
            )
            
            await MainActor.run {
                existsInUserCollection = true
            }
            
        } catch {
            print("Failed to add to wishlist: \(error)")
            // TODO: Show error alert to user
        }
    }
    
    @MainActor
    private func uploadCoverArt(_ image: UIImage) async {
        guard shouldShowOwnerControls else {
            print("❌ [uploadCoverArt] Non-owner attempted to upload cover art")
            return
        }
        
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
            if let existingUrl = vinyl.coverArtUrl,
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
            
            // Create a temporary VinylRegistrationData for the upload function
            var tempRegistrationData = VinylRegistrationData()
//            tempRegistrationData.id = vinyl.id
            tempRegistrationData.title = vinyl.title
            tempRegistrationData.artist = vinyl.artist
            
            let coverArtUrl = try await SonexDBManager.shared.uploadAndSetCoverArt(
                for: tempRegistrationData,
                image: image
            )
            
            print("✅ Successfully uploaded cover art: \(coverArtUrl)")
            print("🔄 [uploadCoverArt] Updating vinyl.coverArtUrl to: \(coverArtUrl)")
            
            // Update the vinyl entry in the database
            try await SonexDBManager.shared.updateVinylCoverArt(
                entryId: vinyl.id,
                coverArtUrl: coverArtUrl
            )
            
            // Force UI update by explicitly setting the cover art URL and refreshing AsyncImage
            await MainActor.run {
                print("🎯 [uploadCoverArt] MainActor: Updating vinyl coverArtUrl")
                // Create updated vinyl entry
                vinyl = VinylEntry(
                    id: vinyl.id,
                    ownerId: vinyl.ownerId,
                    discogsId: vinyl.discogsId,
                    nfcTagHash: vinyl.nfcTagHash,
                    title: vinyl.title,
                    artist: vinyl.artist,
                    label: vinyl.label,
                    year: vinyl.year,
                    pressing: vinyl.pressing,
                    format: vinyl.format,
                    mediaGrade: vinyl.mediaGrade,
                    gradeNotes: vinyl.gradeNotes,
                    coverArtUrl: coverArtUrl,
                    forSale: vinyl.forSale,
                    askingPrice: vinyl.askingPrice,
                    createdAt: vinyl.createdAt,
                    catalogNumber: vinyl.catalogNumber,
                    matrixCode: vinyl.matrixCode,
                    barcode: vinyl.barcode,
                    releaseEdition: vinyl.releaseEdition,
                    editionNotes: vinyl.editionNotes,
                    sleeveGrade: vinyl.sleeveGrade,
                    locationNote: vinyl.locationNote
                )
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
    
    private func loadVinylCrates() async {
        guard shouldShowOwnerControls else { return }
        
        isLoadingCrates = true
        
        do {
            let crates = try await dbManager.fetchCratesForVinyl(vinylId: vinyl.id)
            await MainActor.run {
                self.vinylCrates = crates
            }
        } catch {
            print("Failed to load vinyl crates: \(error)")
            // On error, fallback to showing default or empty state
            await MainActor.run {
                self.vinylCrates = []
            }
        }
        
        isLoadingCrates = false
    }
    
    private func updateLocationNote(_ newLocationNote: String) async {
        guard shouldShowOwnerControls else { return }
        
        isUpdatingLocation = true
        
        do {
            let noteToSave = newLocationNote.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalNote = noteToSave.isEmpty ? nil : noteToSave
            
            try await dbManager.updateVinylLocationNote(
                entryId: vinyl.id,
                locationNote: finalNote
            )
            
            // Update the local vinyl object to reflect the change
            vinyl = VinylEntry(
                id: vinyl.id,
                ownerId: vinyl.ownerId,
                discogsId: vinyl.discogsId,
                nfcTagHash: vinyl.nfcTagHash,
                title: vinyl.title,
                artist: vinyl.artist,
                label: vinyl.label,
                year: vinyl.year,
                pressing: vinyl.pressing,
                format: vinyl.format,
                mediaGrade: vinyl.mediaGrade,
                gradeNotes: vinyl.gradeNotes,
                coverArtUrl: vinyl.coverArtUrl,
                forSale: vinyl.forSale,
                askingPrice: vinyl.askingPrice,
                createdAt: vinyl.createdAt,
                catalogNumber: vinyl.catalogNumber,
                matrixCode: vinyl.matrixCode,
                barcode: vinyl.barcode,
                releaseEdition: vinyl.releaseEdition,
                editionNotes: vinyl.editionNotes,
                sleeveGrade: vinyl.sleeveGrade,
                locationNote: finalNote
            )
            
            showingLocationEditor = false
        } catch {
            print("Failed to update location note: \(error)")
            // Handle error - could show an alert or toast
        }
        
        isUpdatingLocation = false
    }
    
    private func updateGradeNotes(_ newGradeNotes: String) async {
        guard shouldShowOwnerControls else { return }
        
        isUpdatingGradeNotes = true
        
        // TODO: Implement updateVinylGradeNotes in SonexDBManager
        // For now, just update the local object
        do {
            let notesToSave = newGradeNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalNotes = notesToSave.isEmpty ? nil : notesToSave
            
            // TODO: Replace with actual database update
            // try await dbManager.updateVinylGradeNotes(
            //     entryId: vinyl.id,
            //     gradeNotes: finalNotes
            // )
            
            // Update the local vinyl object
            vinyl = VinylEntry(
                id: vinyl.id,
                ownerId: vinyl.ownerId,
                discogsId: vinyl.discogsId,
                nfcTagHash: vinyl.nfcTagHash,
                title: vinyl.title,
                artist: vinyl.artist,
                label: vinyl.label,
                year: vinyl.year,
                pressing: vinyl.pressing,
                format: vinyl.format,
                mediaGrade: vinyl.mediaGrade,
                gradeNotes: finalNotes,
                coverArtUrl: vinyl.coverArtUrl,
                forSale: vinyl.forSale,
                askingPrice: vinyl.askingPrice,
                createdAt: vinyl.createdAt,
                catalogNumber: vinyl.catalogNumber,
                matrixCode: vinyl.matrixCode,
                barcode: vinyl.barcode,
                releaseEdition: vinyl.releaseEdition,
                editionNotes: vinyl.editionNotes,
                sleeveGrade: vinyl.sleeveGrade,
                locationNote: vinyl.locationNote
            )
            
            showingGradeNotesEditor = false
        } catch {
            print("Failed to update grade notes: \(error)")
        }
        
        isUpdatingGradeNotes = false
    }
    
    private func updateEditionNotes(_ newEditionNotes: String) async {
        guard shouldShowOwnerControls else { return }
        
        isUpdatingEditionNotes = true
        
        // TODO: Implement updateVinylEditionNotes in SonexDBManager
        // For now, just update the local object
        do {
            let notesToSave = newEditionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalNotes = notesToSave.isEmpty ? nil : notesToSave
            
            // TODO: Replace with actual database update
            // try await dbManager.updateVinylEditionNotes(
            //     entryId: vinyl.id,
            //     editionNotes: finalNotes
            // )
            
            // Update the local vinyl object
            vinyl = VinylEntry(
                id: vinyl.id,
                ownerId: vinyl.ownerId,
                discogsId: vinyl.discogsId,
                nfcTagHash: vinyl.nfcTagHash,
                title: vinyl.title,
                artist: vinyl.artist,
                label: vinyl.label,
                year: vinyl.year,
                pressing: vinyl.pressing,
                format: vinyl.format,
                mediaGrade: vinyl.mediaGrade,
                gradeNotes: vinyl.gradeNotes,
                coverArtUrl: vinyl.coverArtUrl,
                forSale: vinyl.forSale,
                askingPrice: vinyl.askingPrice,
                createdAt: vinyl.createdAt,
                catalogNumber: vinyl.catalogNumber,
                matrixCode: vinyl.matrixCode,
                barcode: vinyl.barcode,
                releaseEdition: vinyl.releaseEdition,
                editionNotes: finalNotes,
                sleeveGrade: vinyl.sleeveGrade,
                locationNote: vinyl.locationNote
            )
            
            showingEditionNotesEditor = false
        } catch {
            print("Failed to update edition notes: \(error)")
        }
        
        isUpdatingEditionNotes = false
    }
    
    private func moveVinylToCrateById(_ newCrateId: String) async {
        guard shouldShowOwnerControls else { return }
        guard !isInWishlistCrate else {
            print("Cannot move vinyl from wishlist crate")
            return
        }
        
        do {
            // Get the current crate ID (first crate that's not "For Sale")
            let currentCrateId = vinylCrates.first?.id ?? ""
            
            if !currentCrateId.isEmpty {
                try await dbManager.moveVinyl(
                    entryId: vinyl.id, 
                    fromCrate: currentCrateId, 
                    toCrate: newCrateId
                )
                await loadVinylCrates() // Refresh the crates
            }
            showingCrateSelection = false
        } catch {
            print("Failed to move vinyl to crate: \(error)")
        }
    }
    
    private func updateVinylPricing(newPrice: Double?, forSale: Bool) async {
        guard shouldShowOwnerControls else { return }
        
        do {
            try await dbManager.updateVinylSaleStatus(
                entryId: vinyl.id,
                forSale: forSale,
                askingPrice: newPrice
            )
            
            // Update local vinyl object
            vinyl = VinylEntry(
                id: vinyl.id,
                ownerId: vinyl.ownerId,
                discogsId: vinyl.discogsId,
                nfcTagHash: vinyl.nfcTagHash,
                title: vinyl.title,
                artist: vinyl.artist,
                label: vinyl.label,
                year: vinyl.year,
                pressing: vinyl.pressing,
                format: vinyl.format,
                mediaGrade: vinyl.mediaGrade,
                gradeNotes: vinyl.gradeNotes,
                coverArtUrl: vinyl.coverArtUrl,
                forSale: forSale,
                askingPrice: newPrice,
                createdAt: vinyl.createdAt,
                catalogNumber: vinyl.catalogNumber,
                matrixCode: vinyl.matrixCode,
                barcode: vinyl.barcode,
                releaseEdition: vinyl.releaseEdition,
                editionNotes: vinyl.editionNotes,
                sleeveGrade: vinyl.sleeveGrade,
                locationNote: vinyl.locationNote
            )
            
            await loadVinylCrates() // Refresh crates to update For Sale crate membership
            showingPricingEditor = false
        } catch {
            print("Failed to update vinyl pricing: \(error)")
        }
    }
    
    private func delistVinyl() async {
        guard shouldShowOwnerControls else { return }
        
        do {
            try await dbManager.updateVinylSaleStatus(
                entryId: vinyl.id,
                forSale: false,
                askingPrice: nil
            )
            
            // Update local vinyl object
            vinyl = VinylEntry(
                id: vinyl.id,
                ownerId: vinyl.ownerId,
                discogsId: vinyl.discogsId,
                nfcTagHash: vinyl.nfcTagHash,
                title: vinyl.title,
                artist: vinyl.artist,
                label: vinyl.label,
                year: vinyl.year,
                pressing: vinyl.pressing,
                format: vinyl.format,
                mediaGrade: vinyl.mediaGrade,
                gradeNotes: vinyl.gradeNotes,
                coverArtUrl: vinyl.coverArtUrl,
                forSale: false,
                askingPrice: nil,
                createdAt: vinyl.createdAt,
                catalogNumber: vinyl.catalogNumber,
                matrixCode: vinyl.matrixCode,
                barcode: vinyl.barcode,
                releaseEdition: vinyl.releaseEdition,
                editionNotes: vinyl.editionNotes,
                sleeveGrade: vinyl.sleeveGrade,
                locationNote: vinyl.locationNote
            )
            
            await loadVinylCrates() // Refresh crates to remove from For Sale crate
            showingPricingEditor = false
        } catch {
            print("Failed to delist vinyl: \(error)")
        }
    }
    
    private func deleteRecord() async {
        guard shouldShowOwnerControls else { return }
        
        let actionDescription = isInWishlistCrate ? "removal from wishlist" : "deletion"
        print("🗑️ [deleteRecord] Starting \(actionDescription) of vinyl record: \(vinyl.title)")
        
        isDeletingRecord = true
        defer {
            Task { @MainActor in
                isDeletingRecord = false
            }
        }
        
        do {
            // Delete the vinyl record from the database
            // This works the same for both regular records and wishlist items
            try await dbManager.deleteVinyl(entryId: vinyl.id)
            
            print("✅ [deleteRecord] Successfully completed \(actionDescription) of vinyl record")
            
            // Dismiss the view after successful deletion
            await MainActor.run {
                dismiss()
            }
            
        } catch {
            print("❌ [deleteRecord] Failed \(actionDescription) of vinyl record: \(error)")
            
            // You could show an error alert here if needed
            // For now, just log the error
            await MainActor.run {
                // Handle error - could show alert to user
                let errorAction = isInWishlistCrate ? "remove from wishlist" : "delete record"
                print("Failed to \(errorAction): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Location Note Editor

struct LocationNoteEditorView: View {
    @Binding var locationNote: String
    let vinylTitle: String
    @Binding var isUpdating: Bool
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location Note")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text("Add notes to help you find \"\(vinylTitle)\" in your collection")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    TextField("e.g., Bedroom shelf, top row, third from left", text: $locationNote, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .lineLimit(3...6)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Edit Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .disabled(isUpdating)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(locationNote)
                    }
                    .foregroundStyle(Color.sonexAmber)
                    .disabled(isUpdating)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
}

// MARK: - Grade Notes Editor

struct GradeNotesEditorView: View {
    @Binding var gradeNotes: String
    let vinylTitle: String
    @Binding var isUpdating: Bool
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Grade Notes")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text("Add notes about the condition and grading of \"\(vinylTitle)\"")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    TextField("e.g., Minor scuffs on side A, excellent overall condition", text: $gradeNotes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .lineLimit(3...6)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Edit Grade Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .disabled(isUpdating)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(gradeNotes)
                    }
                    .foregroundStyle(Color.sonexAmber)
                    .disabled(isUpdating)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
}

// MARK: - Edition Notes Editor

struct EditionNotesEditorView: View {
    @Binding var editionNotes: String
    let vinylTitle: String
    @Binding var isUpdating: Bool
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Edition Notes")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text("Add notes about this specific edition or pressing of \"\(vinylTitle)\"")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    TextField("e.g., Limited edition colored vinyl, includes bonus tracks", text: $editionNotes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .lineLimit(3...6)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Edit Edition Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .disabled(isUpdating)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(editionNotes)
                    }
                    .foregroundStyle(Color.sonexAmber)
                    .disabled(isUpdating)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
}

// MARK: - Placeholder Views (To be implemented)

struct PricingEditorView: View {
    let vinyl: VinylEntry
    let onSave: (Double?, Bool) -> Void
    let onDelist: () -> Void
    
    @State private var priceText: String = ""
    @State private var forSale: Bool = false
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isPriceFieldFocused: Bool
    
    private var isValidPrice: Bool {
        guard !priceText.isEmpty else { return false }
        return Double(priceText) != nil && Double(priceText)! > 0
    }
    
    private var currentPrice: Double? {
        Double(priceText)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Listing Settings")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text("Set the asking price for \"\(vinyl.title)\" or remove it from sale")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    // List for sale toggle
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("LIST FOR SALE")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.6))
                                Text(forSale ? "Listed" : "Not Listed")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $forSale)
                                .tint(Color.sonexAmber)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Price input section
                    if forSale {
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ASKING PRICE")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.6))
                                
                                HStack(spacing: 8) {
                                    Text("$")
                                        .font(.title2)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                    
                                    TextField("0.00", text: $priceText)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                        .focused($isPriceFieldFocused)
                                        .font(.title2)
                                        .fontWeight(.medium)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            if !priceText.isEmpty && !isValidPrice {
                                Text("Please enter a valid price greater than $0")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Edit Pricing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let price = forSale ? currentPrice : nil
                        onSave(price, forSale)
                        dismiss()
                    }
                    .foregroundStyle(Color.sonexAmber)
                    .disabled(forSale && !isValidPrice)
                }
            }
            .onAppear {
                // Initialize with current values
                forSale = vinyl.forSale
                if let askingPrice = vinyl.askingPrice {
                    priceText = String(format: "%.0f", askingPrice)
                }
                
                // Focus price field if listing for sale
                if forSale {
                    isPriceFieldFocused = true
                }
            }
            .confirmationDialog("Remove from Sale", isPresented: $showingDeleteConfirmation) {
                Button("Remove from Sale", role: .destructive) {
                    onDelist()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to remove \"\(vinyl.title)\" from sale?")
            }
        }
    }
}
