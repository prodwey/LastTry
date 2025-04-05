import Foundation
import Firebase
import FirebaseAuth
import Combine

// Custom error types for authentication
enum AuthError: Error, LocalizedError {
    case signInFailed(String)
    case signUpFailed(String)
    case signOutFailed(String)
    case userNotFound
    case invalidCredentials
    case networkError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .signUpFailed(let message):
            return "Sign up failed: \(message)"
        case .signOutFailed(let message):
            return "Sign out failed: \(message)"
        case .userNotFound:
            return "User not found"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network error, please try again"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

// Main authentication service that handles Firebase Auth operations
class AuthenticationService: ObservableObject {
    // Published properties for observing auth state and errors
    @Published private(set) var currentUser: FirebaseAuth.User?
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var authError: AuthError?
    
    // Publishers for components to subscribe to
    var userPublisher: AnyPublisher<FirebaseAuth.User?, Never> {
        $currentUser.eraseToAnyPublisher()
    }
    
    var authStatePublisher: AnyPublisher<Bool, Never> {
        $isAuthenticated.eraseToAnyPublisher()
    }
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        // Remove auth state listener when service is deallocated
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Public Methods
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async -> Result<FirebaseAuth.User, AuthError> {
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            return .success(authResult.user)
        } catch {
            let authError = handleFirebaseError(error)
            DispatchQueue.main.async {
                self.authError = authError
            }
            return .failure(authError)
        }
    }
    
    /// Create a new user with email and password
    func signUp(email: String, password: String) async -> Result<FirebaseAuth.User, AuthError> {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            return .success(authResult.user)
        } catch {
            let authError = handleFirebaseError(error)
            DispatchQueue.main.async {
                self.authError = authError
            }
            return .failure(authError)
        }
    }
    
    /// Sign out the current user
    func signOut() -> Result<Void, AuthError> {
        do {
            try Auth.auth().signOut()
            return .success(())
        } catch {
            let authError = AuthError.signOutFailed(error.localizedDescription)
            DispatchQueue.main.async {
                self.authError = authError
            }
            return .failure(authError)
        }
    }
    
    /// Update a user's profile (display name)
    func updateUserProfile(displayName: String) async -> Result<Void, AuthError> {
        guard let user = Auth.auth().currentUser else {
            return .failure(.userNotFound)
        }
        
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        
        do {
            try await changeRequest.commitChanges()
            return .success(())
        } catch {
            let authError = handleFirebaseError(error)
            DispatchQueue.main.async {
                self.authError = authError
            }
            return .failure(authError)
        }
    }
    
    /// Update user's email
    func updateEmail(to newEmail: String) async -> Result<Void, AuthError> {
        guard let user = Auth.auth().currentUser else {
            return .failure(.userNotFound)
        }
        
        do {
            try await user.updateEmail(to: newEmail)
            return .success(())
        } catch {
            let authError = handleFirebaseError(error)
            DispatchQueue.main.async {
                self.authError = authError
            }
            return .failure(authError)
        }
    }
    
    /// Update user's password
    func updatePassword(currentPassword: String, newPassword: String) async -> Result<Void, AuthError> {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            return .failure(.userNotFound)
        }
        
        // First re-authenticate
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        
        do {
            try await user.reauthenticate(with: credential)
            try await user.updatePassword(to: newPassword)
            return .success(())
        } catch {
            let authError = handleFirebaseError(error)
            DispatchQueue.main.async {
                self.authError = authError
            }
            return .failure(authError)
        }
    }
    
    /// Send password reset email to the specified email address
    func sendPasswordReset(to email: String) async -> Result<Void, AuthError> {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return .success(())
        } catch {
            let authError = handleFirebaseError(error)
            DispatchQueue.main.async {
                self.authError = authError
            }
            return .failure(authError)
        }
    }
    
    /// Clear any current auth errors
    func clearError() {
        authError = nil
    }
    
    // MARK: - Private Methods
    
    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.currentUser = user
                self.isAuthenticated = user != nil
                print("AuthenticationService: Auth state changed, user is \(user != nil ? "authenticated" : "not authenticated")")
            }
        }
    }
    
    private func handleFirebaseError(_ error: Error) -> AuthError {
        if let errorCode = AuthErrorCode.Code(rawValue: (error as NSError).code) {
            switch errorCode {
            case .userNotFound:
                return .userNotFound
            case .wrongPassword:
                return .invalidCredentials
            case .invalidEmail:
                return .invalidCredentials
            case .networkError:
                return .networkError
            case .emailAlreadyInUse:
                return .signUpFailed("Email is already in use")
            case .weakPassword:
                return .signUpFailed("Password is too weak")
            default:
                return .unknown
            }
        }
        
        // If we can't match with a specific Firebase error, return a generic one with the message
        if let nsError = error as? NSError {
            if nsError.domain.contains("Firebase") {
                if nsError.localizedDescription.contains("sign in") {
                    return .signInFailed(nsError.localizedDescription)
                } else if nsError.localizedDescription.contains("create user") {
                    return .signUpFailed(nsError.localizedDescription)
                }
            }
        }
        
        return .unknown
    }
} 