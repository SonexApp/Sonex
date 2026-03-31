//
//  ScanTabView.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

// ScanTabView.swift
import SwiftUI

struct ScanTabView: View {
    var body: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            VStack(spacing: 16) {
                // Pulsing ring to suggest the NFC scan animation
                ZStack {
                    Circle()
                        .strokeBorder(Color.red.opacity(0.15), lineWidth: 1)
                        .frame(width: 120, height: 120)
                    Circle()
                        .strokeBorder(Color.red.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 80, height: 80)
                    Image(systemName: "wave.3.right.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.red)
                }
                Text("Tap to Scan")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("NFCManager + camera overlay goes here")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        // No NavigationStack or title — this tab is always full bleed
    }
}
