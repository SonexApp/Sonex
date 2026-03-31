//
//  AuthView.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

import SwiftUI

struct AuthView: View {

    @Environment(SupabaseManager.self) private var supabaseManager

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color.sonexCharcoal.ignoresSafeArea()

            VStack(spacing: 32) {

                // Wordmark
                VStack(spacing: 6) {
                    Image(systemName: "wave.3.right.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.sonexAmber)

                    Text("Sonex")
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)

                    Text("Vinyl cataloging and peer exchange")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.top, 60)

                // Fields
                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .sonexFieldStyle()
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("Password", text: $password)
                        .sonexFieldStyle()
                        .textContentType(.password)
                }
                .padding(.horizontal, 32)

                // Error
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Sign in
                Button {
                    Task { await signIn() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Sign In")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.sonexAmber)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 32)
                .disabled(isLoading || email.isEmpty || password.isEmpty)

                Spacer()
            }
        }
    }

    private func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabaseManager.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Field style modifier

private extension View {
    func sonexFieldStyle() -> some View {
        self
            .padding(14)
            .background(Color.sonexSurface)
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            }
    }
}
