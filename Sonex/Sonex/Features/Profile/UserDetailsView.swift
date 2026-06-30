//
//  UserDetailsView.swift
//  Sonex
//
//  Created by Assistant on 4/28/26.
//

import SwiftUI
import SonexShared

struct UserDetailsView: View {
    let userId: String
    private let dbManager = SonexDBManager.shared
    
    @State private var userProfile: SonexUser?
    @State private var userStats: UserStats?
    @State private var isLoadingProfile = false
    @State private var isLoadingStats = false
    @State private var currentUser: SonexUser?
    @State private var isFollowing = false
    @State private var isUpdatingFollowStatus = false
    
    // Discover posts state
    @State private var userDiscoverPosts: [DiscoverPost] = []
    @State private var userRSVPPosts: [DiscoverPostWithRSVP] = []
    @State private var isLoadingDiscoverPosts = false
    @State private var isLoadingRSVPPosts = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.sonexCharcoal.ignoresSafeArea()
            
            if isLoadingProfile {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Color.sonexAmber)
                    Text("Loading profile...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else if let userProfile = userProfile {
                ScrollView {
                    VStack(spacing: 24) {
                        // User Info Section
                        VStack(spacing: 12) {
                            // User Avatar
                            userAvatarView(for: userProfile)
                            
                            // User Names
                            Text(userProfile.displayName ?? userProfile.username)
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Text("@\(userProfile.username)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            // Bio section
                            if let bio = userProfile.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.body)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                            
                            // Follow/Unfollow Button (only show if not current user)
                            if !isCurrentUser {
                                followButton
                            }
                            
                            // User Stats
                            if let stats = userStats {
                                UserStatsDisplayView(stats: stats, userId: userId)
                                    .padding(.top, 8)
                            }
                        }
                        
                        // Discover Posts Sections
                        VStack(spacing: 24) {
                            // User's Created Posts Section
                            discoverPostsSection
                            
                            // User's RSVP Posts Section
                            rsvpPostsSection
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 100) // Add bottom padding for safe area
                }
                .refreshable {
                    await refreshAllData()
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Text("User not found")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("This user may have been deleted or does not exist")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .navigationTitle(userProfile?.username ?? "User Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            Task {
                await loadAllData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UserStatsDidChange"))) { _ in
            Task {
                await loadUserStats()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ViewedUserStatsDidChange"))) { notification in
            if let userInfo = notification.object as? [String: String],
               let notificationUserId = userInfo["userId"],
               notificationUserId == userId {
                Task {
                    print("Received notification to refresh stats for viewed user: \(userId)")
                    await loadUserStats()
                }
            }
        }
    }
}

// MARK: - View Components
extension UserDetailsView {
    private func userAvatarView(for user: SonexUser) -> some View {
        Circle()
            .fill(avatarColor(for: user))
            .frame(width: 80, height: 80)
            .overlay {
                Text(avatarInitials(for: user))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.black)
            }
    }
    
    private func avatarInitials(for user: SonexUser) -> String {
        let displayName = user.displayName ?? user.username
        return String(displayName.prefix(2).uppercased())
    }
    
    private func avatarColor(for user: SonexUser) -> Color {
        let colors: [Color] = [
            Color.orange, Color.green, Color.blue, Color.purple,
            Color.pink, Color.cyan, Color.mint, Color.indigo,
            Color.sonexAmber
        ]
        let index = abs(user.username.hashValue) % colors.count
        return colors[index]
    }
    
    private var followButton: some View {
        Button {
            Task {
                await toggleFollowStatus()
            }
        } label: {
            HStack(spacing: 8) {
                if isUpdatingFollowStatus {
                    ProgressView()
                        .tint(.black)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: isFollowing ? "person.fill.checkmark" : "person.fill.badge.plus")
                        .font(.system(size: 14, weight: .medium))
                    
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(isFollowing ? .white : .black)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(isFollowing ? Color.sonexSurface : Color.sonexAmber)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                if isFollowing {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                }
            }
        }
        .disabled(isUpdatingFollowStatus)
        .accessibilityLabel(isFollowing ? "Unfollow user" : "Follow user")
        .accessibilityHint(isFollowing ? "Tap to unfollow this user" : "Tap to follow this user")
    }
    
    private var discoverPostsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Discover Posts")
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
                            UserDiscoverPostPreviewCard(post: post)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    private var rsvpPostsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Events & RSVPs")
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
                            UserRSVPPostPreviewCard(postWithRSVP: rsvpPost)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    private var isCurrentUser: Bool {
        guard let currentUser = currentUser, let userProfile = userProfile else { 
            print("Cannot determine if current user - currentUser: \(currentUser?.id ?? "nil"), userProfile: \(userProfile?.id ?? "nil")")
            return false 
        }
        let result = currentUser.id == userProfile.id
        print("isCurrentUser check: currentUser.id=\(currentUser.id), userProfile.id=\(userProfile.id), result=\(result)")
        return result
    }
}

// MARK: - Data Loading Methods
extension UserDetailsView {
    @MainActor
    private func loadAllData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadCurrentUser()
            }
            group.addTask {
                await self.loadUserProfile()
            }
            group.addTask {
                await self.loadUserStats()
            }
            group.addTask {
                await self.loadUserDiscoverPosts()
            }
            group.addTask {
                await self.loadUserRSVPPosts()
            }
            group.addTask {
                await self.loadFollowingStatus()
            }
        }
    }
    
    @MainActor
    private func refreshAllData() async {
        await loadAllData()
    }
    
    @MainActor
    private func loadCurrentUser() async {
        guard dbManager.isAuthenticated else { return }
        
        do {
            let user = try await dbManager.fetchCurrentUser()
            currentUser = user
        } catch {
            print("Failed to load current user: \(error)")
        }
    }
    
    @MainActor
    private func loadUserProfile() async {
        isLoadingProfile = true
        
        do {
            let profile = try await dbManager.fetchUserById(userId)
            userProfile = profile
        } catch {
            print("Failed to load user profile: \(error)")
            userProfile = nil
        }
        
        isLoadingProfile = false
    }
    
    @MainActor
    private func loadUserStats() async {
        isLoadingStats = true
        
        do {
            print("Loading user stats for user: \(userId)")
            let stats = try await dbManager.fetchUserStats(for: userId)
            userStats = stats
            print("Successfully loaded user stats: crates=\(stats.cratesCount), exchanges=\(stats.exchangesCount), following=\(stats.followingCount), followers=\(stats.followersCount), totalRecords=\(stats.totalRecordsCount)")
        } catch {
            print("Failed to load user stats: \(error)")
            userStats = UserStats()
        }
        
        isLoadingStats = false
    }
    
    @MainActor
    private func loadUserDiscoverPosts() async {
        isLoadingDiscoverPosts = true
        
        do {
            let posts = try await dbManager.fetchDiscoverPostsByUser(userId: userId)
            userDiscoverPosts = posts
        } catch {
            print("Failed to load user discover posts: \(error)")
            userDiscoverPosts = []
        }
        
        isLoadingDiscoverPosts = false
    }
    
    @MainActor
    private func loadUserRSVPPosts() async {
        isLoadingRSVPPosts = true
        
        do {
            let rsvpPosts = try await dbManager.fetchUserRSVPDiscoverPosts(for: userId)
            userRSVPPosts = rsvpPosts
        } catch {
            print("Failed to load user RSVP posts: \(error)")
            userRSVPPosts = []
        }
        
        isLoadingRSVPPosts = false
    }
    
    @MainActor
    private func loadFollowingStatus() async {
        guard dbManager.isAuthenticated else { 
            print("User not authenticated, setting isFollowing to false")
            isFollowing = false
            return 
        }
        
        guard !isCurrentUser else {
            print("This is current user, setting isFollowing to false")
            isFollowing = false
            return 
        }
        
        do {
            print("Loading following status for user: \(userId)")
            let following = try await dbManager.fetchFollowing()
            let wasFollowing = isFollowing
            isFollowing = following.contains { $0.user.id == userId }
            print("Following status for user \(userId): \(isFollowing) (was: \(wasFollowing))")
        } catch {
            print("Failed to load following status: \(error)")
            isFollowing = false
        }
    }
    
    @MainActor
    private func toggleFollowStatus() async {
        guard !isCurrentUser else { 
            print("Cannot follow/unfollow current user")
            return 
        }
        
        guard dbManager.isAuthenticated else {
            print("User not authenticated, cannot toggle follow status")
            return
        }
        
        let previousFollowingState = isFollowing
        isUpdatingFollowStatus = true
        
        print("Toggling follow status for user \(userId). Current state: \(isFollowing)")
        
        do {
            if isFollowing {
                print("Attempting to unfollow user: \(userId)")
                try await dbManager.unfollowUser(userId: userId)
                isFollowing = false
                print("Successfully unfollowed user: \(userId)")
            } else {
                print("Attempting to follow user: \(userId)")
                try await dbManager.followUser(userId: userId)
                isFollowing = true
                print("Successfully followed user: \(userId)")
            }
            
            // Refresh user stats for the viewed user to update follower count
            print("Refreshing user stats for viewed user after follow state change")
            await loadUserStats()
            
            // Refresh following status to ensure consistency
            await loadFollowingStatus()
            
            // Post notification to refresh ProfileTabView stats (current user's stats)
            print("Posting notification to refresh current user's stats")
            NotificationCenter.default.post(name: Notification.Name("UserStatsDidChange"), object: nil)
            
            // Post notification to refresh following lists
            print("Posting notification to refresh following lists")
            NotificationCenter.default.post(name: Notification.Name("FollowingListDidChange"), object: nil)
            
            // Also post a specific notification for the viewed user if needed
            print("Posting notification for viewed user stats change")
            NotificationCenter.default.post(name: Notification.Name("ViewedUserStatsDidChange"), object: ["userId": userId])
            
        } catch {
            print("Failed to toggle follow status: \(error)")
            // Revert the UI state on error
            isFollowing = previousFollowingState
            
            // TODO: Show error alert to user
            // For now, we'll just log the error and revert the state
        }
        
        isUpdatingFollowStatus = false
        print("Finished toggle follow status. Final state: \(isFollowing)")
    }
}

