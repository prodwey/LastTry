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
    
    /// Static method to report an error
    static func report(error: Any)
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
    
    /// Clear any current authentication errors
    func clearError()
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
    
    /// Publisher for observing current time changes
    var currentTimePublisher: AnyPublisher<TimeInterval, Never> { get }
    
    /// Publisher for observing playback state changes
    var isPlayingPublisher: AnyPublisher<Bool, Never> { get }
    
    /// Publisher for observing current song changes
    var currentSongPublisher: AnyPublisher<Song?, Never> { get }
    
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

// MARK: - User Manager Protocol

/// Protocol defining the public interface for the user manager
protocol UserManagerProtocol: AnyObject {
    /// The currently authenticated user, if any
    var currentUser: User? { get }
    
    /// Whether a user is currently logged in
    var isLoggedIn: Bool { get }
    
    /// The current user error, if any
    var authError: UserError? { get }
    
    /// Load user data from Firebase user
    func loadUserFromFirebase(_ firebaseUser: FirebaseAuth.User)
    
    /// Sign up user using the authentication service
    func signUp(name: String, email: String, password: String, dateOfBirth: Date, role: UserRole)
    
    /// Login using the authentication service
    func login(email: String, password: String)
    
    /// Logout using the authentication service
    func logout()
    
    /// Update user profile information
    func updateProfile(name: String, email: String, dateOfBirth: Date, role: UserRole) -> Bool
    
    /// Save user data to persistent storage
    func saveUserData()
    
    /// Set the current user directly
    func setCurrentUser(_ user: User?)
    
    /// Set the login state directly
    func setLoggedIn(_ isLoggedIn: Bool)
}

// MARK: - Task Manager Protocol

/// Protocol defining the public interface for the task manager
protocol TaskManagerProtocol: AnyObject {
    /// All tasks managed by this manager
    var tasks: [Task] { get }
    
    /// The current task error, if any
    var taskError: TaskError? { get }
    
    /// Load tasks from persistent storage
    func loadTasks()
    
    /// Add a new task
    func addTask(title: String, description: String, priority: TaskPriority, 
                dueDate: Date?, assignedTo: String?, createdBy: String) -> Bool
    
    /// Toggle the completion status of a task
    func toggleTaskCompletion(taskId: String) -> Bool
    
    /// Remove a task
    func removeTask(taskId: String) -> Bool
    
    /// Update an existing task
    func updateTask(task: Task) -> Bool
    
    /// Get tasks sorted by priority
    func sortedByPriority() -> [Task]
    
    /// Get tasks assigned to a specific user
    func tasksAssignedTo(userId: String) -> [Task]
    
    /// Set the tasks collection directly
    func setTasks(_ tasks: [Task])
    
    /// Set the task error directly
    func setTaskError(_ error: TaskError?)
    
    /// Clear any task error
    func clearError()
}

// MARK: - News Manager Protocol

/// Protocol defining the public interface for the news manager
protocol NewsManagerProtocol: AnyObject {
    /// All news items managed by this manager
    var newsItems: [NewsItem] { get }
    
    /// Fetch news items from the remote source
    func fetchNews()
    
    /// Get news items filtered by category
    func getNewsByCategory(category: NewsCategory) -> [NewsItem]
}

// These protocols will be expanded as we continue refactoring
// Additional protocols for managers will be added in subsequent steps 