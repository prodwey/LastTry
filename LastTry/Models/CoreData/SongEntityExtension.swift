import Foundation
import CoreData
import AVFoundation

extension SongEntity {
    
    // MARK: - Persistent File URL Handling
    
    /// The persisted file URL string
    @objc var fileURLString: String? {
        get {
            // If fileURL is already a string, return it directly
            if let urlString = self.primitiveValue(forKey: "fileURLString") as? String {
                return urlString
            }
            
            // If we have a URL, convert it to a string for persistence
            if let fileURL = self.fileURL {
                let urlString = FilePersistenceHelper.shared.persistFileURL(fileURL)
                self.setPrimitiveValue(urlString, forKey: "fileURLString")
                return urlString
            }
            
            return nil
        }
        set {
            self.setPrimitiveValue(newValue, forKey: "fileURLString")
            
            // Also update the fileURL property for convenience
            if let urlString = newValue {
                self.fileURL = FilePersistenceHelper.shared.restoreFileURL(from: urlString)
            } else {
                self.fileURL = nil
            }
        }
    }
    
    // MARK: - Model Conversion
    
    // Convert from SongEntity (CoreData) to Song (Model)
    func toModel() -> Song {
        // Convert artists if they exist
        var artistModels: [Artist] = []
        if let artistEntities = self.artists as? Set<ArtistEntity>, !artistEntities.isEmpty {
            artistModels = artistEntities.map { $0.toModel() }
        }
        
        // Get the file URL, either directly or from the string representation
        var url = self.fileURL
        if url == nil && self.fileURLString != nil {
            url = FilePersistenceHelper.shared.restoreFileURL(from: self.fileURLString)
        }
        
        return Song(
            id: self.id ?? UUID().uuidString,
            name: self.name ?? "",
            fileURL: url,
            format: AudioFormat(rawValue: self.format ?? AudioFormat.mp3.rawValue) ?? .mp3,
            artists: artistModels,
            lyrics: self.lyrics,
            dateCreated: self.dateCreated ?? Date(),
            fileSize: self.fileSize,
            duration: self.duration,
            sessionId: (self.session?.id) ?? ""
        )
    }
    
    // Create or update SongEntity from Song model
    static func createOrUpdate(from model: Song, in context: NSManagedObjectContext) -> SongEntity {
        // Try to find existing entity with matching ID
        let fetchRequest: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", model.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            // Use existing entity or create new one
            let entity = results.first ?? SongEntity(context: context)
            
            // Update properties
            entity.id = model.id
            entity.name = model.name
            
            // Store both the direct URL and the string representation
            entity.fileURL = model.fileURL
            entity.fileURLString = FilePersistenceHelper.shared.persistFileURL(model.fileURL)
            
            entity.format = model.format.rawValue
            entity.lyrics = model.lyrics
            entity.dateCreated = model.dateCreated
            entity.fileSize = model.fileSize ?? 0
            entity.duration = model.duration ?? 0
            
            // Handle artists relationship
            if !model.artists.isEmpty {
                let artistEntities = NSMutableSet()
                
                for artist in model.artists {
                    // Get or create the artist entity
                    let artistEntity = ArtistEntity.createOrUpdate(from: artist, in: context)
                    artistEntities.add(artistEntity)
                }
                
                entity.artists = artistEntities
            }
            
            // Find and set session relationship if session ID exists
            if !model.sessionId.isEmpty {
                let sessionFetchRequest: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
                sessionFetchRequest.predicate = NSPredicate(format: "id == %@", model.sessionId)
                
                do {
                    let sessionResults = try context.fetch(sessionFetchRequest)
                    if let sessionEntity = sessionResults.first {
                        entity.session = sessionEntity
                    }
                } catch {
                    print("Error fetching session for song: \(error)")
                }
            }
            
            return entity
        } catch {
            print("Error fetching SongEntity: \(error)")
            // If fetch fails, create new entity
            let entity = SongEntity(context: context)
            entity.id = model.id
            entity.name = model.name
            
            // Store both the direct URL and the string representation
            entity.fileURL = model.fileURL
            entity.fileURLString = FilePersistenceHelper.shared.persistFileURL(model.fileURL)
            
            entity.format = model.format.rawValue
            entity.lyrics = model.lyrics
            entity.dateCreated = model.dateCreated
            entity.fileSize = model.fileSize ?? 0
            entity.duration = model.duration ?? 0
            
            return entity
        }
    }
    
    // MARK: - File Validation
    
    /// Validate that the associated audio file exists
    func validateAudioFile() -> Bool {
        guard let id = self.id, let format = self.format else {
            return false
        }
        
        if let audioFormat = AudioFormat(rawValue: format) {
            return AudioFileManager.shared.songAudioFileExists(songId: id, format: audioFormat)
        }
        
        return false
    }
    
    /// Get the file URL for this song, generating it from ID and format if necessary
    func resolveFileURL() -> URL? {
        // First try the direct URL property
        if let url = self.fileURL, FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        
        // Then try the string representation
        if let urlString = self.fileURLString, 
           let url = FilePersistenceHelper.shared.restoreFileURL(from: urlString),
           FileManager.default.fileExists(atPath: url.path) {
            // Update the direct URL property
            self.fileURL = url
            return url
        }
        
        // Finally, try to generate from ID and format
        if let id = self.id, let formatString = self.format, 
           let format = AudioFormat(rawValue: formatString) {
            
            // Check if the file exists at the expected location
            if AudioFileManager.shared.songAudioFileExists(songId: id, format: format) {
                do {
                    let url = try AudioFileManager.shared.getSongAudioFile(songId: id, format: format)
                    
                    // Update the properties
                    self.fileURL = url
                    self.fileURLString = FilePersistenceHelper.shared.persistFileURL(url)
                    
                    return url
                } catch {
                    print("Error resolving file URL: \(error)")
                }
            }
        }
        
        return nil
    }
} 