//
//  ProfileTabView.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

// ProfileTabView.swift
import SwiftUI

struct ProfileTabView: View {
    var body: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.red)
                Text("Profile")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("User stats · Wishlist · Friends · Settings")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
