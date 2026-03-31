//
//  SupabaseManager.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

import Foundation
import Observation

@Observable
final class SupabaseManager {

    static let shared = SupabaseManager()

    // Observed by TapTracksApp to switch between AuthView and RootView
    var isAuthenticated: Bool = false
    var currentUserId: UUID? = nil

    private init() {
        // In Week 1: initialize the Supabase Swift SDK client here
        // and restore an existing session from Keychain if present.
        //
        // let client = SupabaseClient(
        //     supabaseURL: URL(string: Secrets.supabaseURL)!,
        //     supabaseKey: Secrets.supabaseAnonKey
        // )
    }

    func signIn(email: String, password: String) async throws {
        // In Week 1: replace with real Supabase Auth call
        // let session = try await client.auth.signIn(
        //     email: email, password: password
        // )
        // currentUserId = UUID(uuidString: session.user.id.uuidString)
        // isAuthenticated = true

        // Placeholder: simulate network delay
        try await Task.sleep(for: .seconds(1))
        isAuthenticated = true
    }

    func signOut() async throws {
        // try await client.auth.signOut()
        isAuthenticated = false
        currentUserId = nil
    }
}
