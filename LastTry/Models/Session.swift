import Foundation
import CoreData

// Custom error types for session management
enum SessionError: Error, LocalizedError, Equatable {
    case sessionNotFound(String)
    case failedToSave(String)
    case failedToLoad(String)
    case failedToUpdate(String)
    case failedToDelete(String)
    case studioUnavailable(String)
    case schedulingConflict(String)
    case invalidSessionData(String)
    case invalidDuration
    case pastDateBooking
    case coreDataError(String)
    
    var errorDescription: String? {
        switch self {
        case .sessionNotFound(let message):
            return "Session not found: \(message)"
        case .failedToSave(let message):
            return "Failed to save session: \(message)"
        case .failedToLoad(let message):
            return "Failed to load sessions: \(message)"
        case .failedToUpdate(let message):
            return "Failed to update session: \(message)"
        case .failedToDelete(let message):
            return "Failed to delete session: \(message)"
        case .studioUnavailable(let message):
            return "Studio unavailable: \(message)"
        case .schedulingConflict(let message):
            return "Scheduling conflict: \(message)"
        case .invalidSessionData(let message):
            return "Invalid session data: \(message)"
        case .invalidDuration:
            return "Invalid session duration"
        case .pastDateBooking:
            return "Cannot book sessions in the past"
        case .coreDataError(let message):
            return "Database error: \(message)"
        }
    }
    
