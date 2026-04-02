//
//  AuthView.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

import SwiftUI

struct AuthView: View {
    
    // Use the singleton instead of Environment
    private let dbManager = SonexDBManager.shared

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var isSignUpMode = false

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

                    Text(isSignUpMode ? "Join the vinyl community" : "Vinyl cataloging and peer exchange")
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
                        .textContentType(isSignUpMode ? .newPassword : .password)
                    
                    if isSignUpMode {
                        SecureField("Confirm Password", text: $confirmPassword)
                            .sonexFieldStyle()
                            .textContentType(.newPassword)
                            .overlay(alignment: .trailing) {
                                if !confirmPassword.isEmpty {
                                    Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(passwordsMatch ? .green : .red)
                                        .padding(.trailing, 14)
                                }
                            }
                    }
                }
                .padding(.horizontal, 32)

                // Validation Messages
                if isSignUpMode && !confirmPassword.isEmpty && !passwordsMatch {
                    Text("Passwords do not match")
                        .font(.caption)
                        .foregroundStyle(Color.red.opacity(0.8))
                        .padding(.horizontal, 32)
                }
                
                // Error
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Primary Action Button
                Button {
                    Task { 
                        if isSignUpMode {
                            await signUp()
                        } else {
                            await signIn()
                        }
                    }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text(isSignUpMode ? "Sign Up" : "Sign In")
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
                .disabled(isFormInvalid || isLoading)
                
                // Toggle between Sign In and Sign Up
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSignUpMode.toggle()
                        errorMessage = nil
                        clearFields()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isSignUpMode ? "Already have an account?" : "Don't have an account?")
                            .foregroundStyle(.white.opacity(0.6))
                        Text(isSignUpMode ? "Sign In" : "Sign Up")
                            .foregroundStyle(Color.sonexAmber)
                    }
                    .font(.system(size: 14, weight: .medium))
                }
                .padding(.top, 12)

                Spacer()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormInvalid: Bool {
        if isSignUpMode {
            return email.isEmpty || password.isEmpty || confirmPassword.isEmpty || !passwordsMatch
        } else {
            return email.isEmpty || password.isEmpty
        }
    }
    
    private var passwordsMatch: Bool {
        password == confirmPassword
    }
    
    // MARK: - Methods

    private func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await dbManager.signIn(email: email, password: password)
            // Session is automatically cached in the dbManager
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func signUp() async {
        isLoading = true
        errorMessage = nil
        
        // Validate passwords match
        guard passwordsMatch else {
            errorMessage = "Passwords do not match"
            isLoading = false
            return
        }
        
        // Validate password strength (optional)
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            isLoading = false
            return
        }
        
        do {
            _ = try await dbManager.signUpWithEmail(email: email, password: password)
            // Session is automatically cached in the dbManager if signup includes immediate sign-in
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func clearFields() {
        email = ""
        password = ""
        confirmPassword = ""
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
