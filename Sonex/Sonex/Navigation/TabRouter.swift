//
//  TabRouter.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//
import SonexShared
import SwiftUI

@Observable
final class TabRouter {
    var selectedTab: SonexTab = .collection
    var isDockHidden: Bool = false

    func navigate(to tab: SonexTab) {
        selectedTab = tab
    }

    func hideDock() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isDockHidden = true
        }
    }

    func showDock() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isDockHidden = false
        }
    }
}
