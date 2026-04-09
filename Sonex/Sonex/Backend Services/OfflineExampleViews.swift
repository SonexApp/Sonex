import SwiftUI
import SonexShared
/// Example view showing how to use SonexDBManager's offline capabilities
struct OfflineCapableProfileView: View {
    @State private var dbManager = SonexDBManager.shared
    @State private var userProfile: SonexUser?
    @State private var crates: [Crate] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingOfflineIndicator = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Offline indicator
                if !dbManager.isOnline {
                    HStack {
                        Image(systemName: "wifi.slash")
                        Text("Offline - Using cached data")
                    }
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                // Sync status
                if dbManager.pendingOperationsCount > 0 {
                    HStack {
                        Image(systemName: "clock")
                        Text("\(dbManager.pendingOperationsCount) changes waiting to sync")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                if isLoading {
                    ProgressView("Loading...")
                } else {
                    List {
                        // User profile section
                        Section("Profile") {
                            if let profile = userProfile {
                                VStack(alignment: .leading) {
                                    Text(profile.displayName ?? profile.username)
                                        .font(.headline)
                                    if let bio = profile.bio {
                                        Text(bio)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        // Crates section
                        Section("Crates") {
                            ForEach(crates) { crate in
                                HStack {
                                    Text(crate.name)
                                    Spacer()
                                    if crate.for_sale {
                                        Text("For Sale")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Error display
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await refreshData()
                        }
                    }
                    .disabled(!dbManager.isOnline)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sync") {
                        Task {
                            await syncPendingChanges()
                        }
                    }
                    .disabled(!dbManager.isOnline || dbManager.pendingOperationsCount == 0)
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load user profile (from cache if offline)
            userProfile = try await dbManager.fetchCurrentUser()
            
            // Load crates (from cache if offline)
            crates = try await dbManager.fetchCrates()
            
        } catch SonexDBError.noNetworkConnection {
            if !dbManager.canWorkOffline {
                errorMessage = "No cached data available. Please connect to the internet to load your profile."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func refreshData() async {
        guard dbManager.isOnline else {
            errorMessage = "Cannot refresh while offline"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Force refresh from server
            userProfile = try await dbManager.refreshUserProfileCache()
            crates = try await dbManager.refreshCratesCache()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func syncPendingChanges() async {
        guard dbManager.isOnline else {
            errorMessage = "Cannot sync while offline"
            return
        }
        
        do {
            try await dbManager.syncAllData()
            // Reload data after successful sync
            await loadData()
        } catch {
            errorMessage = "Failed to sync: \(error.localizedDescription)"
        }
    }
}

/// Example of how to handle offline profile editing
struct OfflineProfileEditView: View {
    @State private var dbManager = SonexDBManager.shared
    @State private var username = ""
    @State private var displayName = ""
    @State private var bio = ""
    @State private var isEditing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Info") {
                    TextField("Username", text: $username)
                    TextField("Display Name", text: $displayName)
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button("Save Changes") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(isEditing)
                }
                
                // Status messages
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                if let success = successMessage {
                    Section {
                        Text(success)
                            .foregroundColor(.green)
                    }
                }
                
                // Offline status
                if !dbManager.isOnline {
                    Section {
                        HStack {
                            Image(systemName: "wifi.slash")
                            Text("Changes will be saved locally and synced when online")
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .disabled(isEditing)
        }
    }
    
    private func saveProfile() async {
        isEditing = true
        errorMessage = nil
        successMessage = nil
        
        let updateFields = ProfileUpdatePayload(
            username: username.isEmpty ? nil : username,
            displayName: displayName.isEmpty ? nil : displayName,
            avatarUrl: nil,
            bio: bio.isEmpty ? nil : bio
        )
        
        do {
            try await dbManager.updateProfile(updateFields)
            
            if dbManager.isOnline {
                successMessage = "Profile updated successfully"
            } else {
                successMessage = "Profile saved locally. Will sync when online."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isEditing = false
    }
}

#Preview("Offline Profile View") {
    OfflineCapableProfileView()
}

#Preview("Offline Profile Edit") {
    OfflineProfileEditView()
}
