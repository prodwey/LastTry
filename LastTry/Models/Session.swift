import Foundation

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

class SessionManager: ObservableObject {
    @Published var sessions: [Session] = []
    
    func bookSession(studio: Studio, mainProducer: String, additionalProducers: [String], 
                    singers: [String], date: Date, duration: TimeInterval) -> Bool {
        
        // Check for double booking
        if isStudioBooked(studio: studio, date: date, duration: duration) {
            return false
        }
        
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
        
        sessions.append(newSession)
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
    }
} 