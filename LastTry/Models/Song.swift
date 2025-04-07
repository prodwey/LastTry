import Foundation
import AVFoundation
import CoreData

// Custom error types for song management
enum SongError: Error, LocalizedError, Equatable {
    case songNotFound(String)
    case failedToSave(String)
    case failedToLoad(String)
    case failedToUpdate(String)
    case failedToDelete(String)
    case invalidFileFormat(String)
    case fileError(String)
    case metadataError(String)
    case playbackError(String)
    case fileNotFound
    case coreDataError(String)
    
    var errorDescription: String? {
        switch self {
        case .songNotFound(let message):
            return "Song not found: \(message)"
        case .failedToSave(let message):
            return "Failed to save song: \(message)"
        case .failedToLoad(let message):
            return "Failed to load songs: \(message)"
        case .failedToUpdate(let message):
            return "Failed to update song: \(message)"
        case .failedToDelete(let message):
            return "Failed to delete song: \(message)"
        case .invalidFileFormat(let message):
            return "Invalid file format: \(message)"
        case .fileError(let message):
            return "File error: \(message)"
        case .metadataError(let message):
            return "Metadata error: \(message)"
        case .playbackError(let message):
            return "Playback error: \(message)"
        case .fileNotFound:
            return "Audio file not found"
        case .coreDataError(let message):
            return "Database error: \(message)"
        }
    }
    
