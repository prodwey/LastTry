import Foundation
import CoreData
import AVFoundation

extension SongEntity {
    
    // Convert from SongEntity (CoreData) to Song (Model)
    func toModel() -> Song {
        // Convert artists if they exist
        var artistModels: [Artist] = []
        if let artistEntities = self.artists as? Set<ArtistEntity>, !artistEntities.isEmpty {
            artistModels = artistEntities.map { $0.toModel() }
        }
        
        // No need to convert - fileURL is already a URL in CoreData
        return Song(
            id: self.id ?? UUID().uuidString,
            name: self.name ?? "",
            fileURL: self.fileURL,
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
            
            // Direct assignment - no need to convert URL to string
            entity.fileURL = model.fileURL
            
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
            
            // Direct assignment - no need to convert URL to string
            entity.fileURL = model.fileURL
            
            entity.format = model.format.rawValue
            entity.lyrics = model.lyrics
            entity.dateCreated = model.dateCreated
            entity.fileSize = model.fileSize ?? 0
            entity.duration = model.duration ?? 0
            
            return entity
        }
    }
} 