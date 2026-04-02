//
//  ConfigurationErrorView.swift
//  Sonex
//
//  Created by Assistant on 4/1/26.
//

import SwiftUI

struct ConfigurationErrorView: View {
    let errorMessage: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Configuration Error")
                .font(.title)
                .fontWeight(.bold)
            
            Text(errorMessage)
                .multilineTextAlignment(.center)
                .font(.body)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            
            Button("Copy Error Message") {
                UIPasteboard.general.string = errorMessage
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    ConfigurationErrorView(errorMessage: "Sample error message for preview")
}