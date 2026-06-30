//
//  SingleCrateView.swift
//  Sonex
//
//  Created by Assistant on 4/15/26.
//

import SwiftUI
import SonexShared

// MARK: - Constants

private enum CrateStack {
    /// How many cards are visible in the back-stack peek
    static let visibleBackCount = 3
    /// The base card dimensions (front card)
    static let cardSize: CGFloat = 260
    /// Vertical offset step between stacked cards (peeking upward)
    static let peekOffset: CGFloat = 18
    /// Horizontal rotation tilt step (alternating sides for organic feel)
    static let tiltStep: Double = 3.5
    /// Scale step per depth level
    static let scaleStep: CGFloat = 0.06
    /// Corner radius of each card
    static let cornerRadius: CGFloat = 14
}

// MARK: - View modes

private enum ViewMode {
    case stack         // Default card stack view
    case grid          // Grid selection mode
}

// MARK: - Animation phases

private enum FlipPhase {
    case idle          // Nothing happening
    case animating     // Card is animating to the back
}

// MARK: - View

struct SingleCrateView: View {
    let crate: CrateWithCount

    // MARK: State

    @State private var vinylEntries: [VinylEntry] = []
    @State private var isLoading = true
    @State private var isLoadingImages = false
    @State private var preloadedImages: [String: UIImage] = [:]

    @State private var flipPhase: FlipPhase = .idle
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var animatingCardOffset: CGFloat = 0
    @State private var animatingCardScale: CGFloat = 1.0
    @State private var animatingCardRotation: Double = 0.0

    @State private var showingAlbumDetails = false
    @State private var selectedVinyl: VinylEntry?

    // Selection mode state
    @State private var viewMode: ViewMode = .stack
    @State private var selectedVinyls: Set<String> = []
    @State private var showingCrateSelection = false
    @State private var showingSettings = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteError: String?
    @State private var showingDeleteError = false

    @State private var dbManager = SonexDBManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(TabRouter.self) private var tabRouter

    // Drag threshold to trigger a flip
    private let dragThreshold: CGFloat = 80
    
