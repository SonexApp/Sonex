//
//  TabContentRouter.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

import SwiftUI
import SonexShared

struct TabContentRouter: View {

    @Environment(TabRouter.self) private var router

    var body: some View {
        ZStack {
            CollectionTabView()
                .navigationStackWrapper(title: "My Crates")
                .tabVisible(router.selectedTab == .collection)

            ScanTabView()
                .tabVisible(router.selectedTab == .scan)

            DiscoverTabView()
                .navigationStackWrapper(title: "Discover")
                .tabVisible(router.selectedTab == .discover)

            ExchangeTabView()
                .navigationStackWrapper(title: "Exchange")
                .tabVisible(router.selectedTab == .exchange)

            ProfileTabView()
                .navigationStackWrapper(title: "Profile")
                .tabVisible(router.selectedTab == .profile)
        }
    }
}

// MARK: - View modifiers

private extension View {

    func navigationStackWrapper(title: String) -> some View {
        NavigationStack {
            self
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.large)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .tint(Color.sonexAmber)
    }

    func tabVisible(_ isVisible: Bool) -> some View {
        self
            .opacity(isVisible ? 1 : 0)
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
    }
}
