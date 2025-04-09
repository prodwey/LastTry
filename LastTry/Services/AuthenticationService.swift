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
    case none
    
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
        case .none:
            return nil
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
             (.none, .none),
             (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
}

// Main authentication service that handles Firebase Auth operations
class AuthenticationService: ObservableObject, AuthenticationServiceProtocol {
    // MARK: - Singleton
    
    /// Shared instance for global access
    static let shared = AuthenticationService()
    
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
    
    // ErrorHandlingService reference
    private let errorHandlingService: ErrorHandlingServiceProtocol
    
    // MARK: - Initialization
    
    /// Default initializer that uses the shared ErrorHandlingService
    private init() {
        self.errorHandlingService = ErrorHandlingService.shared
        setupAuthStateListener()
        print("AuthenticationService: Initialized shared instance")
    }
    
    /// Dependency injection initializer for testing or custom configurations
    init(errorHandlingService: ErrorHandlingServiceProtocol) {
        self.errorHandlingService = errorHandlingService
        setupAuthStateListener()
        print("AuthenticationService: Initialized with custom error handling service")
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
            // Report error to centralized error handling service
            errorHandlingService.reportError(authError)
            
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
            // Report error to centralized error handling service
            errorHandlingService.reportError(authError)
            
            // Update local state
            await MainActor.run {
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
            // Report error to centralized error handling service
            errorHandlingService.reportError(authError)
            
            // Update local state
            self.authError = authError
            return .failure(authError)
        }
    }
    
    /// Update a user's display name
    func updateUserDisplayName(_ name: String) async -> Result<Void, AuthError> {
        guard let user = Auth.auth().currentUser else {
            let error = AuthError.userNotFound
            errorHandlingService.reportError(error)
            await MainActor.run { self.authError = error }
            return .failure(error)
        }
        
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = name
        
        do {
            try await changeRequest.commitChanges()
            return .success(())
        } catch {
            let authError = handleFirebaseError(error)
            errorHandlingService.reportError(authError)
            await MainActor.run { self.authError = authError }
            return .failure(authError)
        }
    }
    
    /// Update user's email
    func updateUserEmail(_ email: String) async -> Result<Void, AuthError> {
        guard let user = Auth.auth().currentUser else {
            let error = AuthError.userNotFound
            errorHandlingService.reportError(error)
            await MainActor.run { self.authError = error }
            return .failure(error)
        }
        
        do {
            try await user.sendEmailVerification(beforeUpdatingEmail: email)
            return .success(())
        } catch {
            let authError = handleFirebaseError(error)
            errorHandlingService.reportError(authError)
            await MainActor.run { self.authError = authError }
            return .failure(authError)
        }
    }
    
    /// Reset password for an email
    func resetPassword(for email: String) async -> Result<Void, AuthError> {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            // Report success notification
            NotificationCenter.default.post(name: .passwordResetEmailSent, object: nil)
            // Clear any auth errors
            await MainActor.run { self.authError = AuthError.none }
            return .success(())
        } catch {
            let authError = handleFirebaseError(error)
            errorHandlingService.reportError(authError)
            await MainActor.run { self.authError = authError }
            return .failure(authError)
        }
    }
    
    /// Delete the current user's account
    func deleteAccount() async -> Result<Void, AuthError> {
        guard let user = Auth.auth().currentUser else {
            let error = AuthError.userNotFound
            errorHandlingService.reportError(error)
            await MainActor.run { self.authError = error }
            return .failure(error)
        }
        
        do {
            try await user.delete()
            return .success(())
        } catch {
            let authError = handleFirebaseError(error)
            errorHandlingService.reportError(authError)
            await MainActor.run { self.authError = authError }
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

// MARK: - Notifications

extension Notification.Name {
    /// Notification sent when password reset email is successfully sent
    static let passwordResetEmailSent = Notification.Name("passwordResetEmailSent")
}

// MARK: - Authentication Helper

/// Global access to authentication functionality
enum AuthenticationManager {
    /// Access the shared authentication service instance
    static var service: AuthenticationServiceProtocol {
        return AuthenticationService.shared
    }
    
    /// Check if a user is currently authenticated
    static var isAuthenticated: Bool {
        return service.isAuthenticated
    }
    
    /// Get the current authenticated user, if any
    static var currentUser: FirebaseAuth.User? {
        return service.currentUser
    }
    
    /// Clear any authentication errors
    static func clearError() {
        service.clearError()
    }
    
    /// Sign in with email and password
    static func signIn(email: String, password: String) async -> Result<FirebaseAuth.User, AuthError> {
        return await service.signIn(email: email, password: password)
    }
    
    /// Sign up a new user with email, password and name
    static func signUp(email: String, password: String, name: String) async -> Result<FirebaseAuth.User, AuthError> {
        return await service.signUp(email: email, password: password, name: name)
    }
    
    /// Sign out the current user
    static func signOut() -> Result<Void, AuthError> {
        return service.signOut()
    }
    
    /// Reset password for an email
    static func resetPassword(for email: String) async -> Result<Void, AuthError> {
        return await service.resetPassword(for: email)
    }
    
    // MARK: - Error Handling Integration
    
    /// Sign in with email and password, reporting errors automatically
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - onSuccess: Callback with the User object on success
    static func signInWithErrorHandling(email: String, password: String, onSuccess: @escaping (FirebaseAuth.User) -> Void) async {
        let result = await signIn(email: email, password: password)
        
        switch result {
        case .success(let user):
            onSuccess(user)
        case .failure(let error):
            // Errors are already reported by the service
            // This is just a convenient way to handle the result
            print("Authentication failed: \(error.localizedDescription)")
        }
    }
    
    /// Sign up with email, password and name, reporting errors automatically
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - name: User's display name
    ///   - onSuccess: Callback with the User object on success
    static func signUpWithErrorHandling(email: String, password: String, name: String, onSuccess: @escaping (FirebaseAuth.User) -> Void) async {
        let result = await signUp(email: email, password: password, name: name)
        
        switch result {
        case .success(let user):
            onSuccess(user)
        case .failure(let error):
            // Errors are already reported by the service
            print("Sign up failed: \(error.localizedDescription)")
        }
    }
    
    /// Reset password for email, reporting errors automatically
    /// - Parameters:
    ///   - email: User's email address
    ///   - onSuccess: Callback on success
    static func resetPasswordWithErrorHandling(for email: String, onSuccess: @escaping () -> Void) async {
        let result = await resetPassword(for: email)
        
        if case .success = result {
            onSuccess()
        }
        // Errors are already reported by the service
    }
} 