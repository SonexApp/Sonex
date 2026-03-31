//
//  SonexAPp.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

import SwiftUI
import SonexShared

@main
struct SonexApp: App {

    @State private var router = TabRouter()
    @State private var supabaseManager = SupabaseManager.shared
    @State private var nfcManager = NFCManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if supabaseManager.isAuthenticated {
                    RootView()
                } else {
                    AuthView()
                }
            }
            .environment(router)
            .environment(supabaseManager)
            .environment(nfcManager)
            .preferredColorScheme(.dark)
            .tint(Color.sonexAmber)
        }
    }
}