    // Protected crates that cannot be deleted
    private var isProtectedCrate: Bool {
        ["Unsorted", "For Sale", "Wishlist"].contains(crate.name)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()

                contentView
            }
            .navigationTitle(crate.name)
            .navigationBarTitleDisplayMode(viewMode == .grid ? .inline : .large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarContent
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewMode == .grid && !selectedVinyls.isEmpty {
                    Button("Move \(selectedVinyls.count) record\(selectedVinyls.count == 1 ? "" : "s")") {
                        showingCrateSelection = true
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.sonexAmber)
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .background(.black.opacity(0.8))
                }
            }
        }
        .onAppear {
            tabRouter.hideDock()
        }
        .onDisappear {
            tabRouter.showDock()
        }
        .task { await loadVinylEntries() }
        .sheet(isPresented: $showingAlbumDetails) {
            if let vinyl = selectedVinyl {
                AlbumDetailsView(vinyl: vinyl)
            }
        }
        .sheet(isPresented: $showingCrateSelection) {
            CrateSelectionView(
                selectedVinyls: Array(selectedVinyls),
                currentCrateId: crate.id,
                onMove: { toCrateId in
                    Task {
                        await moveSelectedVinyls(to: toCrateId)
                    }
                }
            )
        }
        .confirmationDialog("Crate Settings", isPresented: $showingSettings) {
            Button("Delete Crate", role: .destructive) {
                showingDeleteConfirmation = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose an action for this crate.")
        }
        .alert("Delete Crate", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deleteCrate()
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(crate.name)\"? All records will be moved to your Unsorted crate.")
        }
        .alert("Delete Error", isPresented: $showingDeleteError) {
            Button("OK") {}
        } message: {
            Text(deleteError ?? "An unknown error occurred while deleting the crate.")
        }
    }

    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading || isLoadingImages {
            loadingView
        } else if vinylEntries.isEmpty {
            emptyStateView
        } else {
            mainContent
        }
    }
    
    @ViewBuilder
    private var toolbarContent: some View {
        HStack(spacing: 12) {
            if viewMode == .stack && !isProtectedCrate {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white)
                }
            }
            
            if shouldShowSelectButton {
                Button(viewMode == .stack ? "Select" : "Cancel") {
                    toggleViewMode()
                }
                .foregroundStyle(.white)
            }
        }
    }
    
    private var shouldShowSelectButton: Bool {
        crate.name != "For Sale" && crate.name != "Wishlist"
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        Group {
            switch viewMode {
            case .stack:
                stackView
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            case .grid:
                gridView
                    .transition(.opacity.combined(with: .scale(scale: 1.1)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewMode)
    }
    
    // MARK: - Stack view (original)
    
    @ViewBuilder
    private var stackView: some View {
        VStack(spacing: 32) {
            Spacer()

            // ── Crate stack ──────────────────────────────────────────────────
            ZStack {
                // Back cards (index 1…N), rendered back-to-front
                ForEach(backIndices, id: \.self) { depth in
                    backCard(depth: depth)
                }

                // Front card
                frontCard
            }
            // Reserve enough height for the tallest peek offset
            .frame(
                width: CrateStack.cardSize + 60,
                height: CrateStack.cardSize + CGFloat(CrateStack.visibleBackCount) * CrateStack.peekOffset + 60
            )

            // ── Album info ───────────────────────────────────────────────────
            if let front = vinylEntries.first {
                albumInfoView(for: front)
                    .opacity(flipPhase == .idle ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.2), value: flipPhase)
            }

            // ── Swipe hint ───────────────────────────────────────────────────
            Label("Swipe down to flip", systemImage: "hand.draw")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))

            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Grid view (selection mode)
    
    @ViewBuilder
    private var gridView: some View {
        VStack(spacing: 0) {
            // Selection info header
            if !selectedVinyls.isEmpty {
                HStack {
                    Text("\(selectedVinyls.count) selected")
                        .font(.subheadline)
                        .foregroundStyle(Color.sonexAmber)
                    
                    Spacer()
                    
                    Button("Select All") {
                        selectAllVinyls()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .opacity(selectedVinyls.count == vinylEntries.count ? 0 : 1)
                    
                    Button("Clear") {
                        clearAllSelections()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.leading, 16)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(.black.opacity(0.2))
            }
            
            // Grid content
            if vinylEntries.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No records to select")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(vinylEntries, id: \.id) { vinyl in
                            gridCard(for: vinyl)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 480) // Extra padding for bottom button
                }
            }
        }
        .onAppear(){
            tabRouter.hideDock()
        }
        .onDisappear {
            tabRouter.showDock()
        }
    }
    
    private func selectAllVinyls() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedVinyls = Set(vinylEntries.map(\.id))
        }
    }
    
    private func clearAllSelections() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedVinyls.removeAll()
        }
    }
    
    @ViewBuilder
    private func gridCard(for vinyl: VinylEntry) -> some View {
        ZStack {
            // Card background
            if let url = vinyl.coverArtUrl, let img = preloadedImages[url] {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
            } else {
                placeholderFace
                    .aspectRatio(1, contentMode: .fit)
            }
            
            // Selection overlay
            if selectedVinyls.contains(vinyl.id) {
                Rectangle()
                    .fill(.black.opacity(0.4))
                
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.sonexAmber)
                            .frame(width: 28, height: 28)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                    }
                    .padding(12)
                    Spacer()
                }
            } else {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                            .frame(width: 28, height: 28)
                    }
                    .padding(12)
                    Spacer()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CrateStack.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: CrateStack.cornerRadius)
                .strokeBorder(
                    selectedVinyls.contains(vinyl.id) ? Color.sonexAmber.opacity(0.6) : .white.opacity(0.08),
                    lineWidth: selectedVinyls.contains(vinyl.id) ? 2 : 1
                )
        )
        .onTapGesture {
            toggleSelection(for: vinyl.id)
        }
        .scaleEffect(selectedVinyls.contains(vinyl.id) ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedVinyls.contains(vinyl.id))
    }

    // MARK: - Back cards

    /// Indices into vinylEntries for the peeking back cards (1, 2, 3 …)
    private var backIndices: [Int] {
        let count = vinylEntries.count - 1
        return count > 0 ? Array(1...count).reversed() : []
    }

    @ViewBuilder
    private func backCard(depth: Int) -> some View {
        let scale = 1.0 - CGFloat(depth) * CrateStack.scaleStep
        // Alternate tilt: odd depths lean right, even left
//        let tiltDeg = (depth % 2 == 0 ? 1.0 : -1.0) * Double(depth) * CrateStack.tiltStep
        let tiltDeg = 0.0
        let yOff = -CGFloat(depth) * CrateStack.peekOffset

        cardFace(vinyl: vinylEntries[depth], isInteractive: false)
            .frame(width: CrateStack.cardSize, height: CrateStack.cardSize)
            .scaleEffect(scale)
            .rotationEffect(.degrees(tiltDeg))
            .offset(y: yOff)
            .zIndex(Double(-depth))
    }

    // MARK: - Front card

    @ViewBuilder
    private var frontCard: some View {
        guard let front = vinylEntries.first else { return AnyView(EmptyView()).asAnyView() }

        let scaleValue: CGFloat = {
            switch flipPhase {
            case .animating:  return animatingCardScale
            default:          return isDragging ? (1.0 - dragOffset / 600) : 1.0
            }
        }()

        let yOffset: CGFloat = {
            switch flipPhase {
            case .animating:  return animatingCardOffset
            default:          return isDragging ? dragOffset : 0
            }
        }()

        let rotation: Double = {
            switch flipPhase {
            case .animating:  return animatingCardRotation
            default:          return 0
            }
        }()

        return AnyView(
            cardFace(vinyl: front, isInteractive: flipPhase == .idle)
                .frame(width: CrateStack.cardSize, height: CrateStack.cardSize)
                .scaleEffect(scaleValue)
                .rotationEffect(.degrees(rotation))
                .offset(y: yOffset)
                .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 10)
                .zIndex(flipPhase == .animating ? 5 : 10) // Lower z-index when animating to back
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: scaleValue)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: yOffset)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: rotation)
                // ── Drag gesture ──────────────────────────────────────────
                .gesture(
                    DragGesture()
                        .onChanged { val in
                            guard flipPhase == .idle else { return }
                            let dy = val.translation.height
                            if dy > 0 {
                                isDragging = true
                                dragOffset = dy
                            }
                        }
                        .onEnded { val in
                            guard flipPhase == .idle else { return }
                            if val.translation.height > dragThreshold {
                                triggerFlip()
                            } else {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                    isDragging = false
                                }
                            }
                        }
                )
                // ── Tap to view details ───────────────────────────────────
                .onTapGesture {
                    guard flipPhase == .idle else { return }
                    selectedVinyl = front
                    showingAlbumDetails = true
                }
        )
    }

    // MARK: - Card face

    @ViewBuilder
    private func cardFace(vinyl: VinylEntry, isInteractive: Bool) -> some View {
        ZStack {
            if let url = vinyl.coverArtUrl, let img = preloadedImages[url] {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                placeholderFace
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CrateStack.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: CrateStack.cornerRadius)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var placeholderFace: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(.white.opacity(0.4))
            }
    }

    // MARK: - Album info

    @ViewBuilder
    private func albumInfoView(for vinyl: VinylEntry) -> some View {
        VStack(spacing: 6) {
            Text(vinyl.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(vinyl.artist)
                .font(.subheadline)
                .foregroundStyle(Color.sonexAmber)

            if let year = vinyl.year {
                Text(String(year))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Loading / empty

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.sonexAmber))
                .scaleEffect(1.5)
            Text(isLoadingImages ? "Loading album covers…" : "Loading records…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "music.note.house")
                .font(.system(size: 60))
                .foregroundStyle(Color.sonexAmber)
            VStack(spacing: 8) {
                Text("No Records Found")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("This crate doesn't contain any records yet.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    // MARK: - View mode management
    
    private func toggleViewMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if viewMode == .stack {
                viewMode = .grid
            } else {
                viewMode = .stack
                selectedVinyls.removeAll()
            }
        }
    }
    
    private func toggleSelection(for vinylId: String) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedVinyls.contains(vinylId) {
                selectedVinyls.remove(vinylId)
            } else {
                selectedVinyls.insert(vinylId)
            }
        }
    }
    
    // MARK: - Vinyl moving
    
    private func moveSelectedVinyls(to crateId: String) async {
        let vinylsToMove = Array(selectedVinyls)
        
        do {
            // Use the new bulk move function
            try await dbManager.moveVinyls(
                entryIds: vinylsToMove,
                fromCrate: crate.id,
                toCrate: crateId
            )
            
            // Success: reset selection and reload
            await MainActor.run {
                selectedVinyls.removeAll()
                viewMode = .stack
                showingCrateSelection = false
            }
            
            // Reload vinyl entries to reflect the changes
            await loadVinylEntries()
            
        } catch {
            print("Failed to move vinyls: \(error)")
            
            // Reset UI state even on error
            await MainActor.run {
                selectedVinyls.removeAll()
                viewMode = .stack
                showingCrateSelection = false
            }
        }
    }
    
    // MARK: - Crate deletion
    
    private func deleteCrate() async {
        do {
            // First, get all vinyl entries in this crate
            let allVinyls = vinylEntries.map(\.id)
            
            // If there are vinyls in this crate, move them to Unsorted
            if !allVinyls.isEmpty {
                let unsortedCrateId = try await dbManager.resolveUnsortedCrateId()
                try await dbManager.moveVinyls(
                    entryIds: allVinyls,
                    fromCrate: crate.id,
                    toCrate: unsortedCrateId
                )
            }
            
            // Then delete the crate itself
            try await dbManager.deleteCrate(crateId: crate.id)
            
            // Dismiss the view since the crate no longer exists
            await MainActor.run {
                dismiss()
            }
            
        } catch {
            print("Failed to delete crate: \(error)")
            await MainActor.run {
                deleteError = error.localizedDescription
                showingDeleteError = true
            }
        }
    }

    // MARK: - Flip animation sequence

    /// Quick flip animation that moves the front card to the back position
    /// while the new front card naturally slides up from behind
    private func triggerFlip() {
        guard vinylEntries.count > 1, flipPhase == .idle else { return }

        // Start the animation phase
        flipPhase = .animating
        
        // Reset drag state
        dragOffset = 0
        isDragging = false
        
        // Calculate the target position for the front card to move to the back
        let backDepth = min(vinylEntries.count - 1, CrateStack.visibleBackCount)
        let targetScale = 1.0 - CGFloat(backDepth) * CrateStack.scaleStep
        let targetOffset = -CGFloat(backDepth) * CrateStack.peekOffset
        let targetRotation = Double(backDepth) * CrateStack.tiltStep * (backDepth % 2 == 0 ? 1.0 : -1.0)
        
        // Quick animation to the back position
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            animatingCardScale = targetScale
            animatingCardOffset = targetOffset
            animatingCardRotation = targetRotation
        }
        
        // After animation completes, update the data model and reset animation state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            // Move front album to back (no animation on data mutation itself)
            let front = vinylEntries.removeFirst()
            vinylEntries.append(front)
            
            // Reset animation state
            animatingCardScale = 1.0
            animatingCardOffset = 0
            animatingCardRotation = 0
            flipPhase = .idle
        }
    }

    // MARK: - Data loading

    private func loadVinylEntries() async {
        do {
            let entries = try await dbManager.fetchVinylEntries(inCrate: crate.id)
            await MainActor.run {
                self.vinylEntries = entries
                self.isLoading = false
            }
            await preloadImages()
        } catch {
            print("Failed to load vinyl entries for crate: \(error)")
            await MainActor.run {
                self.vinylEntries = []
                self.isLoading = false
            }
        }
    }

    private func preloadImages() async {
        guard !vinylEntries.isEmpty else { return }
        await MainActor.run { isLoadingImages = true }

        await withTaskGroup(of: (String, UIImage?).self) { group in
            for vinyl in vinylEntries {
                if let url = vinyl.coverArtUrl {
                    group.addTask {
                        let img = await downloadImage(from: url)
                        return (url, img)
                    }
                }
            }
            var loaded: [String: UIImage] = [:]
            for await (url, img) in group {
                if let img { loaded[url] = img }
            }
            await MainActor.run {
                self.preloadedImages = loaded
                self.isLoadingImages = false
            }
        }
    }

    private func downloadImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("Image download failed (\(urlString)): \(error)")
            return nil
        }
    }
}

// MARK: - AnyView helper (avoids erasing return type warnings)

private extension View {
    func asAnyView() -> AnyView { AnyView(self) }
}
