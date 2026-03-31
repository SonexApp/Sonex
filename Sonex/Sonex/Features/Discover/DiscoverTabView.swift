//
//  DiscoverTabView.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

// DiscoverTabView.swift
import SwiftUI

struct DiscoverTabView: View {
    var body: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "map.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.red)
                Text("Discover")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("MapKit + geo pins + activity log goes here")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
