import Foundation

/// A service locator pattern implementation that manages app-wide dependencies
/// and provides a centralized access point for services and managers.
class ServiceLocator {
    /// Shared singleton instance
    static let shared = ServiceLocator()
    
    /// Private storage for registered services
    private var services: [String: Any] = [:]
    
    /// Flag to indicate if the service locator has been initialized with default services
    private var isInitialized = false
    
    /// Private initializer for singleton pattern
    private init() {}
    
    /// Register a service implementation for a specific protocol type
    /// - Parameters:
    ///   - service: The concrete service implementation
    ///   - type: The protocol type the service implements
    func register<T>(_ service: Any, for type: T.Type) {
        let key = String(describing: type)
        services[key] = service
    }
    
    /// Resolve a service by its protocol type
    /// - Parameter type: The protocol type to resolve
    /// - Returns: The registered service implementation or nil if not found
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return services[key] as? T
    }
    
    /// Check if a service is registered for a specific type
    /// - Parameter type: The protocol type to check
    /// - Returns: True if a service is registered for the type
    func isRegistered<T>(_ type: T.Type) -> Bool {
        let key = String(describing: type)
        return services[key] != nil
    }
    
    /// Remove a registered service
    /// - Parameter type: The protocol type to remove
    func unregister<T>(_ type: T.Type) {
        let key = String(describing: type)
        services.removeValue(forKey: key)
    }
    
    /// Initialize the service locator with default services
    /// This method links to the current app architecture without modifying it
    /// When the refactoring is complete, this will be replaced with proper DI
    func registerExistingServices(from appState: AppState) {
        guard !isInitialized else { return }
        
        // Register all existing services from the AppState
        // Register concrete implementations under their original types for compatibility
        register(appState.userManager, for: UserManager.self)
        register(appState.sessionManager, for: SessionManager.self)
        register(appState.songManager, for: SongManager.self)
        register(appState.taskManager, for: TaskManager.self)
        register(appState.newsManager, for: NewsManager.self)
        
        // Register services under their protocol interfaces
        // This allows future code to depend on the abstractions rather than concrete implementations
        
        // For AuthenticationService, always use the shared instance
        register(AuthenticationService.shared, for: AuthenticationServiceProtocol.self)  
        register(AuthenticationService.shared, for: AuthenticationService.self)
        
        // For AudioService, use the instance from AppState for backward compatibility
        register(appState.audioService, for: AudioServiceProtocol.self)
        
        // For ErrorHandlingService, always use the shared instance
        register(ErrorHandlingService.shared, for: ErrorHandlingServiceProtocol.self)
        register(ErrorHandlingService.shared, for: ErrorHandlingService.self)
        
        // Also register the original service implementations for backward compatibility
        register(appState.audioService, for: AudioService.self)
        
        // Mark as initialized
        isInitialized = true
        
        print("ServiceLocator: Registered existing services from AppState")
    }
    
    /// Reset the service locator (mainly for testing purposes)
    func reset() {
        services.removeAll()
        isInitialized = false
    }
} 