//
//  CollectionTabView.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

// CollectionTabView.swift
import SwiftUI

struct CollectionTabView: View {
    var body: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.red)
                Text("Crates")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("SceneKit milk crate wall goes here")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .navigationTitle("My Crates")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
