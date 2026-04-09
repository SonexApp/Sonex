//
//  ConfirmationView.swift
//  Sonex
//
//  Created by Assistant on 4/8/26.
//

import SwiftUI
import SonexShared

struct ConfirmationView: View {
    @Bindable var registrationData: VinylRegistrationData
    let onComplete: (VinylEntry) -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.sonexAmber.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.sonexAmber)
            }
            
            // Success Message
            VStack(spacing: 12) {
                Text("Vinyl Registered!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Your vinyl has been added to your collection")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                if registrationData.forSale {
                    Text("and listed for sale at $\(Int(registrationData.askingPrice ?? 0))")
                        .font(.subheadline)
                        .foregroundStyle(Color.sonexAmber)
                }
            }
            
            Spacer()
            
            // Done Button
            Button("Done") {
                // This would typically create a VinylEntry object
                // For now, we'll pass a placeholder
                let placeholderVinyl = VinylEntry(
                    ownerId: "placeholder",
                    title: registrationData.title,
                    artist: registrationData.artist,
                    forSale: registrationData.forSale,
                    askingPrice: registrationData.askingPrice
                )
                onComplete(placeholderVinyl)
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(Color.sonexCharcoal)
            .background(Color.sonexAmber)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    ConfirmationView(registrationData: VinylRegistrationData()) { _ in }
        .background(Color.sonexCharcoal)
}