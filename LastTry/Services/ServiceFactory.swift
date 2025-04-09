import Foundation
import Firebase
import FirebaseAuth

/// A factory class responsible for creating properly configured service instances
/// This centralizes service creation logic and dependency injection
class ServiceFactory {
    
    /// Create and configure the authentication service
    /// - Returns: A fully configured AuthenticationServiceProtocol instance
    static func createAuthenticationService() -> AuthenticationServiceProtocol {
        // Create the dependencies first
        let errorService = createErrorHandlingService()
        
        // Create the service with its dependencies
        let authService = AuthenticationService(errorHandlingService: errorService)
        return authService
    }
    
    /// Create and configure the audio service
    /// - Returns: A fully configured AudioServiceProtocol instance
    static func createAudioService() -> AudioServiceProtocol {
        // Create the dependencies first
        let errorService = createErrorHandlingService()
        
        // Create the service with its dependencies
        let audioService = AudioService(errorHandlingService: errorService)
        return audioService
    }
    
    /// Create and configure the error handling service
    /// - Returns: A fully configured ErrorHandlingServiceProtocol instance
    static func createErrorHandlingService() -> ErrorHandlingServiceProtocol {
        // This is a root service with no dependencies
        return ErrorHandlingService.shared
    }
    
    /// Create and configure the user manager
    /// - Returns: A fully configured UserManagerProtocol instance
    static func createUserManager() -> UserManagerProtocol {
        // Create dependencies
        let authService = createAuthenticationService()
        let errorService = createErrorHandlingService()
        
        // Create the manager with its dependencies
        return UserManager(
            authService: authService,
            errorService: errorService
        )
    }
    
    /// Create and configure the task manager
    /// - Returns: A fully configured TaskManagerProtocol instance
    static func createTaskManager() -> TaskManagerProtocol {
        // Create dependencies
        let errorService = createErrorHandlingService()
        
        // Create the manager with its dependencies
        return TaskManager(errorService: errorService)
    }
    
    /// Create and configure the session manager
    /// - Returns: A fully configured SessionManager instance
    static func createSessionManager() -> SessionManager {
        // Create dependencies
        let errorService = createErrorHandlingService()
        
        // Create the manager with its dependencies
        return SessionManager(errorService: errorService)
    }
    
    /// Create and configure the song manager
    /// - Returns: A fully configured SongManager instance
    static func createSongManager() -> SongManager {
        // Create dependencies
        let errorService = createErrorHandlingService()
        
        // Create the manager with its dependencies
        return SongManager(errorService: errorService)
    }
    
    /// Create and configure the news manager
    /// - Returns: A fully configured NewsManagerProtocol instance
    static func createNewsManager() -> NewsManagerProtocol {
        // Create dependencies
        let errorService = createErrorHandlingService()
        
        // Create the manager with its dependencies
        return NewsManager(errorService: errorService)
    }
    
    /// Initialize all services and register them with the ServiceLocator
    /// This should be called during application launch
    static func registerAllServices() {
        // Clear the service locator first (in case it's being reinitialized)
        ServiceLocator.shared.reset()
        
        // Create all services
        let errorService = createErrorHandlingService()
        let authService = createAuthenticationService()
        let audioService = createAudioService()
        
        // Create all managers
        let userManager = createUserManager()
        let taskManager = createTaskManager()
        let sessionManager = createSessionManager()
        let songManager = createSongManager()
        let newsManager = createNewsManager()
        
        // Register services with ServiceLocator
        let locator = ServiceLocator.shared
        
        // Register services under their protocol interfaces
        locator.register(errorService, for: ErrorHandlingServiceProtocol.self)
        locator.register(authService, for: AuthenticationServiceProtocol.self)
        locator.register(audioService, for: AudioServiceProtocol.self)
        
        // Register managers under their protocol interfaces
        locator.register(userManager, for: UserManagerProtocol.self)
        locator.register(taskManager, for: TaskManagerProtocol.self)
        locator.register(sessionManager, for: SessionManager.self)
        locator.register(songManager, for: SongManager.self)
        locator.register(newsManager, for: NewsManagerProtocol.self)
        
        // Also register concrete implementations for backward compatibility
        locator.register(errorService, for: ErrorHandlingService.self)
        locator.register(authService, for: AuthenticationService.self)
        locator.register(audioService, for: AudioService.self)
        locator.register(userManager, for: UserManager.self)
        locator.register(taskManager, for: TaskManager.self)
        
        print("ServiceFactory: All services registered with ServiceLocator")
    }
} 