//
//  ProfileTabView.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

// ProfileTabView.swift
import SwiftUI
import SonexShared

struct ProfileTabView: View {
    private let dbManager = SonexDBManager.shared
    @State private var showingSignOutAlert = false
    @State private var userProfile: SonexUser?
    @State private var userStats: UserStats?
    @State private var isLoadingProfile = false
    @State private var isLoadingStats = false
    @State private var showProfileCreation = false
    @State private var showingEditProfile = false
    @State private var showingSettingsMenu = false
    @State private var showingDeleteAccountAlert = false
    
    // Stat overlays
    @State private var showingCratesOverlay = false
    @State private var showingFollowingOverlay = false
    @State private var showingFollowersOverlay = false
    @State private var showingExchangesOverlay = false
    
    // Discover posts state
    @State private var userDiscoverPosts: [DiscoverPost] = []
    @State private var userRSVPPosts: [DiscoverPostWithRSVP] = []
    @State private var isLoadingDiscoverPosts = false
    @State private var isLoadingRSVPPosts = false
    @State private var showingEditPost = false
    @State private var postToEdit: DiscoverPost?
    @State private var showingDeletePostAlert = false
    @State private var postToDelete: DiscoverPost?
    
    var body: some View {
        ZStack {
            Color.sonexCharcoal.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // User Info Section
                    VStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.sonexAmber)
                    
                    if isLoadingProfile {
                        ProgressView()
                            .tint(Color.sonexAmber)
                        Text("Loading profile...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    } else if let userProfile = userProfile {
                        // User has a profile
                        Text(userProfile.displayName ?? userProfile.username)
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text("@\(userProfile.username)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        if let userEmail = dbManager.userEmail {
                            Text(userEmail)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        // Bio section
                        if let bio = userProfile.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        
                        // User Stats
                        if isLoadingStats {
                            ProgressView()
                                .tint(Color.sonexAmber)
                            Text("Loading stats...")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        } else if let stats = userStats {
                            UserStatsView(stats: stats, onStatTap: { statType in
                                handleStatTap(statType)
                            }, onFollowingTap: {
                                showingFollowingOverlay = true
                            }, onFollowersTap: {
                                showingFollowersOverlay = true
                            })
                            .padding(.top, 8)
                        } else {
                            // Placeholder stats view
                            UserStatsView(stats: UserStats(), onStatTap: { statType in
                                handleStatTap(statType)
                            }, onFollowingTap: {
                                showingFollowingOverlay = true
                            }, onFollowersTap: {
                                showingFollowersOverlay = true
                            })
                            .padding(.top, 8)
                        }
                    } else {
                        // User is authenticated but has no profile
                        if let userEmail = dbManager.userEmail {
                            Text(userEmail)
                                .font(.headline)
                                .foregroundStyle(.white)
                        } else {
                            Text("Profile")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        
                        if let userID = dbManager.userID {
                            Text("User ID: \(userID.prefix(8))...")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        Text("Complete your profile setup to get started")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Discover Posts Sections
                VStack(spacing: 24) {
                    // User's Created Posts Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("My Discover Posts")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            if isLoadingDiscoverPosts {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(Color.sonexAmber)
                            }
                        }
                        
                        if userDiscoverPosts.isEmpty && !isLoadingDiscoverPosts {
                            VStack(spacing: 8) {
                                Image(systemName: "location.circle")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.opacity(0.4))
                                
                                Text("No discover posts yet")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(Color.sonexSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(userDiscoverPosts.prefix(10)) { post in
                                        DiscoverPostPreviewCard(
                                            post: post,
                                            showMenu: true,
                                            onEdit: {
                                                postToEdit = post
                                                showingEditPost = true
                                            },
                                            onDelete: {
                                                postToDelete = post
                                                showingDeletePostAlert = true
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // User's RSVP Posts Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("My RSVPs")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            if isLoadingRSVPPosts {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(Color.sonexAmber)
                            }
                        }
                        
                        if userRSVPPosts.isEmpty && !isLoadingRSVPPosts {
                            VStack(spacing: 8) {
                                Image(systemName: "calendar.circle")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.opacity(0.4))
                                
                                Text("No RSVPs yet")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(Color.sonexSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(userRSVPPosts.prefix(10)) { rsvpPost in
                                        DiscoverPostRSVPCard(
                                            postWithRSVP: rsvpPost,
                                            onRemoveRSVP: {
                                                Task {
                                                    try? await dbManager.removeRSVP(for: rsvpPost.post.id)
                                                    await loadUserRSVPPosts()
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                // Setup Profile Button (only shown when user has no profile)
                if userProfile == nil && !isLoadingProfile {
                    Button {
                        showProfileCreation = true
                    } label: {
                        Text("Setup Profile")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.sonexAmber)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 32)
                }
                }
                .padding(.bottom, 100) // Add bottom padding for safe area
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Debug Button - only show in development
                    #if DEBUG
                    NavigationLink(destination: SocialDebugView()) {
                        Image(systemName: "ladybug")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.red)
                    }
                    #endif
                    
                    // Edit Profile Button
                    if userProfile != nil {
                        Button {
                            showingEditProfile = true
                        } label: {
                            Text("Edit")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.sonexAmber)
                        }
                    }
                    
                    // Settings Menu Button
                    Button {
                        showingSettingsMenu = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.sonexAmber)
                    }
                }
            }
        }
        .sheet(isPresented: $showProfileCreation) {
            ProfileCreationView {
                showProfileCreation = false
                // Refresh profile after creation
                Task {
                    await checkUserProfile()
                }
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            if let userProfile = userProfile {
                EditProfileView(userProfile: userProfile) {
                    showingEditProfile = false
                    // Refresh profile after editing
                    Task {
                        await checkUserProfile()
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettingsMenu) {
            SettingsMenuView(
                onSignOut: {
                    showingSettingsMenu = false
                    showingSignOutAlert = true
                },
                onDeleteAccount: {
                    showingSettingsMenu = false
                    showingDeleteAccountAlert = true
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await dbManager.signOutFromApp()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Account", role: .destructive) {
                Task {
                    // Add delete account functionality here
                    print("Delete account functionality to be implemented")
                }
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .sheet(isPresented: $showingCratesOverlay) {
            CratesOverlayView()
        }
        .sheet(isPresented: $showingFollowingOverlay) {
            FollowingOverlayView()
        }
        .sheet(isPresented: $showingFollowersOverlay) {
            FollowersOverlayView()
        }
        .sheet(isPresented: $showingExchangesOverlay) {
            ExchangesOverlayView()
        }
        .sheet(isPresented: $showingEditPost) {
            if let postToEdit = postToEdit {
                EditDiscoverPostView(post: postToEdit) {
                    showingEditPost = false
                    self.postToEdit = nil
                    // Refresh posts after editing
                    Task {
                        await loadUserDiscoverPosts()
                    }
                }
            }
        }
        .alert("Delete Post", isPresented: $showingDeletePostAlert) {
            Button("Cancel", role: .cancel) { 
                postToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let postToDelete = postToDelete {
                    Task {
                        try? await dbManager.deactivateDiscoverPost(postToDelete.id)
                        self.postToDelete = nil
                        await loadUserDiscoverPosts()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this discover post?")
        }
        .onAppear {
            Task {
                await checkUserProfile()
                await loadUserStats()
                await loadUserDiscoverPosts()
                await loadUserRSVPPosts()
            }
        }
        .onChange(of: dbManager.isAuthenticated) { oldValue, newValue in
            if newValue && !oldValue {
                // User just got authenticated, check their profile and load stats
                Task {
                    await checkUserProfile()
                    await loadUserStats()
                    await loadUserDiscoverPosts()
                    await loadUserRSVPPosts()
                }
            } else if !newValue {
                // User signed out, clear profile and stats
                userProfile = nil
                userStats = nil
                userDiscoverPosts = []
                userRSVPPosts = []
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UserStatsDidChange"))) { _ in
            Task {
                await loadUserStats()
            }
        }
    }
    
    // MARK: - Methods
    
    @MainActor
    private func checkUserProfile() async {
        guard dbManager.isAuthenticated else {
            userProfile = nil
            return
        }
        
        isLoadingProfile = true
        
        do {
            let profile = try await dbManager.fetchCurrentUser()
            userProfile = profile
        } catch {
            // User doesn't have a profile yet, or there was an error
            userProfile = nil
            print("No user profile found: \(error.localizedDescription)")
        }
        
        isLoadingProfile = false
    }
    
    @MainActor
    private func loadUserStats() async {
        guard dbManager.isAuthenticated else {
            userStats = nil
            return
        }
        
        isLoadingStats = true
        
        do {
            let stats = try await dbManager.fetchUserStats()
            userStats = stats
        } catch {
            // If there's an error, show default stats
            userStats = UserStats()
            print("Failed to load user stats: \(error.localizedDescription)")
        }
        
        isLoadingStats = false
    }
    
    // Helper method to refresh stats from external views
    func refreshUserStats() async {
        await loadUserStats()
    }
    
    @MainActor
    private func loadUserDiscoverPosts() async {
        guard dbManager.isAuthenticated else {
            userDiscoverPosts = []
            return
        }
        
        isLoadingDiscoverPosts = true
        
        do {
            let posts = try await dbManager.fetchUserDiscoverPosts()
            userDiscoverPosts = posts
        } catch {
            userDiscoverPosts = []
            print("Failed to load user discover posts: \(error.localizedDescription)")
        }
        
        isLoadingDiscoverPosts = false
    }
    
    @MainActor
    private func loadUserRSVPPosts() async {
        guard dbManager.isAuthenticated else {
            userRSVPPosts = []
            return
        }
        
        isLoadingRSVPPosts = true
        
        do {
            let rsvpPosts = try await dbManager.fetchUserRSVPDiscoverPosts()
            userRSVPPosts = rsvpPosts
        } catch {
            userRSVPPosts = []
            print("Failed to load user RSVP posts: \(error.localizedDescription)")
        }
        
        isLoadingRSVPPosts = false
    }
    
    private func handleStatTap(_ statType: StatType) {
        switch statType {
        case .crates:
            showingCratesOverlay = true
        case .exchanges:
            showingExchangesOverlay = true
        }
    }
}

// MARK: - Field style modifier

private extension View {
    func sonexFieldStyle() -> some View {
        self
            .padding(14)
            .background(Color.sonexSurface)
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            }
    }
}

// MARK: - User Stats View

enum StatType {
    case crates, exchanges
}

struct UserStatsView: View {
    let stats: UserStats
    let onStatTap: (StatType) -> Void
    let onFollowingTap: () -> Void
    let onFollowersTap: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // First row: Crates and Exchanges
            HStack(spacing: 32) {
                StatItemView(
                    value: stats.cratesCount,
                    title: "Crates",
                    action: { onStatTap(.crates) }
                )
                
                StatItemView(
                    value: stats.exchangesCount,
                    title: "Exchanges",
                    action: { onStatTap(.exchanges) }
                )
            }
            
            // Second row: Following and Followers (individually tappable)
            HStack(spacing: 16) {
                Button(action: onFollowingTap) {
                    VStack(spacing: 4) {
                        Text("\(stats.followingCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text("Following")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.sonexSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onFollowersTap) {
                    VStack(spacing: 4) {
                        Text("\(stats.followersCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text("Followers")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.sonexSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
        
        }
        .padding(.horizontal, 16)
    }
}

struct StatItemView: View {
    let value: Int
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(value)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Overlay Views

struct CratesOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    private let dbManager = SonexDBManager.shared
    @State private var crates: [CrateWithCount] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Color.sonexAmber)
                        Text("Loading crates...")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.red.opacity(0.6))
                        
                        Text("Error loading crates")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text(errorMessage)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            loadCrates()
                        }
                        .foregroundStyle(Color.sonexAmber)
                    }
                    .padding()
                } else {
                    List(crates) { crate in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(crate.name)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                if crate.forSale {
                                    Text("For Sale")
                                        .font(.caption)
                                        .foregroundStyle(Color.green)
                                }
                            }
                            
                            Spacer()
                            
                            Text("\(crate.recordCount) records")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.sonexSurface)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("My Crates")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.sonexAmber)
                }
            }
        }
        .onAppear {
            loadCrates()
        }
    }
    
    private func loadCrates() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedCrates = try await dbManager.fetchCratesWithCounts()
                await MainActor.run {
                    self.crates = fetchedCrates
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct FollowingOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    private let dbManager = SonexDBManager.shared
    @State private var following: [FriendshipRelation] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Search functionality
    @State private var searchText = ""
    @State private var searchResults: [SonexUser] = []
    @State private var isLoadingSearch = false
    @State private var followingUserIds: Set<String> = []
    @State private var followingStates: [String: Bool] = [:]  // Track follow state for each user
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Debug section for troubleshooting
                    if ProcessInfo.processInfo.environment["DEBUG_SOCIAL"] != nil {
                        VStack(spacing: 8) {
                            Text("🔍 Debug Mode")
                                .font(.caption)
                                .foregroundStyle(Color.sonexAmber)
                            
                            Button("Test Raw Following Data") {
                                Task {
                                    await debugRawFollowingData()
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.blue)
                            
                            Text("Check console for debug output")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(8)
                        .background(Color.sonexSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 16)
                    }
                    
                    // Search Bar
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.white.opacity(0.6))
                                .font(.system(size: 16))
                            
                            TextField("search people...", text: $searchText)
                                .foregroundStyle(.white)
                                .textFieldStyle(PlainTextFieldStyle())
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.sonexSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        
                        // Show search results or following list
                        if !searchText.isEmpty {
                            searchResultsSection
                        } else {
                            followingListSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    Spacer()
                }
            }
            .navigationTitle("Following")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.sonexAmber)
                }
            }
        }
        .onAppear {
            print("FollowingOverlayView: onAppear called")
            Task {
                await loadFollowing()
                await updateFollowingUserIds()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UserStatsDidChange"))) { _ in
            print("FollowingOverlayView: Received UserStatsDidChange notification - refreshing following list")
            Task {
                await loadFollowing()
                await updateFollowingUserIds()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FollowingListDidChange"))) { _ in
            print("FollowingOverlayView: Received FollowingListDidChange notification - refreshing following list")
            Task {
                await loadFollowing()
                await updateFollowingUserIds()
            }
        }
        .onChange(of: searchText) { oldValue, newValue in
            if !newValue.isEmpty && newValue.count > 2 {
                Task {
                    await searchUsers(query: newValue)
                }
            } else {
                searchResults = []
            }
        }
    }
    
    @ViewBuilder
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoadingSearch {
                HStack {
                    ProgressView()
                        .tint(Color.sonexAmber)
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if searchResults.isEmpty && searchText.count > 2 {
                Text("No users found")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RESULTS")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.leading, 4)
                    
                    LazyVStack(spacing: 12) {
                        ForEach(searchResults) { user in
                            NavigationLink(destination: UserDetailsView(userId: user.id)) {
                                UserSearchResultView(
                                    user: user,
                                    isFollowing: followingStates[user.id] ?? followingUserIds.contains(user.id),
                                    onFollowTap: {
                                        Task {
                                            await toggleFollowForUser(user: user)
                                        }
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var followingListSection: some View {
        VStack(spacing: 0) {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Color.sonexAmber)
                    Text("Loading following...")
                        .foregroundStyle(.white.opacity(0.6))
                }
                .onAppear {
                    print("FollowingOverlayView: Showing loading state")
                }
            } else if let errorMessage = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.red.opacity(0.6))
                    
                    Text("Error loading following")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding()
                .onAppear {
                    print("FollowingOverlayView: Showing error state: \(errorMessage)")
                }
            } else if following.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Text("Not following anyone yet")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("Start following other users to see them here")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding()
                .onAppear {
                    print("FollowingOverlayView: Showing empty state (following.count = \(following.count))")
                }
            } else {
                List(following) { relation in
                    HStack {
                        NavigationLink(destination: UserDetailsView(userId: relation.user.id)) {
                            HStack {
                                // User avatar placeholder
                                Circle()
                                    .fill(Color.sonexAmber)
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Text(relation.user.username.prefix(1).uppercased())
                                            .font(.headline)
                                            .foregroundStyle(.black)
                                    }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(relation.user.displayName ?? relation.user.username)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    
                                    Text("@\(relation.user.username)")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
//                        Spacer()
//                        
//                        Button("Unfollow") {
//                            Task {
//                                await unfollowUser(relation.user.id)
//                            }
//                        }
//                        .font(.caption)
//                        .foregroundStyle(Color.red)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.sonexSurface)
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                .onAppear {
                    print("FollowingOverlayView: Showing list with \(following.count) following relationships")
                }
            }
        }
    }
    
    @MainActor
    private func loadFollowing() async {
        isLoading = true
        errorMessage = nil
        
        print("FollowingOverlayView: Starting to load following...")
        
        do {
            // Try the safer approach first
            let fetchedFollowing = try await safeFetchFollowing()
            print("FollowingOverlayView: Successfully fetched \(fetchedFollowing.count) following relationships")
            following = fetchedFollowing
            isLoading = false
            print("FollowingOverlayView: Updated UI with \(following.count) following")
        } catch {
            print("FollowingOverlayView: Error loading following: \(error)")
            
            // Add detailed error logging
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ Missing key '\(key.stringValue)' in context: \(context.debugDescription)")
                    errorMessage = "Missing data field: \(key.stringValue)"
                case .valueNotFound(let type, let context):
                    print("❌ Missing value for type '\(type)' in context: \(context.debugDescription)")
                    errorMessage = "Missing value for \(type)"
                case .typeMismatch(let type, let context):
                    print("❌ Type mismatch for '\(type)' in context: \(context.debugDescription)")
                    errorMessage = "Data format error for \(type)"
                case .dataCorrupted(let context):
                    print("❌ Data corrupted in context: \(context.debugDescription)")
                    errorMessage = "Data corrupted: \(context.debugDescription)"
                @unknown default:
                    print("❌ Unknown decoding error: \(decodingError)")
                    errorMessage = "Unknown data parsing error"
                }
            } else {
                errorMessage = error.localizedDescription
            }
            
            isLoading = false
        }
    }
    
    // Safe fetching method with better error handling
    private func safeFetchFollowing() async throws -> [FriendshipRelation] {
        print("🔍 FollowingOverlayView: Attempting safe fetch following...")
        
        do {
            // Try the regular method first
            let result = try await dbManager.fetchFollowing()
            print("✅ Regular fetchFollowing succeeded with \(result.count) items")
            return result
        } catch {
            print("⚠️ Regular fetchFollowing failed: \(error)")
            
            // For now, return an empty array rather than crashing
            // In a real implementation, you might want to try alternative data sources
            // or implement a retry mechanism
            return []
        }
    }
    
    // Debug method to inspect raw data
    private func debugRawFollowingData() async {
        print("🔍 [DEBUG] Starting raw data inspection for following...")
        
        // This would require access to the underlying network call
        // Since we can't see the SonexDBManager implementation, 
        // we'll just print what we can observe
        
        print("🔍 [DEBUG] Current following count: \(following.count)")
        print("🔍 [DEBUG] Current error message: \(errorMessage ?? "none")")
        print("🔍 [DEBUG] Is loading: \(isLoading)")
        
        // Try to get some info about the current user
        do {
            if let user = try? await dbManager.fetchCurrentUser() {
                print("🔍 [DEBUG] Current user ID: \(user.id)")
                print("🔍 [DEBUG] Current user: \(user.username)")
            }
        } catch {
            print("🔍 [DEBUG] Could not fetch current user: \(error)")
        }
        
        print("🔍 [DEBUG] Re-attempting following load...")
        await loadFollowing()
    }
    
    @MainActor
    private func updateFollowingUserIds() async {
        followingUserIds = Set(following.map { $0.user.id })
    }
    
    @MainActor
    private func searchUsers(query: String) async {
        isLoadingSearch = true
        
        do {
            let users = try await dbManager.searchUsers(query: query, limit: 20)
            searchResults = users
        } catch {
            print("Error searching users: \(error)")
            searchResults = []
        }
        
        isLoadingSearch = false
    }
    
    @MainActor
    private func toggleFollow(user: SonexUser) async {
        let isCurrentlyFollowing = followingUserIds.contains(user.id)
        
        do {
            if isCurrentlyFollowing {
                try await dbManager.unfollowUser(userId: user.id)
                followingUserIds.remove(user.id)
            } else {
                try await dbManager.followUser(userId: user.id)
                followingUserIds.insert(user.id)
            }
            
            // Refresh the connections
            await loadFollowing()
            await updateFollowingUserIds()
            
            // Post notification to refresh main profile stats
            NotificationCenter.default.post(name: Notification.Name("UserStatsDidChange"), object: nil)
            
            // Post notification to refresh following lists
            NotificationCenter.default.post(name: Notification.Name("FollowingListDidChange"), object: nil)
            
            // Also post notification for the specific user that was followed/unfollowed
            NotificationCenter.default.post(name: Notification.Name("ViewedUserStatsDidChange"), object: ["userId": user.id])
        } catch {
            print("Error toggling follow: \(error)")
            // TODO: Show error alert to user
        }
    }
    
    @MainActor
    private func toggleFollowForUser(user: SonexUser) async {
        let isCurrentlyFollowing = followingStates[user.id] ?? followingUserIds.contains(user.id)
        
        // Update UI immediately
        followingStates[user.id] = !isCurrentlyFollowing
        
        do {
            if isCurrentlyFollowing {
                try await dbManager.unfollowUser(userId: user.id)
                followingUserIds.remove(user.id)
            } else {
                try await dbManager.followUser(userId: user.id)
                followingUserIds.insert(user.id)
            }
            
            // Update the persistent state
            followingStates[user.id] = !isCurrentlyFollowing
            
            // Refresh the connections for consistency
            await loadFollowing()
            await updateFollowingUserIds()
            
            // Post notification to refresh main profile stats
            NotificationCenter.default.post(name: Notification.Name("UserStatsDidChange"), object: nil)
            
            // Post notification to refresh following lists
            NotificationCenter.default.post(name: Notification.Name("FollowingListDidChange"), object: nil)
            
            // Also post notification for the specific user that was followed/unfollowed
            NotificationCenter.default.post(name: Notification.Name("ViewedUserStatsDidChange"), object: ["userId": user.id])
        } catch {
            print("Error toggling follow: \(error)")
            // Revert the UI change if the API call failed
            followingStates[user.id] = isCurrentlyFollowing
        }
    }
    
    @MainActor
    private func unfollowUser(_ userId: String) async {
        print("🔄 [FollowingOverlayView] Starting unfollow for user ID: \(userId)")
        
        // Update UI immediately for better UX
        following.removeAll { $0.user.id == userId }
        followingUserIds.remove(userId)
        
        do {
            print("🌐 [FollowingOverlayView] Calling dbManager.unfollowUser...")
            try await dbManager.unfollowUser(userId: userId)
            print("✅ [FollowingOverlayView] Successfully unfollowed user")
            
            print("🔄 [FollowingOverlayView] Refreshing following list...")
            // Refresh the list to ensure consistency
            await loadFollowing()
            await updateFollowingUserIds()
            
            // Post notification to refresh main profile stats
            NotificationCenter.default.post(name: Notification.Name("UserStatsDidChange"), object: nil)
            
            // Post notification to refresh following lists
            NotificationCenter.default.post(name: Notification.Name("FollowingListDidChange"), object: nil)
            
            // Also post notification for the specific user that was unfollowed
            NotificationCenter.default.post(name: Notification.Name("ViewedUserStatsDidChange"), object: ["userId": userId])
            
        } catch {
            print("❌ [FollowingOverlayView] Error unfollowing user: \(error)")
            // Revert UI changes if the API call failed
            await loadFollowing()
            await updateFollowingUserIds()
            errorMessage = "Failed to unfollow user: \(error.localizedDescription)"
        }
    }
}

struct FollowersOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    private let dbManager = SonexDBManager.shared
    @State private var followers: [FriendshipRelation] = []
    @State private var following: [FriendshipRelation] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Debug section for troubleshooting
                    if ProcessInfo.processInfo.environment["DEBUG_SOCIAL"] != nil {
                        VStack(spacing: 8) {
                            Text("🔍 Debug Mode")
                                .font(.caption)
                                .foregroundStyle(Color.sonexAmber)
                            
                            Button("Test Raw Followers Data") {
                                Task {
                                    await debugRawFollowersData()
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.blue)
                            
                            Text("Check console for debug output")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(8)
                        .background(Color.sonexSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(Color.sonexAmber)
                            Text("Loading followers...")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.red.opacity(0.6))
                        
                        Text("Error loading followers")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text(errorMessage)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if followers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.4))
                        
                        Text("No followers yet")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text("When someone follows you, they'll appear here")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(followers) { relation in
                        HStack {
                            NavigationLink(destination: UserDetailsView(userId: relation.user.id)) {
                                HStack {
                                    // User avatar placeholder
                                    Circle()
                                        .fill(Color.sonexAmber)
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            Text(relation.user.username.prefix(1).uppercased())
                                                .font(.headline)
                                                .foregroundStyle(.black)
                                        }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(relation.user.displayName ?? relation.user.username)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        
                                        Text("@\(relation.user.username)")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            
                            if isUserFollowingBack(relation.user.id) {
                                Button("Following") {
                                    Task {
                                        await unfollowUser(relation.user.id)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(Color.green)
                            } else {
                                Button("Follow Back") {
                                    Task {
                                        await followUser(relation.user.id)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(Color.sonexAmber)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.sonexSurface)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Followers")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.sonexAmber)
                }
            }
        }
        .onAppear {
            loadFollowersAndFollowing()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UserStatsDidChange"))) { _ in
            print("FollowersOverlayView: Received UserStatsDidChange notification - refreshing followers list")
            loadFollowersAndFollowing()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FollowingListDidChange"))) { _ in
            print("FollowersOverlayView: Received FollowingListDidChange notification - refreshing followers list")
            loadFollowersAndFollowing()
        }
    }
    
    private func loadFollowersAndFollowing() {
        Task {
            await loadFollowers()
            await loadFollowing()
        }
    }
    
    @MainActor
    private func loadFollowers() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedFollowers = try await safeFetchFollowers()
            followers = fetchedFollowers
            print("FollowersOverlayView: Successfully loaded \(fetchedFollowers.count) followers")
        } catch {
            print("FollowersOverlayView: Error loading followers: \(error)")
            
            // Add detailed error logging
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ Missing key '\(key.stringValue)' in context: \(context.debugDescription)")
                    errorMessage = "Missing data field: \(key.stringValue)"
                case .valueNotFound(let type, let context):
                    print("❌ Missing value for type '\(type)' in context: \(context.debugDescription)")
                    errorMessage = "Missing value for \(type)"
                case .typeMismatch(let type, let context):
                    print("❌ Type mismatch for '\(type)' in context: \(context.debugDescription)")
                    errorMessage = "Data format error for \(type)"
                case .dataCorrupted(let context):
                    print("❌ Data corrupted in context: \(context.debugDescription)")
                    errorMessage = "Data corrupted: \(context.debugDescription)"
                @unknown default:
                    print("❌ Unknown decoding error: \(decodingError)")
                    errorMessage = "Unknown data parsing error"
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
        
        isLoading = false
    }
    
    // Safe fetching method with better error handling
    private func safeFetchFollowers() async throws -> [FriendshipRelation] {
        print("🔍 FollowersOverlayView: Attempting safe fetch followers...")
        
        do {
            // Try the regular method first
            let result = try await dbManager.fetchFollowers()
            print("✅ Regular fetchFollowers succeeded with \(result.count) items")
            return result
        } catch {
            print("⚠️ Regular fetchFollowers failed: \(error)")
            
            // For now, return an empty array rather than crashing
            // In a real implementation, you might want to try alternative data sources
            // or implement a retry mechanism
            return []
        }
    }
    
    // Debug method to inspect raw data
    private func debugRawFollowersData() async {
        print("🔍 [DEBUG] Starting raw data inspection for followers...")
        
        print("🔍 [DEBUG] Current followers count: \(followers.count)")
        print("🔍 [DEBUG] Current error message: \(errorMessage ?? "none")")
        print("🔍 [DEBUG] Is loading: \(isLoading)")
        
        // Try to get some info about the current user
        do {
            if let user = try? await dbManager.fetchCurrentUser() {
                print("🔍 [DEBUG] Current user ID: \(user.id)")
                print("🔍 [DEBUG] Current user: \(user.username)")
            }
        } catch {
            print("🔍 [DEBUG] Could not fetch current user: \(error)")
        }
        
        print("🔍 [DEBUG] Re-attempting followers load...")
        await loadFollowers()
    }
    
    @MainActor
    private func loadFollowing() async {
        do {
            let fetchedFollowing = try await dbManager.fetchFollowing()
            following = fetchedFollowing
        } catch {
            print("Error loading following: \(error)")
        }
    }
    
    private func isUserFollowingBack(_ userId: String) -> Bool {
        return following.contains { $0.user.id == userId }
    }
    
    @MainActor
    private func followUser(_ userId: String) async {
        do {
            try await dbManager.followUser(userId: userId)
            
            // Refresh both lists
            await loadFollowing()
            await loadFollowers()
            
            // Post notification to refresh main profile stats
            NotificationCenter.default.post(name: Notification.Name("UserStatsDidChange"), object: nil)
            
            // Post notification to refresh following lists
            NotificationCenter.default.post(name: Notification.Name("FollowingListDidChange"), object: nil)
            
            // Also post notification for the specific user that was followed
            NotificationCenter.default.post(name: Notification.Name("ViewedUserStatsDidChange"), object: ["userId": userId])
            
        } catch {
            print("Error following user: \(error)")
            // TODO: Show error alert to user
        }
    }
    
    @MainActor
    private func unfollowUser(_ userId: String) async {
        do {
            try await dbManager.unfollowUser(userId: userId)
            
            // Refresh both lists
            await loadFollowing()
            await loadFollowers()
            
            // Post notification to refresh main profile stats
            NotificationCenter.default.post(name: Notification.Name("UserStatsDidChange"), object: nil)
            
            // Post notification to refresh following lists
            NotificationCenter.default.post(name: Notification.Name("FollowingListDidChange"), object: nil)
            
            // Also post notification for the specific user that was unfollowed
            NotificationCenter.default.post(name: Notification.Name("ViewedUserStatsDidChange"), object: ["userId": userId])
            
        } catch {
            print("Error unfollowing user: \(error)")
            // TODO: Show error alert to user
        }
    }
}

struct ExchangesOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    private let dbManager = SonexDBManager.shared
    @State private var exchanges: [ExchangeSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Color.sonexAmber)
                        Text("Loading exchanges...")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.red.opacity(0.6))
                        
                        Text("Error loading exchanges")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text(errorMessage)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if exchanges.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.4))
                        
                        Text("No exchanges yet")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text("Your vinyl exchanges will appear here")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(exchanges) { exchange in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(exchange.otherUser.displayName ?? exchange.otherUser.username)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                Spacer()
                                
                                Text(exchange.status.rawValue.capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(statusColor(exchange.status))
                                    .foregroundStyle(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            
                            HStack {
                                Text("\(exchange.recordCount) record\(exchange.recordCount == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                                
                                if let totalPrice = exchange.totalPrice {
                                    Text("• $\(totalPrice, specifier: "%.2f")")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                
                                Text("• \(exchange.isSellerInExchange ? "Selling" : "Buying")")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.sonexSurface)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Exchanges")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.sonexAmber)
                }
            }
        }
        .onAppear {
            loadExchanges()
        }
    }
    
    private func loadExchanges() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedExchanges = try await dbManager.fetchExchangeHistory()
                await MainActor.run {
                    self.exchanges = fetchedExchanges
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func statusColor(_ status: ExchangeStatus) -> Color {
        switch status {
        case .pending, .countered:
            return Color.orange
        case .accepted:
            return Color.green
        case .completed:
            return Color.sonexAmber
        case .cancelled, .disputed:
            return Color.red
        }
    }
}



// MARK: - User Search Result View

struct UserSearchResultView: View {
    let user: SonexUser
    let isFollowing: Bool
    let onFollowTap: () -> Void
    
    private var initials: String {
        let displayName = user.displayName ?? user.username
        return String(displayName.prefix(2).uppercased())
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(avatarColor)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(initials)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                }
            
            // User Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? user.username)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Follow Button
            Button(action: onFollowTap) {
                Text(isFollowing ? "following" : "follow")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isFollowing ? .white : .black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(isFollowing ? Color.sonexSurface : Color.sonexAmber)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        if isFollowing {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                        }
                    }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var avatarColor: Color {
        let colors: [Color] = [
            Color.orange, Color.green, Color.blue, Color.purple, 
            Color.pink, Color.cyan, Color.mint, Color.indigo
        ]
        let index = abs(user.username.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    private let dbManager = SonexDBManager.shared
    let userProfile: SonexUser
    let onComplete: () -> Void
    
    @State private var username: String
    @State private var displayName: String
    @State private var bio: String
    @State private var address: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(userProfile: SonexUser, onComplete: @escaping () -> Void) {
        self.userProfile = userProfile
        self.onComplete = onComplete
        self._username = State(initialValue: userProfile.username)
        self._displayName = State(initialValue: userProfile.displayName ?? "")
        self._bio = State(initialValue: userProfile.bio ?? "")
        self._address = State(initialValue: userProfile.address ?? "")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.sonexAmber)
                        
                        Text("Edit your profile")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 40)
                    
                    // Form Fields
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            TextField("Enter username", text: $username)
                                .sonexFieldStyle()
                                .textContentType(.username)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display Name")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            TextField("Enter display name", text: $displayName)
                                .sonexFieldStyle()
                                .textContentType(.name)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Address")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            TextField("Enter your address", text: $address)
                                .sonexFieldStyle()
                                .textContentType(.fullStreetAddress)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            TextField("Tell us about yourself", text: $bio, axis: .vertical)
                                .lineLimit(3...6)
                                .sonexFieldStyle()
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    
                    // Error Message
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onComplete()
                    }
                    .foregroundStyle(Color.sonexAmber)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await saveProfile()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(Color.sonexAmber)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(Color.sonexAmber)
                    .disabled(username.trim().isEmpty || isLoading)
                }
            }
        }
    }
    
    private func saveProfile() async {
        isLoading = true
        errorMessage = nil
        
        let trimmedUsername = username.trim()
        let trimmedDisplayName = displayName.trim().isEmpty ? nil : displayName.trim()
        let trimmedBio = bio.trim().isEmpty ? nil : bio.trim()
        let trimmedAddress = address.trim().isEmpty ? nil : address.trim()
        
        do {
            let updatePayload = ProfileUpdatePayload(
                username: trimmedUsername,
                displayName: trimmedDisplayName,
                avatarUrl: nil,
                bio: trimmedBio,
                address: trimmedAddress
            )
            try await dbManager.updateProfile(updatePayload)
            
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Settings Menu View

struct SettingsMenuView: View {
    let onSignOut: () -> Void
    let onDeleteAccount: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.sonexAmber)
                        
                        Text("Settings")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 16) {
                        // Privacy Policy Button
                        Button {
                            if let url = URL(string: "https://sonex.app/privacy") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundStyle(Color.sonexAmber)
                                
                                Text("Privacy Policy")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(16)
                            .background(Color.sonexSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        
                        // Sign Out Button
                        Button {
                            onSignOut()
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundStyle(Color.orange)
                                
                                Text("Sign Out")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(Color.sonexSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        
                        // Delete Account Button
                        Button {
                            onDeleteAccount()
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundStyle(Color.red)
                                
                                Text("Delete Account")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(Color.sonexSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
    }
}

// MARK: - Profile Creation View

struct ProfileCreationView: View {
    private let dbManager = SonexDBManager.shared
    let onComplete: () -> Void
    
    @State private var username = ""
    @State private var displayName = ""
    @State private var bio = ""
    @State private var address = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.sonexAmber)
                        
                        Text("Create your profile")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        
                        Text("Set up your Sonex profile to get started")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Form Fields
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            TextField("Enter username", text: $username)
                                .sonexFieldStyle()
                                .textContentType(.username)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            
                            Text("This will be your unique identifier on Sonex")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display Name (Optional)")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            TextField("Enter display name", text: $displayName)
                                .sonexFieldStyle()
                                .textContentType(.name)
                            
                            Text("This is how others will see you")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio (Optional)")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            TextField("Tell us about yourself", text: $bio, axis: .vertical)
                                .lineLimit(3...6)
                                .sonexFieldStyle()
                            
                            Text("Share something about yourself and your music taste")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Address (Optional)")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            TextField("Enter your address", text: $address)
                                .sonexFieldStyle()
                                .textContentType(.fullStreetAddress)
                            
                            Text("Help others find you for local music events")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Error Message
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                    
                    // Create Profile Button
                    Button {
                        Task {
                            await createProfile()
                        }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text("Create Profile")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.sonexAmber)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                    .disabled(username.trim().isEmpty || isLoading)
                }
            }
            .navigationTitle("Profile Setup")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
    }
    
    private func createProfile() async {
        isLoading = true
        errorMessage = nil
        
        let trimmedUsername = username.trim()
        let trimmedDisplayName = displayName.trim().isEmpty ? nil : displayName.trim()
        let trimmedBio = bio.trim().isEmpty ? nil : bio.trim()
        let trimmedAddress = address.trim().isEmpty ? nil : address.trim()
        
        do {
            // First create the user profile with username, display name, bio, and address
            _ = try await dbManager.createUserProfile(
                username: trimmedUsername,
                displayName: trimmedDisplayName,
                bio: trimmedBio,
                address: trimmedAddress
            )
            
            // If bio or address is provided, update the profile to include them
            if trimmedBio != nil || trimmedAddress != nil {
                let updatePayload = ProfileUpdatePayload(
                    username: nil,
                    displayName: nil,
                    avatarUrl: nil,
                    bio: trimmedBio,
                    address: trimmedAddress
                )
                try await dbManager.updateProfile(updatePayload)
            }
            
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - String Extension

private extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Discover Post Preview Cards

struct DiscoverPostPreviewCard: View {
    let post: DiscoverPost
    let showMenu: Bool
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    
    @State private var showingMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with type and menu
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: post.type.iconName)
                        .font(.caption)
                        .foregroundStyle(post.type.color)
                    
                    Text(post.type.displayName)
                        .font(.caption2)
                        .foregroundStyle(post.type.color)
                }
                
                Spacer()
                
                if showMenu {
                    Button {
                        showingMenu = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                if let title = post.title, !title.isEmpty {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                } else {
                    Text(post.type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                
                if let description = post.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(3)
                }
                
                if let address = post.address {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Text(address)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                
                // Time since created
                if let createdAt = post.createdAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Text(timeAgoString(from: createdAt))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 180, alignment: .leading)
        .background(Color.sonexSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
        .confirmationDialog("Post Options", isPresented: $showingMenu, titleVisibility: .visible) {
            Button("Edit") {
                onEdit?()
            }
            
            Button("Delete", role: .destructive) {
                onDelete?()
            }
            
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private func timeAgoString(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return "Unknown"
        }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 3600 { // Less than 1 hour
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 { // Less than 1 day
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else { // 1 day or more
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
}

struct DiscoverPostRSVPCard: View {
    let postWithRSVP: DiscoverPostWithRSVP
    let onRemoveRSVP: () -> Void
    
    @State private var showingMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with type and RSVP status
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: postWithRSVP.post.type.iconName)
                        .font(.caption)
                        .foregroundStyle(postWithRSVP.post.type.color)
                    
                    Text(postWithRSVP.post.type.displayName)
                        .font(.caption2)
                        .foregroundStyle(postWithRSVP.post.type.color)
                }
                
                Spacer()
                
                // RSVP Status Badge
                HStack(spacing: 4) {
                    Image(systemName: postWithRSVP.rsvpStatus.icon)
                        .font(.caption2)
                        .foregroundStyle(postWithRSVP.rsvpStatus.color)
                    
                    Text(postWithRSVP.rsvpStatus.displayName)
                        .font(.caption2)
                        .foregroundStyle(postWithRSVP.rsvpStatus.color)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(postWithRSVP.rsvpStatus.color.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                if let title = postWithRSVP.post.title, !title.isEmpty {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                } else {
                    Text(postWithRSVP.post.type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                
                if let description = postWithRSVP.post.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(3)
                }
                
                if let address = postWithRSVP.post.address {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Text(address)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                
                // Remove RSVP Button
                Button {
                    onRemoveRSVP()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "minus.circle")
                            .font(.caption2)
                        
                        Text("Remove RSVP")
                            .font(.caption2)
                    }
                    .foregroundStyle(.red.opacity(0.8))
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(width: 180, alignment: .leading)
        .background(Color.sonexSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
    }
}

// MARK: - Edit Discover Post View

struct EditDiscoverPostView: View {
    let post: DiscoverPost
    let onComplete: () -> Void
    
    @State private var title: String
    @State private var description: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let dbManager = SonexDBManager.shared
    
    init(post: DiscoverPost, onComplete: @escaping () -> Void) {
        self.post = post
        self.onComplete = onComplete
        self._title = State(initialValue: post.title ?? "")
        self._description = State(initialValue: post.description ?? "")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: post.type.iconName)
                                .font(.system(size: 24))
                                .foregroundStyle(post.type.color)
                            
                            Text("Edit \(post.type.displayName)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        
                        if let address = post.address {
                            HStack(spacing: 4) {
                                Image(systemName: "location")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                                
                                Text(address)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    // Form Fields
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            TextField("Enter title", text: $title)
                                .sonexFieldStyle()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            TextField("Enter description", text: $description, axis: .vertical)
                                .lineLimit(3...6)
                                .sonexFieldStyle()
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onComplete()
                    }
                    .foregroundStyle(Color.sonexAmber)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await saveChanges()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(Color.sonexAmber)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(Color.sonexAmber)
                    .disabled(isLoading)
                }
            }
        }
    }
    
    private func saveChanges() async {
        isLoading = true
        errorMessage = nil
        
        let trimmedTitle = title.trim().isEmpty ? nil : title.trim()
        let trimmedDescription = description.trim().isEmpty ? nil : description.trim()
        
        do {
            try await dbManager.updateDiscoverPost(
                post.id,
                title: trimmedTitle,
                description: trimmedDescription
            )
            
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - DiscoverPostType Extension for UI

extension DiscoverPostType {
    var iconName: String {
        switch self {
        case .crateDrop:
            return "archivebox"
        case .recordSwap:
            return "arrow.left.arrow.right"
        case .collectionSale:
            return "bag"
        case .scouting:
            return "magnifyingglass"
        case .djSet:
            return "music.note"
        case .recordStore:
            return "building.2"
        case .listeningBar:
            return "hifispeaker.2"
        case .dancingBar:
            return "figure.socialdance"
        case .event:
            return "calendar"
        }
    }
    
    var color: Color {
        switch self {
        case .crateDrop:
            return Color.sonexAmber
        case .recordSwap:
            return Color.orange
        case .collectionSale:
            return Color.green
        case .scouting:
            return Color.blue
        case .djSet:
            return Color.purple
        case .recordStore:
            return Color.cyan
        case .listeningBar:
            return Color.indigo
        case .dancingBar:
            return Color.teal
        case .event:
            return Color.red
        }
    }
    
    var displayName: String {
        switch self {
        case .crateDrop:
            return "Crate Drop"
        case .recordSwap:
            return "Record Swap"
        case .collectionSale:
            return "Collection Sale"
        case .scouting:
            return "Scouting"
        case .djSet:
            return "DJ Set"
        case .recordStore:
            return "Record Store"
        case .dancingBar:
            return "Dancing Bar"
        case .listeningBar:
            return "Listening Bar"
        case .event:
            return "Event"
        }
    }
}

// MARK: - Debug Views for Social Features

struct SocialDebugView: View {
    private let dbManager = SonexDBManager.shared
    @State private var debugOutput: String = "Tap 'Run Diagnostics' to start debugging..."
    @State private var isRunning = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Social Features Debug")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("Use this view to diagnose issues with following/followers loading")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Button {
                        Task {
                            await runDiagnostics()
                        }
                    } label: {
                        HStack {
                            if isRunning {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(isRunning ? "Running..." : "Run Diagnostics")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.sonexAmber)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isRunning)
                    
                    // Debug Output
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Debug Output:")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        ScrollView {
                            Text(debugOutput)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 300)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }
            .background(Color.sonexCharcoal)
            .navigationTitle("Social Debug")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func runDiagnostics() async {
        isRunning = true
        debugOutput = "🔍 Starting social features diagnostics...\n\n"
        
        // Test 1: Check user authentication
        debugOutput += "TEST 1: User Authentication\n"
        debugOutput += "- Is Authenticated: \(dbManager.isAuthenticated)\n"
        if let userID = dbManager.userID {
            debugOutput += "- User ID: \(userID)\n"
        } else {
            debugOutput += "- User ID: None\n"
        }
        if let userEmail = dbManager.userEmail {
            debugOutput += "- User Email: \(userEmail)\n"
        } else {
            debugOutput += "- User Email: None\n"
        }
        debugOutput += "\n"
        
        // Test 2: Try to fetch current user
        debugOutput += "TEST 2: Current User Profile\n"
        do {
            let user = try await dbManager.fetchCurrentUser()
            debugOutput += "✅ Successfully fetched user profile\n"
            debugOutput += "- Username: \(user.username)\n"
            debugOutput += "- Display Name: \(user.displayName ?? "None")\n"
            debugOutput += "- User ID: \(user.id)\n"
        } catch {
            debugOutput += "❌ Failed to fetch user profile: \(error)\n"
            debugOutput += "- Error Type: \(type(of: error))\n"
            if let decodingError = error as? DecodingError {
                debugOutput += "- Decoding Error Details: \(decodingError)\n"
            }
        }
        debugOutput += "\n"
        
        // Test 3: Try to fetch following
        debugOutput += "TEST 3: Following Data\n"
        do {
            let following = try await dbManager.fetchFollowing()
            debugOutput += "✅ Successfully fetched following\n"
            debugOutput += "- Count: \(following.count)\n"
            for (index, relation) in following.prefix(3).enumerated() {
                debugOutput += "- Following \(index + 1): @\(relation.user.username) (ID: \(relation.id))\n"
            }
            if following.count > 3 {
                debugOutput += "- ... and \(following.count - 3) more\n"
            }
        } catch {
            debugOutput += "❌ Failed to fetch following: \(error)\n"
            debugOutput += "- Error Type: \(type(of: error))\n"
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    debugOutput += "- Missing Key: \(key.stringValue)\n"
                    debugOutput += "- Context: \(context.debugDescription)\n"
                case .valueNotFound(let type, let context):
                    debugOutput += "- Missing Value Type: \(type)\n"
                    debugOutput += "- Context: \(context.debugDescription)\n"
                case .typeMismatch(let type, let context):
                    debugOutput += "- Type Mismatch: Expected \(type)\n"
                    debugOutput += "- Context: \(context.debugDescription)\n"
                case .dataCorrupted(let context):
                    debugOutput += "- Data Corrupted\n"
                    debugOutput += "- Context: \(context.debugDescription)\n"
                @unknown default:
                    debugOutput += "- Unknown Decoding Error: \(decodingError)\n"
                }
            }
        }
        debugOutput += "\n"
        
        // Test 4: Try to fetch followers
        debugOutput += "TEST 4: Followers Data\n"
        do {
            let followers = try await dbManager.fetchFollowers()
            debugOutput += "✅ Successfully fetched followers\n"
            debugOutput += "- Count: \(followers.count)\n"
            for (index, relation) in followers.prefix(3).enumerated() {
                debugOutput += "- Follower \(index + 1): @\(relation.user.username) (ID: \(relation.id))\n"
            }
            if followers.count > 3 {
                debugOutput += "- ... and \(followers.count - 3) more\n"
            }
        } catch {
            debugOutput += "❌ Failed to fetch followers: \(error)\n"
            debugOutput += "- Error Type: \(type(of: error))\n"
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    debugOutput += "- Missing Key: \(key.stringValue)\n"
                    debugOutput += "- Context: \(context.debugDescription)\n"
                case .valueNotFound(let type, let context):
                    debugOutput += "- Missing Value Type: \(type)\n"
                    debugOutput += "- Context: \(context.debugDescription)\n"
                case .typeMismatch(let type, let context):
                    debugOutput += "- Type Mismatch: Expected \(type)\n"
                    debugOutput += "- Context: \(context.debugDescription)\n"
                case .dataCorrupted(let context):
                    debugOutput += "- Data Corrupted\n"
                    debugOutput += "- Context: \(context.debugDescription)\n"
                @unknown default:
                    debugOutput += "- Unknown Decoding Error: \(decodingError)\n"
                }
            }
        }
        debugOutput += "\n"
        
        // Test 5: Try to fetch user stats
        debugOutput += "TEST 5: User Stats\n"
        do {
            let stats = try await dbManager.fetchUserStats()
            debugOutput += "✅ Successfully fetched user stats\n"
            debugOutput += "- Following Count: \(stats.followingCount)\n"
            debugOutput += "- Followers Count: \(stats.followersCount)\n"
            debugOutput += "- Crates Count: \(stats.cratesCount)\n"
            debugOutput += "- Exchanges Count: \(stats.exchangesCount)\n"
        } catch {
            debugOutput += "❌ Failed to fetch user stats: \(error)\n"
            debugOutput += "- Error Type: \(type(of: error))\n"
        }
        debugOutput += "\n"
        
        debugOutput += "🏁 Diagnostics completed!\n"
        debugOutput += "\nIf you see errors above, this indicates where the issue lies.\n"
        debugOutput += "Copy this output and share it for further debugging.\n"
        
        isRunning = false
    }
}

