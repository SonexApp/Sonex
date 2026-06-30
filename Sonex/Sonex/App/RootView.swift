//
//  RootView.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

import SwiftUI
import SonexShared

struct RootView: View {
    @Environment(TabRouter.self) private var router
    @State private var dbManager = SonexDBManager.shared
    @State private var backgroundNFCManager = BackgroundNFCManager.shared
    @State private var showingAlbumDetails = false
    @State private var detailsVinyl: VinylEntry?
    @State private var isAppActive = true

    var body: some View {
        ZStack(alignment: .bottom) {
            TabContentRouter()
                .ignoresSafeArea()

            if !router.isDockHidden {
                SonexDock()
                    .padding(.bottom, 8)
                    .transition(
                        .move(edge: .bottom)
                        .combined(with: .opacity)
                    )
            }
        }
        .animation(
            .spring(response: 0.3, dampingFraction: 0.8),
            value: router.isDockHidden
        )
        .sheet(isPresented: $showingAlbumDetails) {
            if let vinyl = detailsVinyl {
                AlbumDetailsView(vinyl: vinyl)
            }
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .onChange(of: dbManager.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                router.navigate(to: .collection)
            }
        }
        .onChange(of: showingAlbumDetails) { _, isShowing in
            print("🔄 Album details sheet state changed: \(isShowing)")
        }
        .onReceive(NotificationCenter.default.publisher(for: .backgroundNFCDetected)) { notification in
            print("📡 Received backgroundNFCDetected notification")
            handleBackgroundNFCDetection(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            isAppActive = true
            print("🟢 App became active")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            isAppActive = false
            print("🟡  App will resign active")
        }
    }

    // MARK: - Deep link + App Clip URL handling
    //
    // Handles two URL schemes:
    // 1. App Clip experience URLs: https://sonex.app/tag/{nfcTagHash}
    // 2. NFC redirect URLs: sonex://album/{nfcTagHash}
    //
    // For NFC URLs, we look up the vinyl entry and show album details

    private func handleIncomingURL(_ url: URL) {
        print("🔗 Received URL: \(url)")
        
        // Handle sonex:// scheme (from NFC tags)
        if url.scheme == "sonex" {
            handleSonexURL(url)
            return
        }
        
        // Handle https://sonex.app URLs (App Clip experience)
        guard url.host == "sonex.app",
              url.pathComponents.count == 3,
              url.pathComponents[1] == "tag" else { return }

        let _ = url.pathComponents[2]
        router.navigate(to: .scan)
        // NFCManager picks up the hash and resolves it
        // without requiring a physical tap
        // nfcManager.resolveTagHash(tagHash)  ← wire up in Week 2
    }
    
    private func handleSonexURL(_ url: URL) {
        // sonex://album/{nfcTagHash}
        guard url.host == "album",
              url.pathComponents.count == 2 else {
            print("❌ Invalid Sonex URL format: \(url)")
            return
        }
        
        let nfcTagHash = url.pathComponents[1]
        lookupAndShowAlbum(for: nfcTagHash)
    }
    
    private func handleBackgroundNFCDetection(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { 
            print("❌ No userInfo in background NFC notification")
            return 
        }
        
        print("📱 Handling background NFC detection")
        
        // Handle both direct tagHash and URL formats
        if let tagHash = userInfo["tagHash"] as? String {
            print("🏷️ Got tag hash directly: \(tagHash)")
            lookupAndShowAlbum(for: tagHash)
        } else if let url = userInfo["url"] as? URL {
            print("🔗 Got URL from background NFC: \(url)")
            handleIncomingURL(url)
        } else {
            print("❌ No valid data in background NFC notification")
        }
    }
    
    private func lookupAndShowAlbum(for tagHash: String) {
        print("🔍 Looking up vinyl for NFC tag: \(tagHash)")
        
        Task {
            do {
                // Look up the vinyl entry by NFC tag hash
                let vinyl = try await dbManager.checkNFCTagRegistration(tagHash: tagHash)
                
                await MainActor.run {
                    if let vinyl = vinyl {
                        print("✅ Found vinyl: \(vinyl.title) by \(vinyl.artist)")
                        print("📱 Current app state - Active: \(isAppActive), Sheet showing: \(showingAlbumDetails)")
                        
                        // Ensure clean state before showing new details
                        if showingAlbumDetails {
                            showingAlbumDetails = false
                            print("🔄 Dismissing existing sheet first")
                        }
                        
                        // Set the vinyl data
                        detailsVinyl = vinyl
                        
                        // Use a slight delay to ensure UI state is clean, especially when app is launching
                        let delay = isAppActive ? 0.1 : 0.5
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            print("🎵 Presenting album details for: \(vinyl.title)")
                            showingAlbumDetails = true
                        }
                    } else {
                        print("❌ No vinyl found for NFC tag: \(tagHash)")
                        // Could show an error or redirect to scan tab
                        router.navigate(to: .scan)
                    }
                }
            } catch {
                print("❌ Error looking up vinyl: \(error.localizedDescription)")
                await MainActor.run {
                    // Fallback to scan tab
                    router.navigate(to: .scan)
                }
            }
        }
    }
    
    // MARK: - Debug Helper
    /// For testing background NFC detection manually
    private func testBackgroundNFCDetection(tagHash: String = "test-hash-123") {
        print("🧪 Testing background NFC detection with hash: \(tagHash)")
        
        // Simulate the notification that would be sent by BackgroundNFCManager
        NotificationCenter.default.post(
            name: .backgroundNFCDetected,
            object: nil,
            userInfo: ["tagHash": tagHash]
        )
    }
}