// MARK: - Supporting Views

// Stats display view with optional navigation for following/followers
struct UserStatsDisplayView: View {
    let stats: UserStats
    let userId: String
    
    var body: some View {
        VStack(spacing: 16) {
            // First row: Crates and Exchanges (non-interactive)
            HStack(spacing: 32) {
                StatDisplayItemView(value: stats.cratesCount, title: "Crates")
                StatDisplayItemView(value: stats.exchangesCount, title: "Exchanges")
            }
            
            // Second row: Following and Followers (temporarily disabled)
            HStack(spacing: 16) {
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
            
            // Third row: Total Records Owned (non-interactive)
            VStack(spacing: 4) {
                Text("\(stats.totalRecordsCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Records Owned")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.sonexSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 16)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ViewedUserStatsDidChange"))) { notification in
            if let userInfo = notification.object as? [String: String],
               let notificationUserId = userInfo["userId"],
               notificationUserId == userId {
                print("UserStatsDisplayView: Received notification to refresh for user: \(userId)")
                // The parent view will handle the actual refresh since stats is passed down
            }
        }
    }
}

struct StatDisplayItemView: View {
    let value: Int
    let title: String
    
    var body: some View {
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
}

// User-specific discover post preview card (non-interactive)
struct UserDiscoverPostPreviewCard: View {
    let post: DiscoverPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with type
            HStack(spacing: 4) {
                Image(systemName: post.type.iconName)
                    .font(.caption)
                    .foregroundStyle(post.type.color)
                
                Text(post.type.displayName)
                    .font(.caption2)
                    .foregroundStyle(post.type.color)
                
                Spacer()
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

// User-specific RSVP post preview card (non-interactive)
struct UserRSVPPostPreviewCard: View {
    let postWithRSVP: DiscoverPostWithRSVP
    
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

// Note: RSVPStatus extension is already defined in SonexDBManager with public properties

// MARK: - User-specific Following/Followers Overlay Views

struct UserFollowingOverlayView: View {
    let userId: String
    @Environment(\.dismiss) private var dismiss
    private let dbManager = SonexDBManager.shared
    @State private var following: [FriendshipRelation] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var userProfile: SonexUser?
    
    var body: some View {
        ZStack {
            Color.sonexCharcoal.ignoresSafeArea()
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Color.sonexAmber)
                    Text("Loading following...")
                        .foregroundStyle(.white.opacity(0.6))
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
            } else if following.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Text("Not following anyone yet")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("This user isn't following anyone")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List(following) { relation in
                    NavigationLink(destination: UserDetailsView(userId: relation.user.userId)) {
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
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(Color.sonexSurface)
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("\(userProfile?.displayName ?? "User") Following")
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
        .onAppear {
            Task {
                await loadData()
            }
        }
    }
    
    @MainActor
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        async let userTask: () = loadUserProfile()
        async let followingTask: () = loadFollowing()
        
        await userTask
        await followingTask
        
        isLoading = false
    }
    
    @MainActor
    private func loadUserProfile() async {
        do {
            let profile = try await dbManager.fetchUserById(userId)
            userProfile = profile
        } catch {
            print("Failed to load user profile: \(error)")
        }
    }
    
    @MainActor
    private func loadFollowing() async {
        do {
            // Note: This would require a new DB method to fetch following for a specific user
            // For now, if it's the current user, we can use the existing method
            if let currentUserId = dbManager.userID, currentUserId == userId {
                let fetchedFollowing = try await dbManager.fetchFollowing()
                following = fetchedFollowing
                print("UserFollowingOverlayView: Loaded \(following.count) following relationships for current user")
            } else {
                // For other users, we would need a specific API endpoint
                // For now, show empty state
                following = []
                print("UserFollowingOverlayView: Cannot fetch following for non-current user yet")
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading following: \(error)")
        }
    }
}

struct UserFollowersOverlayView: View {
    let userId: String
    @Environment(\.dismiss) private var dismiss
    private let dbManager = SonexDBManager.shared
    @State private var followers: [FriendshipRelation] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var userProfile: SonexUser?
    
    var body: some View {
        ZStack {
            Color.sonexCharcoal.ignoresSafeArea()
            
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
                    
                    Text("This user has no followers")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List(followers) { relation in
                    NavigationLink(destination: UserDetailsView(userId: relation.user.userId)) {
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
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(Color.sonexSurface)
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("\(userProfile?.displayName ?? "User") Followers")
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
        .onAppear {
            Task {
                await loadData()
            }
        }
    }
    
    @MainActor
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        async let userTask: () = loadUserProfile()
        async let followersTask: () = loadFollowers()
        
        await userTask
        await followersTask
        
        isLoading = false
    }
    
    @MainActor
    private func loadUserProfile() async {
        do {
            let profile = try await dbManager.fetchUserById(userId)
            userProfile = profile
        } catch {
            print("Failed to load user profile: \(error)")
        }
    }
    
    @MainActor
    private func loadFollowers() async {
        do {
            // Note: This would require a new DB method to fetch followers for a specific user
            // For now, if it's the current user, we can use a similar approach
            if let currentUserId = dbManager.userID, currentUserId == userId {
                // We would need a fetchFollowers method in dbManager
                // For now, show empty state since this method doesn't exist yet
                followers = []
                print("UserFollowersOverlayView: Cannot fetch followers - method not implemented yet")
            } else {
                // For other users, we would need a specific API endpoint
                followers = []
                print("UserFollowersOverlayView: Cannot fetch followers for non-current user yet")
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading followers: \(error)")
        }
    }
}

#Preview {
    UserDetailsView(userId: "sample-user-id")
}