    // Implementation of Equatable for cases with associated values
    static func == (lhs: SongError, rhs: SongError) -> Bool {
        switch (lhs, rhs) {
        case (.songNotFound(let lhs), .songNotFound(let rhs)):
            return lhs == rhs
        case (.failedToSave(let lhs), .failedToSave(let rhs)):
            return lhs == rhs
        case (.failedToLoad(let lhs), .failedToLoad(let rhs)):
            return lhs == rhs
        case (.failedToUpdate(let lhs), .failedToUpdate(let rhs)):
            return lhs == rhs
        case (.failedToDelete(let lhs), .failedToDelete(let rhs)):
            return lhs == rhs
        case (.invalidFileFormat(let lhs), .invalidFileFormat(let rhs)):
            return lhs == rhs
        case (.fileError(let lhs), .fileError(let rhs)):
            return lhs == rhs
        case (.metadataError(let lhs), .metadataError(let rhs)):
            return lhs == rhs
        case (.playbackError(let lhs), .playbackError(let rhs)):
            return lhs == rhs
        case (.fileNotFound, .fileNotFound):
            return true
        case (.coreDataError(let lhs), .coreDataError(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

struct Artist: Identifiable, Codable {
    var id: String
    var name: String
    var cpf: String?
    var rg: String?
    var dateOfBirth: Date?
    var email: String?
    var phone: String?
    var publisher: String?
    var recordingLabel: String?
}

// MARK: - CoreDataConvertible
extension Artist: CoreDataConvertible {
    typealias Entity = ArtistEntity
    
    func toEntity(in context: NSManagedObjectContext) -> ArtistEntity {
        ArtistEntity.createOrUpdate(from: self, in: context)
    }
    
    static func fromEntity(_ entity: ArtistEntity) -> Artist {
        entity.toModel()
    }
}

enum AudioFormat: String, Codable, CaseIterable {
    case wav = "WAV"
    case aac = "AAC"
    case amr = "AMR"
    case mp3 = "MP3"
    case mp4 = "MP4"
    case ogg = "OGG"
    case opus = "OPUS"
    case m4a = "M4A"
    
    var fileExtension: String {
        return self.rawValue.lowercased()
    }
    
    static func fromFileExtension(_ extension: String) -> AudioFormat? {
        return AudioFormat.allCases.first { $0.fileExtension == `extension`.lowercased() }
    }
}

struct Song: Identifiable, Codable {
    var id: String
    var name: String
    var fileURL: URL?
    var format: AudioFormat
    var artists: [Artist]
    var lyrics: String?
    var dateCreated: Date
    var fileSize: Int64? // In bytes
    var duration: TimeInterval? // In seconds
    var sessionId: String
    
    // Player related properties are not persisted
    var audioPlayer: AVAudioPlayer?
    
    var formattedDuration: String {
        guard let duration = duration else { return "--:--" }
        
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedFileSize: String {
        guard let size = fileSize else { return "Unknown" }
        
        let kb = Double(size) / 1024.0
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        } else {
            let mb = kb / 1024.0
            return String(format: "%.1f MB", mb)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, fileURL, format, artists, lyrics, dateCreated, fileSize, duration, sessionId
    }
}

// MARK: - CoreDataConvertible
extension Song: CoreDataConvertible {
    typealias Entity = SongEntity
    
    func toEntity(in context: NSManagedObjectContext) -> SongEntity {
        SongEntity.createOrUpdate(from: self, in: context)
    }
    
    static func fromEntity(_ entity: SongEntity) -> Song {
        entity.toModel()
    }
}

// MARK: - Song CoreData Manager

class SongDataManager: CoreDataManaging {
    typealias EntityType = SongEntity
    typealias ModelType = Song
    
    var entityName: String { "SongEntity" }
    
    func createEntity(from model: Song, in context: NSManagedObjectContext) -> SongEntity {
        // Try to find existing entity first
        let fetchRequest: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", model.id)
        
        if let existingEntity = try? context.fetch(fetchRequest).first {
            // Update existing entity
            updateEntity(existingEntity, from: model, in: context)
            return existingEntity
        } else {
            // Create new entity
            let entity = SongEntity(context: context)
            updateEntity(entity, from: model, in: context)
            return entity
        }
    }
    
    private func updateEntity(_ entity: SongEntity, from model: Song, in context: NSManagedObjectContext) {
        entity.id = model.id
        entity.name = model.name
        
        // Direct assignment - fileURL is a URL type in CoreData
        entity.fileURL = model.fileURL
        
        entity.format = model.format.rawValue
        entity.lyrics = model.lyrics
        entity.dateCreated = model.dateCreated
        entity.fileSize = model.fileSize ?? 0
        entity.duration = model.duration ?? 0
        
        // Handle session relationship
        if !model.sessionId.isEmpty {
            let sessionFetchRequest: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
            sessionFetchRequest.predicate = NSPredicate(format: "id == %@", model.sessionId)
            
            if let sessionEntity = try? context.fetch(sessionFetchRequest).first {
                entity.session = sessionEntity
            }
        }
        
        // Handle artists - simplified for this example
        if !model.artists.isEmpty {
            let artistEntities = NSMutableSet()
            
            for artist in model.artists {
                // Create a fetch request for the artist
                let artistFetchRequest: NSFetchRequest<ArtistEntity> = ArtistEntity.fetchRequest()
                artistFetchRequest.predicate = NSPredicate(format: "id == %@", artist.id)
                
                // Try to find the artist or create a new one
                let artistEntity: ArtistEntity
                if let existingArtist = try? context.fetch(artistFetchRequest).first {
                    artistEntity = existingArtist
                } else {
                    artistEntity = ArtistEntity(context: context)
                    artistEntity.id = artist.id
                    artistEntity.name = artist.name
                }
                
                artistEntities.add(artistEntity)
            }
            
            entity.artists = artistEntities
        }
    }
    
    func createModel(from entity: SongEntity) -> Song {
        // Direct use of entity.fileURL - it's already a URL
        
        // Convert format string to AudioFormat enum
        let format = AudioFormat(rawValue: entity.format ?? "") ?? .mp3
        
        // Create artists array from relationship
        var artists: [Artist] = []
        if let artistSet = entity.artists as? Set<ArtistEntity> {
            artists = artistSet.map { Artist(id: $0.id ?? UUID().uuidString, name: $0.name ?? "") }
        }
        
        let sessionId = entity.session?.id ?? ""
        
        return Song(
            id: entity.id ?? UUID().uuidString,
            name: entity.name ?? "",
            fileURL: entity.fileURL,
            format: format,
            artists: artists,
            lyrics: entity.lyrics,
            dateCreated: entity.dateCreated ?? Date(),
            fileSize: entity.fileSize > 0 ? entity.fileSize : nil,
            duration: entity.duration > 0 ? entity.duration : nil,
            sessionId: sessionId
        )
    }
    
    // Convert [SongEntity] to [Song]
    func createModels(from entities: [SongEntity]) -> [Song] {
        entities.map { createModel(from: $0) }
    }
}

class SongManager: ObservableObject {
    @Published var songs: [Song] = []
    @Published var songError: SongError? = nil
    
    // Reference to CoreData manager
    private let coreDataManager = CoreDataManager.shared
    // Reference to the song data manager
    private let songDataManager = SongDataManager()
    
    func addSong(name: String, fileURL: URL, artists: [Artist], lyrics: String?, sessionId: String) -> Bool {
        // Validate session ID
        guard !sessionId.isEmpty else {
            songError = .failedToSave("Session ID is required")
            return false
        }
        
        // Validate file extension
        guard let format = AudioFormat.fromFileExtension(fileURL.pathExtension) else {
            songError = .invalidFileFormat("Unsupported file format: \(fileURL.pathExtension)")
            return false
        }
        
        // For file URLs, validate the file exists
        if fileURL.isFileURL && !FileManager.default.fileExists(atPath: fileURL.path) {
            songError = .fileNotFound
            return false
        }
        
        // Get file attributes only for file URLs
        var fileSize: Int64? = nil
        var duration: TimeInterval? = nil
        
        if fileURL.isFileURL {
            // Get file size
            fileSize = getFileSize(url: fileURL)
            
            // Get audio duration
            duration = getAudioDuration(url: fileURL)
        }
        
        let newSong = Song(
            id: UUID().uuidString,
            name: name,
            fileURL: fileURL,  // Use URL directly, CoreData can handle it as URI type
            format: format,
            artists: artists,
            lyrics: lyrics,
            dateCreated: Date(),
            fileSize: fileSize,
            duration: duration,
            sessionId: sessionId
        )
        
        // Add song to CoreData using Result
        let result = songDataManager.performBackgroundTask { context in
            let saveResult = self.songDataManager.saveOrUpdate(
                model: newSong, 
                idValue: newSong.id, 
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
            // Add song to array
            DispatchQueue.main.async {
                self.songs.append(newSong)
            }
            return true
        case .failure(let error):
            songError = .failedToSave("Failed to save song: \(error.localizedDescription)")
            return false
        }
    }
    
    private func getFileSize(url: URL) -> Int64? {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resources.fileSize {
                return Int64(fileSize)
            }
        } catch {
            print("Error getting file size: \(error)")
            songError = .fileError("Error getting file size: \(error.localizedDescription)")
        }
        return nil
    }
    
    private func getAudioDuration(url: URL) -> TimeInterval? {
        // Create AVURLAsset
        let asset = AVURLAsset(url: url)
        
        // Since this is initial setup, we'll use a simple approach for iOS 16+
        // For actual playback, we'll use the more accurate method in AudioService
        
        #if os(iOS)
        if #available(iOS 16.0, *) {
            // Use CMTimeGetSeconds instead of the deprecated seconds property
            let time = asset.duration
            let seconds = CMTimeGetSeconds(time)
            return seconds > 0 ? seconds : nil
        } else {
            // Pre-iOS 16 approach
            let durationSeconds = asset.duration.seconds
            return durationSeconds.isNaN || durationSeconds <= 0 ? nil : durationSeconds
        }
        #else
        // For non-iOS platforms
        let durationSeconds = asset.duration.seconds
        return durationSeconds.isNaN || durationSeconds <= 0 ? nil : durationSeconds
        #endif
    }
    
    // MARK: - CoreData methods
    
    // Load all songs from CoreData - updated to use Result
    func loadSongs() {
        let context = coreDataManager.viewContext
        
        // Create sort descriptor for date
        let sortDescriptor = NSSortDescriptor(key: "dateCreated", ascending: false)
        
        // Use songDataManager to fetch with Result
        let result = songDataManager.fetch(
            sortDescriptors: [sortDescriptor],
            in: context
        )
        
        switch result {
        case .success(let entities):
            let loadedSongs = songDataManager.createModels(from: entities)
            DispatchQueue.main.async {
                self.songs = loadedSongs
            }
        case .failure(let error):
            print("Error loading songs from CoreData: \(error.localizedDescription)")
            songError = .failedToLoad("Failed to load songs: \(error.localizedDescription)")
        }
    }
    
    // Fetch songs for a specific session - updated to use Result
    func loadSongsForSession(sessionId: String) -> [Song] {
        guard !sessionId.isEmpty else {
            songError = .failedToLoad("Invalid session ID")
            return []
        }
        
        let context = coreDataManager.viewContext
        
        // Create predicate for session relationship instead of sessionId property
        let predicate = NSPredicate(format: "session.id == %@", sessionId)
        
        // Use songDataManager to fetch with Result
        let result = songDataManager.fetch(
            predicate: predicate,
            in: context
        )
        
        switch result {
        case .success(let entities):
            return songDataManager.createModels(from: entities)
        case .failure(let error):
            print("Error loading songs for session: \(error.localizedDescription)")
            songError = .failedToLoad("Failed to load songs for session: \(error.localizedDescription)")
            return []
        }
    }
    
    // Delete a song - updated to use Result
    func deleteSong(withID id: String) -> Bool {
        let result = songDataManager.performBackgroundTask { context in
            return self.songDataManager.deleteById(id: id, in: context)
        }
        
        switch result {
        case .success(_):
            // Remove from the published array
            DispatchQueue.main.async {
                self.songs.removeAll { $0.id == id }
            }
            return true
        case .failure(let error):
            songError = .failedToDelete("Failed to delete song: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Search functionality
    
    func searchSongs(query: String) -> [Song] {
        guard !query.isEmpty else { return songs }
        
        let lowercasedQuery = query.lowercased()
        return songs.filter { song in
            // Search by song name
            if song.name.lowercased().contains(lowercasedQuery) {
                return true
            }
            
            // Search by artist name
            if song.artists.contains(where: { $0.name.lowercased().contains(lowercasedQuery) }) {
                return true
            }
            
            // Search by lyrics if available
            if let lyrics = song.lyrics, lyrics.lowercased().contains(lowercasedQuery) {
                return true
            }
            
            return false
        }
    }
} 
