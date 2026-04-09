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
    @State private var isLoadingProfile = false
    @State private var showProfileCreation = false
    
    var body: some View {
        ZStack {
            Color.sonexCharcoal.ignoresSafeArea()
            VStack(spacing: 24) {
                // User Info Section
                VStack(spacing: 12) {
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
                        
                        Text("User stats · Wishlist · Friends · Settings")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
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
                
                // Sign Out Button
                Button {
                    showingSignOutAlert = true
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.red.opacity(0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 32)
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
                
                Spacer()
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showProfileCreation) {
            ProfileCreationView {
                showProfileCreation = false
                // Refresh profile after creation
                Task {
                    await checkUserProfile()
                }
            }
        }
        .onAppear {
            Task {
                await checkUserProfile()
            }
        }
        .onChange(of: dbManager.isAuthenticated) { oldValue, newValue in
            if newValue && !oldValue {
                // User just got authenticated, check their profile
                Task {
                    await checkUserProfile()
                }
            } else if !newValue {
                // User signed out, clear profile
                userProfile = nil
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

// MARK: - Profile Creation View

struct ProfileCreationView: View {
    private let dbManager = SonexDBManager.shared
    let onComplete: () -> Void
    
    @State private var username = ""
    @State private var displayName = ""
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
        
        do {
            _ = try await dbManager.createUserProfile(
                username: trimmedUsername,
                displayName: trimmedDisplayName
            )
            
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

// MARK: - Preview

#Preview("Profile Tab - No Profile") {
    NavigationView {
        ProfileTabView()
    }
}

#Preview("Profile Creation") {
    ProfileCreationView {
        print("Profile created")
    }
}
