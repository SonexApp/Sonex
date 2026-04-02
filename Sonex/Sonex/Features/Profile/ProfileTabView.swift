//
//  ProfileTabView.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

// ProfileTabView.swift
import SwiftUI

struct ProfileTabView: View {
    private let dbManager = SonexDBManager.shared
    @State private var showingSignOutAlert = false
    
    var body: some View {
        ZStack {
            Color.sonexCharcoal.ignoresSafeArea()
            VStack(spacing: 24) {
                // User Info Section
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.sonexAmber)
                    
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
                    
                    Text("User stats · Wishlist · Friends · Settings")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
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
    }
}
