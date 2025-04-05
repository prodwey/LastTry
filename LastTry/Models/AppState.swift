import Foundation
import SwiftUI
import CoreData

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
    @Published var userManager = UserManager()
    @Published var sessionManager = SessionManager()
    @Published var songManager = SongManager()
    @Published var taskManager = TaskManager()
    @Published var newsManager = NewsManager()
    
    @Published var selectedLanguage: AppLanguage = .portugueseBR
    @Published var tabSelection: Int = 0
    @Published var currentPlayingSong: Song? = nil
    @Published var isPlaying: Bool = false
    @Published var currentPlaybackPosition: TimeInterval = 0
    
    private let coreDataManager = CoreDataManager.shared
    
    init() {
        // Check for CoreData migration need on first launch
        checkAndPerformMigration()
        
        // Check if user is logged in, otherwise load demo data
        if !userManager.isLoggedIn {
            loadDemoData()
        }
        
        newsManager.fetchNews()
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
        userManager.currentUser = demoUser
        userManager.isLoggedIn = true
        
        // For backward compatibility
        userManager.saveUserData()
        
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
        
        sessionManager.sessions = [pastSession1, pastSession2, futureSession]
        
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
        
        taskManager.tasks = [task1, task2, task3]
        
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
        
        songManager.songs = [song1, song2, song3]
        
        // Update sessions with songs
        if let index1 = sessionManager.sessions.firstIndex(where: { $0.id == pastSession1ID }) {
            sessionManager.sessions[index1].songs = [song1, song2]
        }
        
        if let index2 = sessionManager.sessions.firstIndex(where: { $0.id == pastSession2ID }) {
            sessionManager.sessions[index2].songs = [song3]
        }
    }
    
    func playSong(_ song: Song) {
        self.currentPlayingSong = song
        self.isPlaying = true
        self.currentPlaybackPosition = 0
        // In a real app, this would actually play the audio
    }
    
    func pausePlayback() {
        self.isPlaying = false
        // In a real app, this would pause the audio
    }
    
    func resumePlayback() {
        self.isPlaying = true
        // In a real app, this would resume the audio
    }
    
    func stopPlayback() {
        self.currentPlayingSong = nil
        self.isPlaying = false
        self.currentPlaybackPosition = 0
        // In a real app, this would stop the audio
    }
    
    func switchLanguage(to language: AppLanguage) {
        self.selectedLanguage = language
        // In a real app, this would update all text in the app
    }
} 