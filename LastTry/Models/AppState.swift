import Foundation
import SwiftUI
import CoreData
import Firebase
import FirebaseAuth
import Combine
import AVFoundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case portugueseBR = "Brazilian Portuguese"
    case english = "English"
    
    var id: String { self.rawValue }
    
    var code: String {
        switch self {
        case .portugueseBR: return "pt-BR"
        case .english: return "en"
        }
    }
}

class AppState: ObservableObject {
    // Manager dependencies using protocol interfaces
    @Published var userManager: UserManagerProtocol
    @Published var sessionManager: SessionManager
    @Published var songManager: SongManager
    @Published var taskManager: TaskManagerProtocol
    @Published var newsManager: NewsManagerProtocol
    
    // Service dependencies using protocol interfaces
    @Published var authService: AuthenticationServiceProtocol
    @Published var audioService: AudioServiceProtocol
    @Published var errorService: ErrorHandlingServiceProtocol
    
    // Simple authentication state tracking - now derived from authService
    @Published var isAuthenticated: Bool = false
    
    @Published var selectedLanguage: AppLanguage = .portugueseBR
    @Published var tabSelection: Int = 0
    @Published var currentPlayingSong: Song? = nil
    @Published var isPlaying: Bool = false
    @Published var currentPlaybackPosition: TimeInterval = 0
    @Published var audioError: AudioError? = nil
    
    // Resource monitoring
    @Published var memoryStatus: ResourceThreshold = .normal
    @Published var diskStatus: ResourceThreshold = .normal
    
    private let coreDataManager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        print("AppState: Initializing")
        
        // Get services from ServiceLocator instead of creating them directly
        let locator = ServiceLocator.shared
        
        // Get services
        guard let errorService = locator.resolve(ErrorHandlingServiceProtocol.self),
              let authService = locator.resolve(AuthenticationServiceProtocol.self),
              let audioService = locator.resolve(AudioServiceProtocol.self),
              let userManager = locator.resolve(UserManagerProtocol.self),
              let taskManager = locator.resolve(TaskManagerProtocol.self),
              let newsManager = locator.resolve(NewsManagerProtocol.self),
              let sessionManager = locator.resolve(SessionManager.self),
              let songManager = locator.resolve(SongManager.self) else {
            
            // Fallback to direct instantiation if ServiceLocator is not properly initialized
            print("AppState: Services not found in ServiceLocator, falling back to direct instantiation")
            self.errorService = ErrorHandlingService.shared
            self.authService = AuthenticationService.shared
            self.audioService = AudioService.shared
            self.userManager = UserManager.shared
            self.sessionManager = SessionManager.shared
            self.songManager = SongManager.shared
            self.taskManager = TaskManager.shared
            self.newsManager = NewsManager.shared
            
            // Check for CoreData migration need on first launch
            checkAndPerformMigration()
            
            // Subscribe to auth state changes from AuthenticationService
            setupAuthStateSubscription()
            
            // Subscribe to audio service state changes
            setupAudioServiceSubscription()
            
            // Start monitoring resources
            setupResourceMonitoring()
            
            // Load initial data
            loadInitialData()
            
            return
        }
        
        // Store service references
        self.errorService = errorService
        self.authService = authService
        self.audioService = audioService
        self.userManager = userManager
        self.sessionManager = sessionManager
        self.songManager = songManager
        self.taskManager = taskManager
        self.newsManager = newsManager
        
        print("AppState: Successfully retrieved services from ServiceLocator")
        
        // Check for CoreData migration need on first launch
        checkAndPerformMigration()
        
        // Subscribe to auth state changes from AuthenticationService
        setupAuthStateSubscription()
        
        // Subscribe to audio service state changes
        setupAudioServiceSubscription()
        
        // Start monitoring resources
        setupResourceMonitoring()
        
