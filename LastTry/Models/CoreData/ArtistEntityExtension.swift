import Foundation
import CoreData

extension ArtistEntity {
    
    // Convert from ArtistEntity (CoreData) to Artist (Model)
    func toModel() -> Artist {
        return Artist(
            id: self.id ?? UUID().uuidString,
            name: self.name ?? "",
            cpf: self.cpf,
            rg: self.rg,
            dateOfBirth: self.dateOfBirth,
            email: self.email,
            phone: self.phone,
            publisher: self.publisher,
            recordingLabel: self.recordingLabel
        )
    }
    
    // Create or update ArtistEntity from Artist model
    static func createOrUpdate(from model: Artist, in context: NSManagedObjectContext) -> ArtistEntity {
        // Try to find existing entity with matching ID
        let fetchRequest: NSFetchRequest<ArtistEntity> = ArtistEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", model.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            // Use existing entity or create new one
            let entity = results.first ?? ArtistEntity(context: context)
            
            // Update properties
            entity.id = model.id
            entity.name = model.name
            entity.cpf = model.cpf
            entity.rg = model.rg
            entity.dateOfBirth = model.dateOfBirth
            entity.email = model.email
            entity.phone = model.phone
            entity.publisher = model.publisher
            entity.recordingLabel = model.recordingLabel
            
            return entity
        } catch {
            print("Error fetching ArtistEntity: \(error)")
            // If fetch fails, create new entity
            let entity = ArtistEntity(context: context)
            entity.id = model.id
            entity.name = model.name
            entity.cpf = model.cpf
            entity.rg = model.rg
            entity.dateOfBirth = model.dateOfBirth
            entity.email = model.email
            entity.phone = model.phone
            entity.publisher = model.publisher
            entity.recordingLabel = model.recordingLabel
            
            return entity
        }
    }
} 