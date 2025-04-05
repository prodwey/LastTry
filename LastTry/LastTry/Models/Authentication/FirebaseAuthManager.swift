import Foundation
import Firebase
import FirebaseAuth
import Combine

/// Manages Firebase authentication operations
class FirebaseAuthManager {
    static let shared = FirebaseAuthManager()
    
    // Current Firebase Auth user
    @Published private(set) var firebaseUser: FirebaseAuth.User?
    
    // Auth state publisher for reactive UI updates
    var authStatePublisher: AnyPublisher<FirebaseAuth.User?, Never> {
        return $firebaseUser.eraseToAnyPublisher()
    }
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    private init() {
        // Start monitoring Firebase auth state changes
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            self?.firebaseUser = user
        }
    }
    
    deinit {
        // Remove auth state listener when this object is deallocated
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Auth Methods
    
    /// Sign up a new user with email and password
    /// - Returns: A tuple containing the user or error
    func signUp(withEmail email: String, password: String) async -> (User?, Error?) {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            return (authResult.user, nil)
        } catch {
            print("Firebase sign up error: \(error.localizedDescription)")
            return (nil, error)
        }
    }
    
    /// Sign in an existing user with email and password
    /// - Returns: A tuple containing the user or error
    func signIn(withEmail email: String, password: String) async -> (User?, Error?) {
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            return (authResult.user, nil)
        } catch {
            print("Firebase sign in error: \(error.localizedDescription)")
            return (nil, error)
        }
    }
    
    /// Sign out the current user
    /// - Returns: Error if sign out failed
    func signOut() -> Error? {
        do {
            try Auth.auth().signOut()
            return nil
        } catch {
            print("Firebase sign out error: \(error.localizedDescription)")
            return error
        }
    }
    
    /// Update the user's profile information
    /// - Parameters:
    ///   - displayName: The user's display name
    /// - Returns: Error if update failed
    func updateProfile(displayName: String) async -> Error? {
        guard let user = Auth.auth().currentUser else {
            return NSError(domain: "FirebaseAuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
        }
        
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        
        do {
            try await changeRequest.commitChanges()
            return nil
        } catch {
            print("Firebase update profile error: \(error.localizedDescription)")
            return error
        }
    }
    
    /// Update the user's email address
    /// - Parameters:
    ///   - email: The new email address
    /// - Returns: Error if update failed
    func updateEmail(to email: String) async -> Error? {
        guard let user = Auth.auth().currentUser else {
            return NSError(domain: "FirebaseAuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
        }
        
        do {
            try await user.updateEmail(to: email)
            return nil
        } catch {
            print("Firebase update email error: \(error.localizedDescription)")
            return error
        }
    }
    
    /// Update the user's password
    /// - Parameters:
    ///   - password: The new password
    /// - Returns: Error if update failed
    func updatePassword(to password: String) async -> Error? {
        guard let user = Auth.auth().currentUser else {
            return NSError(domain: "FirebaseAuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
        }
        
        do {
            try await user.updatePassword(to: password)
            return nil
        } catch {
            print("Firebase update password error: \(error.localizedDescription)")
            return error
        }
    }
    
    /// Send a password reset email
    /// - Parameters:
    ///   - email: The email address to send the reset link to
    /// - Returns: Error if the request failed
    func sendPasswordReset(to email: String) async -> Error? {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return nil
        } catch {
            print("Firebase password reset error: \(error.localizedDescription)")
            return error
        }
    }
    
    /// Get the current user ID
    /// - Returns: The current user's ID, or nil if no user is signed in
    var currentUserID: String? {
        return Auth.auth().currentUser?.uid
    }
    
    /// Check if a user is currently signed in
    /// - Returns: True if a user is signed in, false otherwise
    var isUserSignedIn: Bool {
        return Auth.auth().currentUser != nil
    }
} 