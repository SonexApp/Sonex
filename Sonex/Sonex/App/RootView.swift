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
    private let dbManager = SonexDBManager.shared

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
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .onChange(of: dbManager.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                router.navigate(to: .collection)
            }
        }
    }

    // MARK: - Deep link + App Clip URL handling
    //
    // App Clip experience URLs arrive here when the user has the
    // full app installed. The URL format is:
    //   https://sonex.app/tag/{nfcTagHash}
    //
    // We extract the hash, navigate to the Scan tab, and let
    // NFCManager resolve it against Supabase as if it were a
    // fresh tap.

    private func handleIncomingURL(_ url: URL) {
        guard
            url.host == "sonex.app",
            url.pathComponents.count == 3,
            url.pathComponents[1] == "tag"
        else { return }

        let _ = url.pathComponents[2]
        router.navigate(to: .scan)
        // NFCManager picks up the hash and resolves it
        // without requiring a physical tap
        // nfcManager.resolveTagHash(tagHash)  ← wire up in Week 2
    }
}
