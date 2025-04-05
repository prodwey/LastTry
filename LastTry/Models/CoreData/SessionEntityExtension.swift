import Foundation
import CoreData

extension SessionEntity {
    
    // Convert from SessionEntity (CoreData) to Session (Model)
    func toModel() -> Session {
        // Get songs if they exist
        var songModels: [Song]? = nil
        if let songEntities = self.songs as? Set<SongEntity>, !songEntities.isEmpty {
            songModels = songEntities.map { $0.toModel() }
        }
        
        return Session(
            id: self.id ?? UUID().uuidString,
            studio: Studio(rawValue: self.studio ?? Studio.studioA.rawValue) ?? .studioA,
            mainProducer: self.mainProducer ?? "",
            additionalProducers: self.additionalProducers as? [String] ?? [],
            singers: self.singers as? [String] ?? [],
            date: self.date ?? Date(),
            duration: self.duration,
            songs: songModels
        )
    }
    
    // Create or update SessionEntity from Session model
    static func createOrUpdate(from model: Session, in context: NSManagedObjectContext) -> SessionEntity {
        // Try to find existing entity with matching ID
        let fetchRequest: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", model.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            // Use existing entity or create new one
            let entity = results.first ?? SessionEntity(context: context)
            
            // Update properties
            entity.id = model.id
            entity.studio = model.studio.rawValue
            entity.mainProducer = model.mainProducer
            
            // Using direct array assignment - CoreData will handle the transformation
            entity.additionalProducers = model.additionalProducers
            entity.singers = model.singers
            
            entity.date = model.date
            entity.duration = model.duration
            
            // Handle songs relationship if songs exist
            // Note: This just sets up the relationship; songs must be saved separately
            if let songs = model.songs, !songs.isEmpty {
                let songEntities = NSMutableSet()
                
                for song in songs {
                    // Get or create the song entity
                    let songEntity = SongEntity.createOrUpdate(from: song, in: context)
                    songEntities.add(songEntity)
                }
                
                entity.songs = songEntities
            }
            
            return entity
        } catch {
            print("Error fetching SessionEntity: \(error)")
            // If fetch fails, create new entity
            let entity = SessionEntity(context: context)
            entity.id = model.id
            entity.studio = model.studio.rawValue
            entity.mainProducer = model.mainProducer
            
            // Using direct array assignment - CoreData will handle the transformation
            entity.additionalProducers = model.additionalProducers
            entity.singers = model.singers
            
            entity.date = model.date
            entity.duration = model.duration
            
            return entity
        }
    }
} 