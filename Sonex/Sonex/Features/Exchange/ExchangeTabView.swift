//
//  ExchangeTabView.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

// ExchangeTabView.swift
import SwiftUI

struct ExchangeTabView: View {
    var body: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.red)
                Text("Exchange")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Sell cart + QR session goes here")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .navigationTitle("Exchange")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