        // Load initial data
        loadInitialData()
    }
    
    // MARK: - Example of using ServiceLocator
    
    /// Example method showing how to access a service through the ServiceLocator
    /// This demonstrates the pattern that will be used throughout the refactoring
    func reportErrorUsingServiceLocator(_ error: Error) {
        // We can access the error service either through direct reference (current way)
        errorService.reportError(error)
        
        // Or through the service locator (new way)
        if let errorService = ServiceLocator.shared.resolve(ErrorHandlingServiceProtocol.self) {
            errorService.reportError(error)
        }
        
        // Or use the singleton directly (also new way)
        ErrorHandlingService.shared.reportError(error)
        
        // As we refactor, we'll gradually transition from the first approach to the second or third
    }
    
    // MARK: - Auth State Management
    
    // Setup subscription to the AuthenticationService
    private func setupAuthStateSubscription() {
        print("AppState: Setting up auth state subscription")
        
        getAuthService().authStatePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] isAuthenticated in
                guard let self = self else { return }
                
                // Update our authentication state
                self.isAuthenticated = isAuthenticated
                print("AppState: Auth state changed, user is \(isAuthenticated ? "authenticated" : "not authenticated")")
                
                // Sync with UserManager
                self.getUserManager().setLoggedIn(isAuthenticated)
                
                // Load user data or demo data based on authentication state
                if isAuthenticated {
                    if let firebaseUser = self.getAuthService().currentUser, self.getUserManager().currentUser == nil {
                        // We're authenticated but don't have user data loaded
                        self.getUserManager().loadUserFromFirebase(firebaseUser)
                    }
                } else if self.getUserManager().currentUser == nil {
                    // We're not authenticated and don't have demo data
                    self.loadDemoData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Audio Service Subscription
    
    private func setupAudioServiceSubscription() {
        print("AppState: Setting up audio service subscription")
        
        // Sync AudioService's currentTime with our currentPlaybackPosition
        getAudioService().currentTimePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] time in
                self?.currentPlaybackPosition = time
            }
            .store(in: &cancellables)
        
        // Sync AudioService's isPlaying with our isPlaying
        getAudioService().isPlayingPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] isPlaying in
                self?.isPlaying = isPlaying
            }
            .store(in: &cancellables)
        
        // Sync AudioService's currentSong with our currentPlayingSong
        getAudioService().currentSongPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] song in
                self?.currentPlayingSong = song
            }
            .store(in: &cancellables)
    }
    
    // Check if we need to migrate data from UserDefaults to CoreData
    private func checkAndPerformMigration() {
        if coreDataManager.isFirstLaunch {
            // In a production app, this would perform a comprehensive migration
            // For this demo, we simply mark migration as complete
            print("Core Data is being used for the first time, marking migration as complete")
            coreDataManager.markMigrationAsComplete()
        }
    }
    
    // Load demo data for preview and testing purposes
    public func loadDemoData() {
        print("AppState: Loading demo data")
        
        // Add demo user
        let demoUser = User(
            id: UUID().uuidString,
            name: "João Silva",
            email: "joao@example.com",
            dateOfBirth: Calendar.current.date(from: DateComponents(year: 1990, month: 5, day: 15)) ?? Date(),
            role: .producer
        )
        
        // Save demo user to CoreData
        coreDataManager.performBackgroundTask { context in
            let _ = demoUser.toEntity(in: context)
        }
        
        // Set as current user
        getUserManager().setCurrentUser(demoUser)
        getUserManager().setLoggedIn(true)
        
        // For backward compatibility
        getUserManager().saveUserData()
        
        // Add demo sessions
        let pastDate1 = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        let pastDate2 = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let futureDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        
        let pastSession1ID = UUID().uuidString
        let pastSession1 = Session(
            id: pastSession1ID,
            studio: .studioA,
            mainProducer: demoUser.name,
            additionalProducers: ["Carlos Ferreira"],
            singers: ["Ana Souza", "Rafael Lima"],
            date: pastDate1,
            duration: 180, // 3 hours
            songs: nil
        )
        
        let pastSession2ID = UUID().uuidString
        let pastSession2 = Session(
            id: pastSession2ID,
            studio: .studioB,
            mainProducer: demoUser.name,
            additionalProducers: [],
            singers: ["Mariana Costa"],
            date: pastDate2,
            duration: 120, // 2 hours
            songs: nil
        )
        
        let futureSession = Session(
            id: UUID().uuidString,
            studio: .studioC,
            mainProducer: demoUser.name,
            additionalProducers: ["Pedro Santos"],
            singers: ["Luiza Oliveira", "Thiago Almeida"],
            date: futureDate,
            duration: 240, // 4 hours
            songs: nil
        )
        
        // Save sessions to CoreData
        coreDataManager.performBackgroundTask { context in
            let _ = pastSession1.toEntity(in: context)
            let _ = pastSession2.toEntity(in: context)
            let _ = futureSession.toEntity(in: context)
            
            // Update sessions array on main thread
            DispatchQueue.main.async {
                self.getSessionManager().sessions = [pastSession1, pastSession2, futureSession]
            }
        }
        
        // Add demo tasks
        let task1 = Task(
            id: UUID().uuidString,
            title: "Mix final version of 'Summer Night'",
            description: "Complete the final mix for Ana's new song 'Summer Night'",
            priority: .high,
            createdAt: Date().addingTimeInterval(-86400), // 1 day ago
            dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
            assignedTo: demoUser.id,
            createdBy: demoUser.id,
            isCompleted: false
        )
        
        let task2 = Task(
            id: UUID().uuidString,
            title: "Schedule mastering session",
            description: "Book time with mastering engineer for the new album",
            priority: .medium,
            createdAt: Date().addingTimeInterval(-172800), // 2 days ago
            dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            assignedTo: demoUser.id,
            createdBy: demoUser.id,
            isCompleted: false
        )
        
        let task3 = Task(
            id: UUID().uuidString,
            title: "Order new microphone",
            description: "Order replacement for the broken SM58",
            priority: .low,
            createdAt: Date().addingTimeInterval(-43200), // 12 hours ago
            dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()),
            assignedTo: demoUser.id,
            createdBy: demoUser.id,
            isCompleted: true
        )
        
        getTaskManager().setTasks([task1, task2, task3])
        
        // Add demo songs
        let song1 = Song(
            id: UUID().uuidString,
            name: "Feeling Good",
            fileURL: nil,
            format: .mp3,
            artists: [
                Artist(id: UUID().uuidString, name: "Ana Souza")
            ],
            lyrics: "Birds flying high, you know how I feel...",
            dateCreated: pastDate1,
            fileSize: 4523091,
            duration: 201.5, // 3:21
            sessionId: pastSession1ID
        )
        
        let song2 = Song(
            id: UUID().uuidString,
            name: "Sunset Boulevard",
            fileURL: nil,
            format: .wav,
            artists: [
                Artist(id: UUID().uuidString, name: "Rafael Lima")
            ],
            lyrics: "Walking down that old sunset boulevard...",
            dateCreated: pastDate1,
            fileSize: 12945834,
            duration: 184.3, // 3:04
            sessionId: pastSession1ID
        )
        
        let song3 = Song(
            id: UUID().uuidString,
            name: "Midnight Rain",
            fileURL: nil,
            format: .mp3,
            artists: [
                Artist(id: UUID().uuidString, name: "Mariana Costa")
            ],
            lyrics: "The rain falls softly on my window...",
            dateCreated: pastDate2,
            fileSize: 3854102,
            duration: 240.8, // 4:00
            sessionId: pastSession2ID
        )
        
        getSongManager().songs = [song1, song2, song3]
        
        // Update sessions with songs
        if let index1 = getSessionManager().sessions.firstIndex(where: { $0.id == pastSession1ID }) {
            getSessionManager().sessions[index1].songs = [song1, song2]
        }
        
        if let index2 = getSessionManager().sessions.firstIndex(where: { $0.id == pastSession2ID }) {
            getSessionManager().sessions[index2].songs = [song3]
        }
    }
    
    func playSong(_ song: Song) {
        // Clear any previous error
        audioError = nil
        
        // Try to play the song using the audio service through our accessor method
        do {
            try getAudioService().playSong(song)
        } catch let error {
            // Use the error handling service to report the error
            ErrorReporter.report(error)
            
            // Keep setting the audioError for backward compatibility
            if let audioErr = error as? AudioError {
                audioError = audioErr
            } else {
                audioError = AudioError.playbackError(error.localizedDescription)
            }
            
            print("Audio playback error: \(error.localizedDescription)")
        }
    }
    
    func pausePlayback() {
        getAudioService().pausePlayback()
    }
    
    func resumePlayback() {
        getAudioService().resumePlayback()
    }
    
    func stopPlayback() {
        getAudioService().stopPlayback()
    }
    
    func seekToPosition(_ position: TimeInterval) {
        getAudioService().seek(to: position)
    }
    
    func switchLanguage(to language: AppLanguage) {
        self.selectedLanguage = language
        // In a real app, this would update all text in the app
    }
    
    private func setupResourceMonitoring() {
        // Subscribe to resource notifications
        ResourceMonitor.shared.resourcePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                switch notification.type {
                case .memory:
                    self.memoryStatus = notification.threshold
                    
                    // Log memory warnings in debug builds
                    #if DEBUG
                    if notification.threshold != .normal {
                        print("Memory usage at \(Int(notification.usagePercentage))% - \(notification.threshold)")
                    }
                    #endif
                    
                case .disk:
                    self.diskStatus = notification.threshold
                    
                    // Log disk warnings in debug builds
                    #if DEBUG
                    if notification.threshold != .normal {
                        print("Disk usage at \(Int(notification.usagePercentage))% - \(notification.threshold)")
                    }
                    #endif
                }
                
                // If we're in a critical resource state, reduce memory pressure
                if notification.threshold == .critical {
                    self.handleResourcePressure(type: notification.type)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleResourcePressure(type: ResourceType) {
        // Handle critical resource pressure
        switch type {
        case .memory:
            // Clear non-essential caches
            CacheManager.shared.audioDataCache.clearCache()
            CacheManager.shared.imageCache.clearCache()
            
        case .disk:
            // Clear all caches to free up disk space
            CacheManager.shared.clearAllCaches()
        }
    }
    
    private func loadInitialData() {
        // Load user data
        if getUserManager().currentUser != nil {
            // User is already loaded
        } else if let firebaseUser = getAuthService().currentUser {
            // Load user from Firebase if authenticated
            getUserManager().loadUserFromFirebase(firebaseUser)
        }
        
        // For demo, populate with some data if needed
        if CoreDataManager.shared.isFirstLaunch {
            populateDemoData()
            CoreDataManager.shared.markMigrationAsComplete()
        }
    }
    
    // MARK: - Demo Functionality
    
    func populateDemoData() {
        // Create a demo user
        let demoUser = User(
            id: UUID().uuidString,
            name: "Demo User",
            email: "demo@example.com",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date(),
            role: .producer
        )
        
        // Save the user to CoreData
        let coreDataManager = CoreDataManager.shared
        coreDataManager.performBackgroundTask { context in
            let _ = demoUser.toEntity(in: context)
            
            // Update app state on main thread
            DispatchQueue.main.async {
                self.getUserManager().setCurrentUser(demoUser)
            }
        }
        
        // Create demo sessions
        let pastDate1 = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let pastDate2 = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let futureDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        
        let pastSession1 = Session(
            id: UUID().uuidString,
            studio: .studioA,
            mainProducer: demoUser.name,
            additionalProducers: ["Maria Silva"],
            singers: ["Ana Rodrigues", "Carlos Santos"],
            date: pastDate1,
            duration: 180, // 3 hours
            songs: nil
        )
        
        let pastSession2 = Session(
            id: UUID().uuidString,
            studio: .studioB,
            mainProducer: demoUser.name,
            additionalProducers: ["João Costa"],
            singers: ["Mariana Ferreira"],
            date: pastDate2,
            duration: 120, // 2 hours
            songs: nil
        )
        
        let futureSession = Session(
            id: UUID().uuidString,
            studio: .studioC,
            mainProducer: demoUser.name,
            additionalProducers: ["Pedro Santos"],
            singers: ["Luiza Oliveira", "Thiago Almeida"],
            date: futureDate,
            duration: 240, // 4 hours
            songs: nil
        )
        
        // Save sessions to CoreData
        coreDataManager.performBackgroundTask { context in
            let _ = pastSession1.toEntity(in: context)
            let _ = pastSession2.toEntity(in: context)
            let _ = futureSession.toEntity(in: context)
            
            // Update sessions array on main thread
            DispatchQueue.main.async {
                self.getSessionManager().sessions = [pastSession1, pastSession2, futureSession]
            }
        }
        
        // Add demo tasks
        let task1 = Task(
            id: UUID().uuidString,
            title: "Mix final version of 'Summer Night'",
            description: "Complete the final mix for Ana's new song 'Summer Night'",
            priority: .high,
            createdAt: Date().addingTimeInterval(-86400), // 1 day ago
            dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
            assignedTo: demoUser.id,
            createdBy: demoUser.id,
            isCompleted: false
        )
        
        let task2 = Task(
            id: UUID().uuidString,
            title: "Schedule mastering session",
            description: "Book time with mastering engineer for the new album",
            priority: .medium,
            createdAt: Date().addingTimeInterval(-172800), // 2 days ago
            dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            assignedTo: demoUser.id,
            createdBy: demoUser.id,
            isCompleted: false
        )
        
        let task3 = Task(
            id: UUID().uuidString,
            title: "Call equipment rental",
            description: "Reserve additional microphones for next week's session",
            priority: .low,
            createdAt: Date().addingTimeInterval(-43200), // 12 hours ago
            dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
            assignedTo: demoUser.id,
            createdBy: demoUser.id,
            isCompleted: true
        )
        
        // Save tasks to CoreData
        coreDataManager.performBackgroundTask { context in
            let _ = task1.toEntity(in: context)
            let _ = task2.toEntity(in: context)
            let _ = task3.toEntity(in: context)
            
            // Update tasks array on main thread
            DispatchQueue.main.async {
                self.getTaskManager().setTasks([task1, task2, task3])
            }
        }
        
        // In a real app, we might add demo songs too, but they require audio files
        // which are not easily created programmatically
    }
    
    // MARK: - Memory Management
    
    /// Clear caches to reduce memory pressure
    func clearCaches() {
        CacheManager.shared.clearAllCaches()
    }
    
    /// Optimize memory usage when the app is going to background
    func prepareForBackground() {
        // Clear audio cache when app goes to background to reduce memory usage
        CacheManager.shared.audioDataCache.clearCache()
    }
    
    /// Reload essentials when the app returns to foreground
    func prepareForForeground() {
        // Refresh data that might have changed
        songManager.loadSongs()
        sessionManager.loadSessions()
        taskManager.loadTasks()
    }
    
    // MARK: - Service Access Methods (ServiceLocator Transition)
    
    /// Get the authentication service (transitional method)
    /// This method attempts to get the service from ServiceLocator first,
    /// then falls back to the direct reference if not found
    func getAuthService() -> AuthenticationServiceProtocol {
        if let service = ServiceLocator.shared.resolve(AuthenticationServiceProtocol.self) {
            return service
        }
        return authService
    }
    
    /// Get the audio service (transitional method)
    /// This method attempts to get the service from ServiceLocator first,
    /// then falls back to the direct reference if not found
    func getAudioService() -> AudioServiceProtocol {
        if let service = ServiceLocator.shared.resolve(AudioServiceProtocol.self) {
            return service
        }
        return audioService
    }
    
    /// Get the error handling service (transitional method)
    /// This method attempts to get the service from ServiceLocator first,
    /// then falls back to the direct reference if not found
    func getErrorService() -> ErrorHandlingServiceProtocol {
        if let service = ServiceLocator.shared.resolve(ErrorHandlingServiceProtocol.self) {
            return service
        }
        return errorService
    }
    
    /// Get the user manager (transitional method)
    /// This method attempts to get the manager from ServiceLocator first,
    /// then falls back to the direct reference if not found
    func getUserManager() -> UserManagerProtocol {
        if let manager = ServiceLocator.shared.resolve(UserManagerProtocol.self) {
            return manager
        }
        return userManager
    }
    
    /// Get the task manager (transitional method)
    /// This method attempts to get the manager from ServiceLocator first,
    /// then falls back to the direct reference if not found
    func getTaskManager() -> TaskManagerProtocol {
        if let manager = ServiceLocator.shared.resolve(TaskManagerProtocol.self) {
            return manager
        }
        return taskManager
    }
    
    /// Get the news manager (transitional method)
    /// This method attempts to get the manager from ServiceLocator first,
    /// then falls back to the direct reference if not found
    func getNewsManager() -> NewsManagerProtocol {
        if let manager = ServiceLocator.shared.resolve(NewsManagerProtocol.self) {
            return manager
        }
        return newsManager
    }
    
    /// Get the session manager (transitional method)
    /// This method attempts to get the manager from ServiceLocator first,
    /// then falls back to the direct reference if not found
    func getSessionManager() -> SessionManager {
        if let manager = ServiceLocator.shared.resolve(SessionManager.self) {
            return manager
        }
        return sessionManager
    }
    
    /// Get the song manager (transitional method)
    /// This method attempts to get the manager from ServiceLocator first,
    /// then falls back to the direct reference if not found
    func getSongManager() -> SongManager {
        if let manager = ServiceLocator.shared.resolve(SongManager.self) {
            return manager
        }
        return songManager
    }
} 