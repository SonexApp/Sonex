//
//  SonexDock.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//
import SonexShared
import SwiftUI

struct SonexDock: View {
    @Environment(TabRouter.self) private var router
    @Namespace private var dockNamespace

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(SonexTab.allCases) { tab in
                StandardDockItem(
                    tab: tab,
                    isSelected: router.selectedTab == tab,
                    namespace: dockNamespace,
                    onTap: { router.navigate(to: tab) }
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(0.08),
                            lineWidth: 0.5
                        )
                }
        }
        .shadow(color: .black.opacity(0.5), radius: 24, y: 8)
        .padding(.horizontal, 24)
    }
}

// MARK: - Standard dock item (Crates, Discover, Exchange, Profile)

private struct StandardDockItem: View {
    let tab: SonexTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    // Amber pill slides under the active icon
                    if isSelected {
                        Capsule()
                            .fill(Color.sonexAmber.opacity(0.18))
                            .frame(width: 44, height: 28)
                            .matchedGeometryEffect(
                                id: "dock-indicator",
                                in: namespace
                            )
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(
                            isSelected ? Color.sonexAmber : Color.white.opacity(0.45)
                        )
                        .frame(width: 44, height: 28)
                }

                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(
                        isSelected ? Color.sonexAmber : Color.white.opacity(0.35)
                    )
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
    }
}

// MARK: - Primary dock item (Scan / Tap)
// Elevated above the dock surface, larger hit area, always amber-tinted

private struct PrimaryDockItem: View {
    let tab: SonexTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                            ? Color.sonexAmber
                            : Color.white.opacity(0.1)
                        )
                        .frame(width: 52, height: 52)
                        .shadow(
                            color: isSelected
                                ? Color.sonexAmber.opacity(0.4)
                                : .clear,
                            radius: 12,
                            y: 4
                        )

                    Image(systemName: tab.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(
                            isSelected ? Color.black : Color.white.opacity(0.6)
                        )
                }
                .offset(y: -8) // lifts the button above dock baseline

                Text(tab.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(
                        isSelected ? Color.sonexAmber : Color.white.opacity(0.35)
                    )
                    .offset(y: -8)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
