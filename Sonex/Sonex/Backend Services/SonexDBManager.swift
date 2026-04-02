
import SwiftUI
import Supabase

@MainActor
@Observable
class SonexDBManager {
    static let shared = SonexDBManager()
    private let supabase: SupabaseClient
    
    // Session cache
    private(set) var currentSession: Session?
    private(set) var isAuthenticated: Bool = false
    
    private init() {
        supabase = SupabaseClient(supabaseURL: URL(string: "https://bbjtznnxrreuzurgtuyz.supabase.co")!, supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJianR6bm54cnJldXp1cmd0dXl6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5ODMzMTksImV4cCI6MjA5MDU1OTMxOX0.hrHqnA_rlEc51OROgU0ALAqRCjzWcPYGEj7UaP56qYc"
        )
        print("Supabase client initialized with url")
        
        // Check for existing session
        Task {
            await checkCurrentSession()
        }
        
        // Listen for auth state changes
        Task {
            await listenToAuthChanges()
        }
    }
    
    func signUpWithEmail(email: String, password: String) async throws -> AuthResponse {
        do {
            let authResponse = try await supabase.auth.signUp(email: email, password: password)
            if let session = authResponse.session {
                await updateSessionCache(session)
            }
            return authResponse
        } catch {
            let errorMessage = error.localizedDescription.lowercased()
            throw(NSError(domain: "Auth", code: 500, userInfo: [NSLocalizedDescriptionKey: "\(errorMessage)"]))
        }
    }
    
    func signIn(email: String, password: String) async throws -> Session {
        let session = try await supabase.auth.signIn(email: email, password: password)
        await updateSessionCache(session)
        return session
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
        await clearSessionCache()
    }
    
    // MARK: - Session Management
    
    private func updateSessionCache(_ session: Session) async {
        self.currentSession = session
        self.isAuthenticated = true
    }
    
    private func clearSessionCache() async {
        self.currentSession = nil
        self.isAuthenticated = false
    }
    
    private func checkCurrentSession() async {
        do {
            let session = try await supabase.auth.session
            await updateSessionCache(session)
        } catch {
            await clearSessionCache()
        }
    }
    
    private func listenToAuthChanges() async {
        for await authState in supabase.auth.authStateChanges {
            switch authState.event {
            case .signedIn:
                if let session = authState.session {
                    await updateSessionCache(session)
                }
            case .signedOut:
                await clearSessionCache()
            case .tokenRefreshed:
                if let session = authState.session {
                    await updateSessionCache(session)
                }
            default:
                break
            }
        }
    }
    
    // MARK: - Public Session Access
    
    var userID: String? {
        return currentSession?.user.id.uuidString
    }
    
    var userEmail: String? {
        return currentSession?.user.email
    }
    
    // MARK: - Public Authentication Methods
    
    func signOutFromApp() async throws {
        try await signOut()
    }
    
}
