import Foundation
import Combine
import Firebase
import FirebaseAuth

// MARK: - Error Handling Service Protocol

/// Protocol defining the public interface for the error handling service
protocol ErrorHandlingServiceProtocol: AnyObject {
    /// The current error being displayed to the user
    var currentError: AppError? { get }
    
    /// Formatted display error for UI components
    var displayError: DisplayError? { get }
    
    /// Flag to indicate if an error is being presented
    var isShowingError: Bool { get }
    
    /// Report an error to the centralized error handling system
    func reportError(_ error: AppError)
    
    /// Report an error from a legacy error type
    func reportError<E: Error>(_ error: E)
    
    /// Clear the current error state
    func clearError()
    
    /// Handle a Result type, extracting either the success value or reporting the error
    func handleResult<T>(_ result: Result<T, Error>, successHandler: (T) -> Void)
    
    /// Handle an optional error, reporting it if non-nil
    @discardableResult
    func handleOptionalError(_ error: Error?) -> Bool
}

// MARK: - Authentication Service Protocol

/// Protocol defining the public interface for the authentication service
protocol AuthenticationServiceProtocol {
    /// The currently authenticated Firebase user, if any
    var currentUser: FirebaseAuth.User? { get }
    
    /// Whether a user is currently authenticated
    var isAuthenticated: Bool { get }
    
    /// The current authentication error, if any
    var authError: AuthError? { get }
    
    /// Publisher for observing user changes
    var userPublisher: AnyPublisher<FirebaseAuth.User?, Never> { get }
    
    /// Publisher for observing authentication state changes
    var authStatePublisher: AnyPublisher<Bool, Never> { get }
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async -> Result<FirebaseAuth.User, AuthError>
    
    /// Create a new user with email and password
    func signUp(email: String, password: String, name: String) async -> Result<FirebaseAuth.User, AuthError>
    
    /// Sign out the current user
    func signOut() -> Result<Void, AuthError>
    
    /// Reset password for an email
    func resetPassword(for email: String) async -> Result<Void, AuthError>
    
    /// Update the user's display name
    func updateUserDisplayName(_ name: String) async -> Result<Void, AuthError>
    
    /// Update the user's email
    func updateUserEmail(_ email: String) async -> Result<Void, AuthError>
    
    /// Delete the current user's account
    func deleteAccount() async -> Result<Void, AuthError>
}

// MARK: - Audio Service Protocol

/// Protocol defining the public interface for the audio service
protocol AudioServiceProtocol {
    /// Whether audio is currently playing
    var isPlaying: Bool { get }
    
    /// Current playback time
    var currentTime: TimeInterval { get }
    
    /// Total duration of the current audio
    var duration: TimeInterval { get }
    
    /// The currently playing song, if any
    var currentSong: Song? { get }
    
    /// Play a specific song
    func playSong(_ song: Song) throws
    
    /// Pause playback
    func pausePlayback()
    
    /// Resume playback
    func resumePlayback()
    
    /// Stop playback completely
    func stopPlayback()
    
    /// Seek to a specific position
    func seek(to position: TimeInterval)
}

// These protocols will be expanded as we continue refactoring
// Additional protocols for managers will be added in subsequent steps 