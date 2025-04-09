import Foundation
import AVFoundation
import CoreData
import Combine

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
    case aiff = "AIFF"
    case aac = "AAC"
    case amr = "AMR"
    case mp3 = "MP3"
    case mp4 = "MP4"
    case ogg = "OGG"
    case opus = "OPUS"
    case m4a = "M4A"
    case flac = "FLAC"
    
    var fileExtension: String {
        switch self {
        case .aiff:
            return "aif"
        default:
            return self.rawValue.lowercased()
        }
    }
    
    static func fromFileExtension(_ extension: String) -> AudioFormat? {
        let lowercasedExt = `extension`.lowercased()
        
        // Handle special cases
        if lowercasedExt == "aif" || lowercasedExt == "aiff" {
            return .aiff
        }
        
        // Default case
        return AudioFormat.allCases.first { $0.fileExtension == lowercasedExt }
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
        
        // Handle file URL with our new persistence helper
        if let fileURL = model.fileURL {
            entity.fileURL = fileURL
            entity.fileURLString = FilePersistenceHelper.shared.persistFileURL(fileURL)
        } else if let format = AudioFormat(rawValue: model.format.rawValue) {
            // If no URL is provided but we have format info, generate expected URL
            let expectedURL = AudioFileManager.shared.getSongFileURL(songId: model.id, format: format)
            if FileManager.default.fileExists(atPath: expectedURL.path) {
                entity.fileURL = expectedURL
                entity.fileURLString = FilePersistenceHelper.shared.persistFileURL(expectedURL)
            }
        }
        
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
        // Resolve the file URL using our new helper method
        let fileURL = entity.resolveFileURL()
        
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
            fileURL: fileURL,
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
    // Reference to our file persistence helper
    private let filePersistenceHelper = FilePersistenceHelper.shared
    // Reference to caching services
    private let songCacheService = SongCacheService.shared
    private let audioCacheService = AudioCacheService.shared
    // Reference to error handling service (optional)
    private weak var errorService: ErrorHandlingService?
    
    // Listen for file upload status updates
    private var cancellables = Set<AnyCancellable>()
    
    init(errorService: ErrorHandlingService? = nil) {
        self.errorService = errorService
        
        // Set up subscription to file upload status
        filePersistenceHelper.uploadStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                
                switch status {
                case .failed(_, let error):
                    // Convert to SongError if needed
                    if let fileError = error as? FileStorageError {
                        switch fileError {
                        case .fileNotFound:
                            self.songError = .fileNotFound
                        case .invalidFileFormat(let message):
                            self.songError = .invalidFileFormat(message)
                        default:
                            self.songError = .fileError(fileError.localizedDescription)
                        }
                    } else {
                        self.songError = .fileError(error.localizedDescription)
                    }
                    
                    // Report to error service if available
                    self.errorService?.reportError(self.songError!)
                case .uploading, .completed:
                    // These are handled by specific methods
                    break
                }
            }
            .store(in: &cancellables)
        
        // Load songs from CoreData on initialization
        loadSongs()
    }
    
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
        
        // Create a unique ID for the song
        let songId = UUID().uuidString
        
        // Get file attributes only for file URLs
        var fileSize: Int64? = nil
        var duration: TimeInterval? = nil
        
        if fileURL.isFileURL {
            do {
                // Extract audio metadata
                let (extractedDuration, extractedFileSize) = try AudioFileManager.shared.extractAudioMetadata(from: fileURL)
                duration = extractedDuration
                fileSize = extractedFileSize
            } catch {
                print("Error extracting audio metadata: \(error.localizedDescription)")
                // Continue anyway, we'll try to get this info again after storing
            }
        }
        
        // Start by creating a song with the original URL
        let newSong = Song(
            id: songId,
            name: name,
            fileURL: fileURL, 
            format: format,
            artists: artists,
            lyrics: lyrics,
            dateCreated: Date(),
            fileSize: fileSize,
            duration: duration,
            sessionId: sessionId
        )
        
        // If it's a file URL, we need to permanently store the file
        if fileURL.isFileURL {
            // First add the song to the array with the original URL
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.songs.append(newSong)
                
                // Add to cache immediately for responsive UI
                self.songCacheService.cacheSong(newSong)
            }
            
            // Begin transaction
            let transactionId = TransactionJournal.shared.beginTransaction(
                operation: "uploadSong",
                resourceId: songId,
                sourcePath: fileURL.path,
                metadata: format.rawValue
            )
            
            // Then upload the file in the background
            filePersistenceHelper.uploadSongFile(from: fileURL, songId: songId, format: format)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            print("Failed to upload song file: \(error.localizedDescription)")
                            
                            // Roll back transaction
                            TransactionJournal.shared.failTransaction(
                                id: transactionId,
                                errorMessage: error.localizedDescription
                            )
                            
                            DispatchQueue.main.async {
                                guard let self = self else { return }
                                // Set the error
                                if let fileError = error as? FileStorageError {
                                    switch fileError {
                                    case .fileNotFound:
                                        self.songError = .fileNotFound
                                    case .invalidFileFormat(let message):
                                        self.songError = .invalidFileFormat(message)
                                    default:
                                        self.songError = .fileError(fileError.localizedDescription)
                                    }
                                } else {
                                    self.songError = .fileError(error.localizedDescription)
                                }
                                
                                // Remove the song from the array if upload failed
                                self.songs.removeAll { $0.id == songId }
                                
                                // Remove from cache if upload failed
                                self.songCacheService.removeCachedSong(id: songId)
                            }
                        }
                    },
                    receiveValue: { [weak self] permanentURL in
                        guard let self = self else { return }
                        
                        // Update transaction state
                        TransactionJournal.shared.updateTransaction(
                            id: transactionId,
                            state: .fileOperationCompleted
                        )
                        
                        // Update the song with the permanent URL
                        var updatedSong = newSong
                        updatedSong.fileURL = permanentURL
                        
                        // Try to update fileSize and duration if we couldn't get them earlier
                        if fileSize == nil || duration == nil {
                            do {
                                let (extractedDuration, extractedFileSize) = try AudioFileManager.shared.extractAudioMetadata(from: permanentURL)
                                updatedSong.duration = extractedDuration
                                updatedSong.fileSize = extractedFileSize
                            } catch {
                                print("Error extracting audio metadata after upload: \(error.localizedDescription)")
                            }
                        }
                        
                        // Start caching the audio data in the background
                        _ = self.audioCacheService.cacheAudioData(for: permanentURL)
                        
                        // Now save to CoreData with the permanent URL
                        let result = self.songDataManager.performBackgroundTaskWithResult { [weak self] context -> Result<SongEntity, Error> in
                            guard let self = self else { return .failure(SongError.failedToSave("Self was deallocated")) }
                            return self.songDataManager.saveWithFileReferences(
                                model: updatedSong,
                                in: context
                            ).mapError { $0 as Error }
                        }
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            // Update the song in our published array
                            if let index = self.songs.firstIndex(where: { $0.id == songId }) {
                                self.songs[index] = updatedSong
                                
                                // Update cache with the final song data
                                self.songCacheService.cacheSong(updatedSong)
                            }
                            
                            // Handle any CoreData errors
                            if case .failure(let error) = result {
                                self.songError = .failedToSave("Failed to save song to database: \(error.localizedDescription)")
                                
                                // Transaction failure will be updated via notification
                            } else {
                                // Transaction completion will be handled via notification
                            }
                        }
                    }
                )
                .store(in: &cancellables)
            
            return true
        } else {
            // For non-file URLs (e.g. remote URLs), just save directly
            let result = songDataManager.performBackgroundTaskWithResult { [weak self] context -> Result<SongEntity, Error> in
                guard let self = self else { return .failure(SongError.failedToSave("Self was deallocated")) }
                return self.songDataManager.saveWithFileReferences(
                    model: newSong,
                    in: context
                ).mapError { $0 as Error }
            }
            
            switch result {
            case .success(_):
                // Add song to array and cache
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.songs.append(newSong)
                    self.songCacheService.cacheSong(newSong)
                }
                return true
            case .failure(let error):
                songError = .failedToSave("Failed to save song: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    private func getFileSize(url: URL) -> Int64? {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            return resourceValues.fileSize.map { Int64($0) }
        } catch {
            print("Error getting file size: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func getAudioDuration(url: URL) -> TimeInterval? {
        // Try to use cached data if available
        if let cachedData = audioCacheService.getCachedAudioData(for: url) {
            do {
                let audioPlayer = try AVAudioPlayer(data: cachedData)
                return audioPlayer.duration
            } catch {
                print("Error getting audio duration from cached data: \(error.localizedDescription)")
            }
        }
        
        // Fallback to direct file access
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            return audioPlayer.duration
        } catch {
            print("Error getting audio duration: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Load all songs from CoreData - updated to use the Result approach consistently
    func loadSongs() {
        let context = coreDataManager.viewContext
        let songManager = self.songDataManager // Capture in local variable
        
        // Create sort descriptor
        let sortDescriptor = NSSortDescriptor(key: "dateCreated", ascending: false)
        
        // First validate all song files to update any missing references
        _ = songManager.validateAllSongFiles(in: context)
        
        // Then use songDataManager to fetch with Result
        let result = songManager.fetch(
            sortDescriptors: [sortDescriptor],
            in: context
        )
        
        // Handle the result
        switch result {
        case .success(let entities):
            let loadedSongs = songManager.createModels(from: entities)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.songs = loadedSongs
                // Cache the loaded songs for faster access later
                self.songCacheService.cacheSongs(loadedSongs)
                
                // Prefetch audio for the first few songs to improve playback experience
                let songsToCache = loadedSongs.prefix(3)
                self.audioCacheService.prefetchAudio(for: Array(songsToCache))
            }
        case .failure(let error):
            // For backward compatibility, still set the songError property
            let songError = SongError.failedToLoad("Failed to load songs: \(error.localizedDescription)")
            self.songError = songError
            
            // Report to error handling service if available
            self.errorService?.reportError(songError)
            
            print("Error loading songs from CoreData: \(error.localizedDescription)")
        }
    }
    
    // Fetch songs for a specific session - updated to use Result and caching
    func loadSongsForSession(sessionId: String) -> [Song] {
        guard !sessionId.isEmpty else {
            songError = .failedToLoad("Invalid session ID")
            return []
        }
        
        // Check if songs for this session are already in songs array (and thus, in cache)
        let cachedSessionSongs = songs.filter { $0.sessionId == sessionId }
        if !cachedSessionSongs.isEmpty {
            return cachedSessionSongs
        }
        
        let context = coreDataManager.viewContext
        let songManager = self.songDataManager // Capture in local variable
        
        // Create predicate for session relationship instead of sessionId property
        let predicate = NSPredicate(format: "session.id == %@", sessionId)
        
        // Use songDataManager to fetch with Result
        let result = songManager.fetch(
            predicate: predicate,
            in: context
        )
        
        switch result {
        case .success(let entities):
            let sessionSongs = songManager.createModels(from: entities)
            
            // Cache the loaded songs
            songCacheService.cacheSongs(sessionSongs)
            
            // Prefetch audio data for playback readiness if there aren't too many songs
            if sessionSongs.count <= 5 {
                audioCacheService.prefetchAudio(for: sessionSongs)
            }
            
            return sessionSongs
        case .failure(let error):
            print("Error loading songs for session: \(error.localizedDescription)")
            songError = .failedToLoad("Failed to load songs for session: \(error.localizedDescription)")
            return []
        }
    }
    
    // Delete a song - updated to use Result and also delete the file
    func deleteSong(withID id: String) -> Bool {
        // First, find the song to get its format and URL
        guard let songToDelete = getSong(withID: id) else {
            songError = .songNotFound("Song not found for deletion")
            return false
        }
        
        // Use our enhanced delete method which handles file deletion
        let result = songDataManager.performBackgroundTaskWithResult { [weak self] context -> Result<Void, Error> in
            guard let self = self else { return .failure(SongError.failedToDelete("Self was deallocated")) }
            return self.songDataManager.deleteWithFileById(id: id, in: context)
                .mapError { $0 as Error }
        }
        
        switch result {
        case .success(_):
            // Remove from the published array
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.songs.removeAll { $0.id == id }
            }
            
            // Remove from caches
            songCacheService.removeCachedSong(id: id)
            if let fileURL = songToDelete.fileURL {
                audioCacheService.removeCachedAudio(for: fileURL)
            }
            
            return true
        case .failure(let error):
            songError = .failedToDelete("Failed to delete song: \(error.localizedDescription)")
            return false
        }
    }
    
    // Get a song by ID - now with caching support
    func getSong(withID id: String) -> Song? {
        // Check cache first
        if let cachedSong = songCacheService.getCachedSong(id: id) {
            return cachedSong
        }
        
        // Fall back to array search
        let song = songs.first { $0.id == id }
        
        // If found, add to cache for next time
        if let song = song {
            songCacheService.cacheSong(song)
        }
        
        return song
    }
    
    // Get an audio player for a song, utilizing the cache when possible
    func getAudioPlayer(for song: Song) throws -> AVAudioPlayer {
        do {
            // Use audio cache service to get player
            let player = try audioCacheService.audioPlayer(for: song)
            return player
        } catch {
            // If anything goes wrong, fall back to direct file access
            guard let fileURL = song.fileURL else {
                throw SongError.fileNotFound
            }
            
            do {
                return try AVAudioPlayer(contentsOf: fileURL)
            } catch {
                throw SongError.playbackError("Failed to create audio player: \(error.localizedDescription)")
            }
        }
    }
    
    // Validate all songs and ensure their files exist
    func validateSongs() {
        // Use our enhanced validation method from CoreData
        let result = songDataManager.performBackgroundTaskWithResult { [weak self] context -> Result<[String: Bool], Error> in
            guard let self = self else { return .failure(SongError.failedToLoad("Self was deallocated")) }
            return self.songDataManager.validateAllSongFiles(in: context)
                .mapError { $0 as Error }
        }
        
        switch result {
        case .success(let validationResults):
            // Count of valid and invalid songs
            let validCount = validationResults.values.filter { $0 }.count
            let invalidCount = validationResults.values.filter { !$0 }.count
            
            print("Song validation: \(validCount) valid, \(invalidCount) invalid")
            
            // Reload songs to get updated URLs
            loadSongs()
            
            // Update error state if needed
            if invalidCount > 0 {
                songError = .fileNotFound
            }
            
        case .failure(let error):
            print("Error validating songs: \(error.localizedDescription)")
            songError = .failedToLoad("Failed to validate songs: \(error.localizedDescription)")
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
    
    // MARK: - Cache Management
    
    /// Preload audio for a list of songs
    func preloadAudio(for songs: [Song]) {
        audioCacheService.prefetchAudio(for: songs)
    }
    
    /// Clear all song and audio caches
    func clearCaches() {
        songCacheService.cacheSongs(songs) // Refresh the metadata cache with current state
        CacheManager.shared.audioDataCache.clearCache() // Clear audio data
    }
} 