    // Implementation of Equatable for cases with associated values
    static func == (lhs: SessionError, rhs: SessionError) -> Bool {
        switch (lhs, rhs) {
        case (.sessionNotFound(let lhs), .sessionNotFound(let rhs)):
            return lhs == rhs
        case (.failedToSave(let lhs), .failedToSave(let rhs)):
            return lhs == rhs
        case (.failedToLoad(let lhs), .failedToLoad(let rhs)):
            return lhs == rhs
        case (.failedToUpdate(let lhs), .failedToUpdate(let rhs)):
            return lhs == rhs
        case (.failedToDelete(let lhs), .failedToDelete(let rhs)):
            return lhs == rhs
        case (.studioUnavailable(let lhs), .studioUnavailable(let rhs)):
            return lhs == rhs
        case (.schedulingConflict(let lhs), .schedulingConflict(let rhs)):
            return lhs == rhs
        case (.invalidSessionData(let lhs), .invalidSessionData(let rhs)):
            return lhs == rhs
        case (.invalidDuration, .invalidDuration),
             (.pastDateBooking, .pastDateBooking):
            return true
        case (.coreDataError(let lhs), .coreDataError(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

enum Studio: String, CaseIterable, Identifiable, Codable {
    case studioA = "Studio A"
    case studioB = "Studio B"
    case studioC = "Studio C"
    case studioD = "Studio D"
    
    var id: String { self.rawValue }
}

struct Session: Identifiable, Codable {
    var id: String
    var studio: Studio
    var mainProducer: String
    var additionalProducers: [String]
    var singers: [String]
    var date: Date
    var duration: TimeInterval // in minutes
    var songs: [Song]?
    
    var isPastSession: Bool {
        return Date() > date
    }
    
    var hasUploadedAudio: Bool {
        return songs != nil && !songs!.isEmpty
    }
}

// MARK: - CoreDataConvertible
extension Session: CoreDataConvertible {
    typealias Entity = SessionEntity
    
    func toEntity(in context: NSManagedObjectContext) -> SessionEntity {
        SessionEntity.createOrUpdate(from: self, in: context)
    }
    
    static func fromEntity(_ entity: SessionEntity) -> Session {
        entity.toModel()
    }
}

// MARK: - Session CoreData Manager

class SessionDataManager: CoreDataManaging {
    typealias EntityType = SessionEntity
    typealias ModelType = Session
    
    var entityName: String { "SessionEntity" }
    
    func createEntity(from model: Session, in context: NSManagedObjectContext) -> SessionEntity {
        // Try to find existing entity first
        let fetchRequest: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", model.id)
        
        if let existingEntity = try? context.fetch(fetchRequest).first {
            // Update existing entity
            updateEntity(existingEntity, from: model)
            return existingEntity
        } else {
            // Create new entity
            let entity = SessionEntity(context: context)
            updateEntity(entity, from: model)
            return entity
        }
    }
    
    private func updateEntity(_ entity: SessionEntity, from model: Session) {
        entity.id = model.id
        entity.studio = model.studio.rawValue
        entity.mainProducer = model.mainProducer
        entity.additionalProducers = model.additionalProducers
        entity.singers = model.singers
        entity.date = model.date
        entity.duration = model.duration
        
        // Songs would be handled separately or through a relationship
    }
    
    func createModel(from entity: SessionEntity) -> Session {
        // Get the arrays directly, no conditional downcasts
        let producers = entity.additionalProducers as [String]? ?? []
        let singers = entity.singers as [String]? ?? []
        
        return Session(
            id: entity.id ?? UUID().uuidString,
            studio: Studio(rawValue: entity.studio ?? "Studio A") ?? .studioA,
            mainProducer: entity.mainProducer ?? "",
            additionalProducers: producers,
            singers: singers,
            date: entity.date ?? Date(),
            duration: entity.duration,
            songs: nil  // Songs would typically be loaded separately or through relationships
        )
    }
    
    // Convert [SessionEntity] to [Session]
    func createModels(from entities: [SessionEntity]) -> [Session] {
        entities.map { createModel(from: $0) }
    }
}

class SessionManager: ObservableObject {
    // MARK: - Singleton
    
    /// Shared instance for global access
    static let shared = SessionManager()
    
    @Published var sessions: [Session] = []
    @Published var sessionError: SessionError? = nil
    
    // Reference to CoreData manager
    private let coreDataManager = CoreDataManager.shared
    // Reference to the session data manager
    private let sessionDataManager = SessionDataManager()
    // Reference to error handling service
    private let errorService: ErrorHandlingServiceProtocol
    
    // MARK: - Initialization
    
    /// Private initializer for singleton pattern
    private init() {
        // Get errorService from ServiceLocator
        self.errorService = ServiceLocator.shared.resolve(ErrorHandlingServiceProtocol.self) ?? ErrorHandlingService.shared
        // Load sessions from CoreData on initialization
        loadSessions()
        print("SessionManager: Initialized shared instance")
    }
    
    /// Dependency injection initializer for testing or custom configurations
    init(errorService: ErrorHandlingServiceProtocol) {
        self.errorService = errorService
        print("SessionManager: Initialized with custom error handling service")
    }
    
    func bookSession(studio: Studio, mainProducer: String, additionalProducers: [String], 
                    singers: [String], date: Date, duration: TimeInterval) -> Bool {
        
        // Validate inputs
        guard duration > 0 else {
            sessionError = .invalidDuration
            errorService.reportError(sessionError!)
            return false
        }
        
        guard date > Date() else {
            sessionError = .pastDateBooking
            errorService.reportError(sessionError!)
            return false
        }
        
        // Check for double booking
        if isStudioBooked(studio: studio, date: date, duration: duration) {
            sessionError = .schedulingConflict("Studio \(studio.rawValue) is already booked for this time slot")
            errorService.reportError(sessionError!)
            return false
        }
        
        // Create new session
        let newSession = Session(
            id: UUID().uuidString,
            studio: studio,
            mainProducer: mainProducer,
            additionalProducers: additionalProducers,
            singers: singers,
            date: date,
            duration: duration,
            songs: nil
        )
        
        // Save to CoreData using Result
        let result = sessionDataManager.performBackgroundTask { context in
            let saveResult = self.sessionDataManager.saveOrUpdate(
                model: newSession, 
                idValue: newSession.id, 
                in: context
            )
            
            switch saveResult {
            case .success(_):
                return .success(())
            case .failure(let error):
                return .failure(error)
            }
        }
        
        switch result {
        case .success(_):
            // Update published property on main thread
            DispatchQueue.main.async {
                self.sessions.append(newSession)
            }
            return true
        case .failure(let error):
            sessionError = .failedToSave("Failed to save session: \(error.localizedDescription)")
            errorService.reportError(sessionError!)
            return false
        }
    }
    
    func isStudioBooked(studio: Studio, date: Date, duration: TimeInterval) -> Bool {
        // Logic to check if the studio is already booked for the given time
        return sessions.contains { session in
            guard session.studio == studio else { return false }
            
            let sessionStart = session.date
            let sessionEnd = sessionStart.addingTimeInterval(session.duration * 60)
            
            let newSessionStart = date
            let newSessionEnd = newSessionStart.addingTimeInterval(duration * 60)
            
            // Check for overlap
            return (newSessionStart < sessionEnd && newSessionEnd > sessionStart)
        }
    }
    
    func pastSessions() -> [Session] {
        return sessions.filter { $0.isPastSession }
    }
    
    func upcomingSessions() -> [Session] {
        return sessions.filter { !$0.isPastSession }
    }
    
    func sessionsForMonth(year: Int, month: Int) -> [Session] {
        return sessions.filter {
            let components = Calendar.current.dateComponents([.year, .month], from: $0.date)
            return components.year == year && components.month == month
        }
    }
    
    func addSongToSession(sessionId: String, song: Song) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        
        if sessions[index].songs == nil {
            sessions[index].songs = []
        }
        
        sessions[index].songs?.append(song)
        
        // Save to CoreData
        coreDataManager.performBackgroundTask { context in
            // Find the session entity
            let fetchRequest: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", sessionId)
            
            do {
                let results = try context.fetch(fetchRequest)
                if let sessionEntity = results.first {
                    // Create song entity and add to session
                    let songEntity = song.toEntity(in: context)
                    
                    // Add the song to the session's songs relationship
                    if sessionEntity.songs == nil {
                        sessionEntity.songs = NSSet()
                    }
                    
                    let mutableSongs = sessionEntity.songs?.mutableCopy() as? NSMutableSet
                    mutableSongs?.add(songEntity)
                    sessionEntity.songs = mutableSongs
                }
            } catch {
                print("Error fetching session for adding song: \(error)")
            }
        }
    }
    
    // MARK: - CoreData methods
    
    // Load all sessions from CoreData - updated to use Result
    func loadSessions() {
        let context = coreDataManager.viewContext
        
        // Create sort descriptor
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        
        // Use sessionDataManager to fetch with Result
        let result = sessionDataManager.fetch(
            sortDescriptors: [sortDescriptor],
            in: context
        )
        
        switch result {
        case .success(let entities):
            let loadedSessions = sessionDataManager.createModels(from: entities)
            DispatchQueue.main.async {
                self.sessions = loadedSessions
            }
        case .failure(let error):
            print("Error loading sessions from CoreData: \(error.localizedDescription)")
            sessionError = .failedToLoad("Failed to load sessions: \(error.localizedDescription)")
            errorService.reportError(sessionError!)
        }
    }
    
    // Fetch a specific session by ID - updated to use Result
    func fetchSession(byID id: String) -> Session? {
        let context = coreDataManager.viewContext
        let result = sessionDataManager.fetchById(id: id, in: context)
        
        switch result {
        case .success(let entityOptional):
            if let entity = entityOptional {
                return sessionDataManager.createModel(from: entity)
            }
            sessionError = .sessionNotFound("Session with ID \(id) not found")
            return nil
        case .failure(let error):
            print("Error fetching session from CoreData: \(error.localizedDescription)")
            sessionError = .coreDataError("Database error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Update session 
    func updateSession(_ session: Session) -> Bool {
        let result = sessionDataManager.performBackgroundTask { context in
            let saveResult = self.sessionDataManager.saveOrUpdate(
                model: session, 
                idValue: session.id, 
                in: context
            )
            
            switch saveResult {
            case .success(_):
                return .success(())
            case .failure(let error):
                return .failure(error)
            }
        }
        
        switch result {
        case .success(_):
            // Update the session in the array
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                DispatchQueue.main.async {
                    self.sessions[index] = session
                }
            }
            return true
        case .failure(let error):
            sessionError = .failedToUpdate("Failed to update session: \(error.localizedDescription)")
            errorService.reportError(sessionError!)
            return false
        }
    }
    
    // Delete session
    func deleteSession(withID id: String) -> Bool {
        // Use regular performBackgroundTask instead of performBackgroundTaskWithResult
        let result = sessionDataManager.performBackgroundTask { context in
            // Fetch the entity to delete
            let fetchRequest: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
            
            do {
                let results = try context.fetch(fetchRequest)
                if let sessionEntity = results.first {
                    // Delete the entity
                    context.delete(sessionEntity)
                    try context.save()
                    return .success(())
                } else {
                    return .failure(CoreDataError.entityNotFound)
                }
            } catch {
                return .failure(CoreDataError.deleteFailed(error.localizedDescription))
            }
        }
        
        switch result {
        case .success:
            // Remove the session from the array
            DispatchQueue.main.async {
                self.sessions.removeAll { $0.id == id }
            }
            return true
        case .failure(let error):
            sessionError = .failedToDelete("Failed to delete session: \(error.localizedDescription)")
            errorService.reportError(sessionError!)
            return false
        }
    }
}

// MARK: - Session Library Helper

/// Global access to session functionality
enum SessionLibrary {
    /// Access the shared session manager instance
    static var manager: SessionManager {
        return SessionManager.shared
    }
    
    /// All sessions
    static var sessions: [Session] {
        return manager.sessions
    }
    
    /// Past sessions
    static var pastSessions: [Session] {
        return manager.pastSessions()
    }
    
    /// Upcoming sessions
    static var upcomingSessions: [Session] {
        return manager.upcomingSessions()
    }
    
    /// Book a new session
    /// - Parameters:
    ///   - studio: Studio to book
    ///   - mainProducer: Primary producer name
    ///   - additionalProducers: Additional producers (optional)
    ///   - singers: Singers for the session
    ///   - date: Session date
    ///   - duration: Session duration in minutes
    /// - Returns: Success indicator
    static func bookSession(studio: Studio, mainProducer: String, additionalProducers: [String] = [], 
                           singers: [String], date: Date, duration: TimeInterval) -> Bool {
        return manager.bookSession(
            studio: studio,
            mainProducer: mainProducer,
            additionalProducers: additionalProducers,
            singers: singers,
            date: date,
            duration: duration
        )
    }
    
    /// Update an existing session
    /// - Parameter session: Updated session object
    /// - Returns: Success indicator
    static func updateSession(_ session: Session) -> Bool {
        return manager.updateSession(session)
    }
    
    /// Delete a session
    /// - Parameter id: Session ID to delete
    /// - Returns: Success indicator
    static func deleteSession(id: String) -> Bool {
        return manager.deleteSession(withID: id)
    }
    
    /// Check if a studio is available for booking
    /// - Parameters:
    ///   - studio: Studio to check
    ///   - date: Requested date
    ///   - duration: Requested duration
    /// - Returns: True if studio is already booked
    static func isStudioBooked(studio: Studio, date: Date, duration: TimeInterval) -> Bool {
        return manager.isStudioBooked(studio: studio, date: date, duration: duration)
    }
    
    /// Get sessions for a specific month
    /// - Parameters:
    ///   - year: Year
    ///   - month: Month (1-12)
    /// - Returns: Array of sessions in that month
    static func sessionsForMonth(year: Int, month: Int) -> [Session] {
        return manager.sessionsForMonth(year: year, month: month)
    }
    
    /// Add a song to a session
    /// - Parameters:
    ///   - sessionId: Session ID
    ///   - song: Song to add
    static func addSongToSession(sessionId: String, song: Song) {
        manager.addSongToSession(sessionId: sessionId, song: song)
    }
    
    /// Load all sessions from storage
    static func loadAllSessions() {
        manager.loadSessions()
    }
    
    /// Clear any session errors
    static func clearError() {
        manager.sessionError = nil
    }
} 