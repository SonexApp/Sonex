//
//  AuthView.swift
//  Sonex
//
//  Created by Ricardo Payares on 3/31/26.
//

import SwiftUI
internal import Auth
import SonexShared

struct AuthView: View {
    
    // Use the singleton instead of Environment
    private let dbManager = SonexDBManager.shared

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var isSignUpMode = false
    @State private var showProfileCreation = false
    @State private var profileCreationCompleted = false
    @State private var showEmailConfirmation = false

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
                            isSignUpMode.toggle()
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
        .sheet(isPresented: $showProfileCreation) {
            ProfileCreationView {
                showProfileCreation = false
                profileCreationCompleted = true
            }
        }
        .sheet(isPresented: $showEmailConfirmation) {
            EmailConfirmationView(email: email) {
                showEmailConfirmation = false
            }
        }
        .onChange(of: dbManager.isAuthenticated) { oldValue, newValue in
            if newValue && !oldValue && !showProfileCreation {
                // User just got authenticated (likely from email confirmation)
                // Check if they need to complete profile creation
                Task {
                    await checkAndShowProfileCreation()
                }
            }
        }
        .onOpenURL { url in
            handleIncomingURL(url)
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

    private func checkAndShowProfileCreation() async {
        do {
            // Try to fetch the current user profile
            _ = try await dbManager.fetchCurrentUser()
            // If we get here, user already has a profile, don't show creation
            print("User already has a profile, skipping profile creation")
        } catch {
            // User doesn't have a profile yet, show profile creation
            print("User needs to create a profile: \(error)")
            await MainActor.run {
                showProfileCreation = true
            }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        // Handle authentication callback URLs
        if url.scheme == "sonex" && url.host == "auth-callback" {
            // Supabase automatically handles the callback and updates the session
            // The authentication state changes will be picked up by the auth listener
            // in SonexDBManager, which will trigger the onChange modifier below
            print("Received authentication callback URL: \(url)")
        }
    }

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
        // Reset profile creation state for new sign-ups
        profileCreationCompleted = false
        
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
            let authResponse = try await dbManager.signUpWithEmail(email: email, password: password)
            print("Auth response: \(authResponse)")
            // Check if the user was automatically signed in after signup
            if authResponse.session != nil {
                // User is signed in, show profile creation
                showProfileCreation = true
            } else {
                // User needs to verify email first
                showEmailConfirmation = true
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func clearFields() {
        email = ""
        password = ""
        confirmPassword = ""
        // Reset profile creation state for new sign-ups
        profileCreationCompleted = false
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

// MARK: - Email Confirmation View

struct EmailConfirmationView: View {
    let email: String
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.sonexCharcoal.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Icon and Title
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.sonexAmber)
                        
                        Text("Check your email")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    
                    // Message
                    VStack(spacing: 12) {
                        Text("We've sent a confirmation link to:")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                        
                        Text(email)
                            .font(.headline)
                            .foregroundStyle(Color.sonexAmber)
                            .multilineTextAlignment(.center)
                        
                        Text("Click the link in the email to verify your account and complete signup.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    
                    Spacer()
                    
                    // Done Button
                    Button {
                        onDismiss()
                    } label: {
                        Text("Got it")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.sonexAmber)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Email Sent")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundStyle(Color.sonexAmber)
                }
            }
        }
    }
}
// MARK: - String Extension

private extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Preview

#Preview("Sign In") {
    AuthView()
}

#Preview("Sign Up") {
    struct PreviewWrapper: View {
        @State private var authView = AuthView()
        
        var body: some View {
            authView
                .onAppear {
                    // Access the private state using reflection or a test helper
                    // For now, users can tap the "Sign Up" button in the preview
                }
        }
    }
    
    return PreviewWrapper()
}

#Preview("Email Confirmation") {
    EmailConfirmationView(email: "user@example.com") {
        print("Dismissed")
    }
}

#Preview("Profile Creation") {
    ProfileCreationView {
        print("Profile created")
    }
}

