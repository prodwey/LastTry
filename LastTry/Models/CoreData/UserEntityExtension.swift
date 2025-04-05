import Foundation
import CoreData

extension UserEntity {
    
    // Convert from UserEntity (CoreData) to User (Model)
    func toModel() -> User {
        return User(
            id: self.id ?? UUID().uuidString,
            name: self.name ?? "",
            email: self.email ?? "",
            dateOfBirth: self.dateOfBirth ?? Date(),
            role: UserRole(rawValue: self.role ?? UserRole.artist.rawValue) ?? .artist
        )
    }
    
    // Create or update UserEntity from User model
    static func createOrUpdate(from model: User, in context: NSManagedObjectContext) -> UserEntity {
        // Try to find existing entity with matching ID
        let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", model.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            // Use existing entity or create new one
            let entity = results.first ?? UserEntity(context: context)
            
            // Update properties
            entity.id = model.id
            entity.name = model.name
            entity.email = model.email
            entity.dateOfBirth = model.dateOfBirth
            entity.role = model.role.rawValue
            
            return entity
        } catch {
            print("Error fetching UserEntity: \(error)")
            // If fetch fails, create new entity
            let entity = UserEntity(context: context)
            entity.id = model.id
            entity.name = model.name
            entity.email = model.email
            entity.dateOfBirth = model.dateOfBirth
            entity.role = model.role.rawValue
            
            return entity
        }
    }
} 