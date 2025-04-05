import Foundation
import CoreData

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

class SessionManager: ObservableObject {
    @Published var sessions: [Session] = []
    
    // Reference to CoreData manager
    private let coreDataManager = CoreDataManager.shared
    
    func bookSession(studio: Studio, mainProducer: String, additionalProducers: [String], 
                    singers: [String], date: Date, duration: TimeInterval) -> Bool {
        
        // Check for double booking
        if isStudioBooked(studio: studio, date: date, duration: duration) {
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
        
        // Save to CoreData
        coreDataManager.performBackgroundTask { context in
            let _ = newSession.toEntity(in: context)
            
            // Update published property on main thread
            DispatchQueue.main.async {
                self.sessions.append(newSession)
            }
        }
        
        return true
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
    
    // Load all sessions from CoreData
    func loadSessions() {
        let context = coreDataManager.viewContext
        let fetchRequest: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        
        // Sort by date - most recent first
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        do {
            let sessionEntities = try context.fetch(fetchRequest)
            let loadedSessions = sessionEntities.map { Session.fromEntity($0) }
            
            DispatchQueue.main.async {
                self.sessions = loadedSessions
            }
        } catch {
            print("Error loading sessions from CoreData: \(error)")
        }
    }
    
    // Fetch a specific session by ID
    func fetchSession(byID id: String) -> Session? {
        let context = coreDataManager.viewContext
        let fetchRequest: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let entity = results.first {
                return Session.fromEntity(entity)
            }
        } catch {
            print("Error fetching session from CoreData: \(error)")
        }
        
        return nil
    }
    
    // Delete a session
    func deleteSession(id: String) {
        // Remove from published array
        sessions.removeAll { $0.id == id }
        
        // Remove from CoreData
        coreDataManager.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
            
            do {
                let results = try context.fetch(fetchRequest)
                if let sessionEntity = results.first {
                    context.delete(sessionEntity)
                }
            } catch {
                print("Error deleting session from CoreData: \(error)")
            }
        }
    }
} 