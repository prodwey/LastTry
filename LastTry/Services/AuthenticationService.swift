import Foundation
import Firebase
import FirebaseAuth
import Combine

// Custom error types for authentication
enum AuthError: Error, LocalizedError, Equatable {
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
    
    // Implementation of Equatable for cases with associated values
    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.signInFailed(let lhsMessage), .signInFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.signUpFailed(let lhsMessage), .signUpFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.signOutFailed(let lhsMessage), .signOutFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.userNotFound, .userNotFound),
             (.invalidCredentials, .invalidCredentials),
             (.networkError, .networkError),
             (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
}

// Main authentication service that handles Firebase Auth operations
class AuthenticationService: ObservableObject, AuthenticationServiceProtocol {
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
            // Avoid capturing self in @Sendable closure
            await MainActor.run {
                self.authError = authError
            }
            return .failure(authError)
        }
    }
    
    /// Create a new user with email and password
    func signUp(email: String, password: String, name: String) async -> Result<FirebaseAuth.User, AuthError> {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Update the profile with the provided name
            let changeRequest = authResult.user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
            
            return .success(authResult.user)
        } catch {
            let authError = handleFirebaseError(error)
            // Avoid capturing self in @Sendable closure
            let authServiceError = authError
            await MainActor.run {
                self.authError = authServiceError
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
            // No need for MainActor here since this is not async
            self.authError = authError
            return .failure(authError)
        }
    }
    
    /// Update a user's display name
    func updateUserDisplayName(_ name: String) async -> Result<Void, AuthError> {
        guard let user = Auth.auth().currentUser else {
            return .failure(.userNotFound)
        }
        
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = name
        
        do {
            try await changeRequest.commitChanges()
            return .success(())
        } catch {
            let authError = handleFirebaseError(error)
            await MainActor.run {
                self.authError = authError
            }
            return .failure(authError)
        }
    }
    
    /// Update user's email
    func updateUserEmail(_ email: String) async -> Result<Void, AuthError> {
        guard let user = Auth.auth().currentUser else {
            return .failure(.userNotFound)
        }
        
        do {
            try await user.sendEmailVerification(beforeUpdatingEmail: email)
            return .success(())
        } catch {
            let authError = handleFirebaseError(error)
            // Avoid capturing self in @Sendable closure
            let authServiceError = authError
            await MainActor.run {
                self.authError = authServiceError
            }
            return .failure(authError)
        }
    }
    
    /// Reset password for an email
    func resetPassword(for email: String) async -> Result<Void, AuthError> {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return .success(())
        } catch {
            let authError = handleFirebaseError(error)
            await MainActor.run {
                self.authError = authError
            }
            return .failure(authError)
        }
    }
    
    /// Delete the current user's account
    func deleteAccount() async -> Result<Void, AuthError> {
        guard let user = Auth.auth().currentUser else {
            return .failure(.userNotFound)
        }
        
        do {
            try await user.delete()
            return .success(())
        } catch {
            let authError = handleFirebaseError(error)
            await MainActor.run {
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
            
            // Use dispatch to main queue instead of Task with MainActor to avoid compiler issues
            DispatchQueue.main.async {
                self.currentUser = user
                self.isAuthenticated = user != nil
                print("AuthenticationService: Auth state changed, user is \(user != nil ? "authenticated" : "not authenticated")")
            }
        }
    }
    
    private func handleFirebaseError(_ error: Error) -> AuthError {
        // Get the NSError version of the error
        let nsError = error as NSError
        
        // Check for specific error codes from Firebase Auth
        if nsError.domain == AuthErrorDomain {
            // Use AuthErrorCode directly, not AuthErrorCode.Code
            if let errorCode = AuthErrorCode(rawValue: nsError.code) {
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
                    break
                }
            }
        }
        
        // For other errors, provide a generic message based on the description
        if nsError.domain.contains("Firebase") {
            if nsError.localizedDescription.contains("sign in") {
                return .signInFailed(nsError.localizedDescription)
            } else if nsError.localizedDescription.contains("create user") {
                return .signUpFailed(nsError.localizedDescription)
            }
        }
        
        return .unknown
    }
} 