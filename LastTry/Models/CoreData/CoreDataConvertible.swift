import Foundation
import CoreData

// Protocol to define conversion between domain models and CoreData entities
protocol CoreDataConvertible {
    associatedtype Entity
    
    // Convert from domain model to CoreData entity
    func toEntity(in context: NSManagedObjectContext) -> Entity
    
    // Create a domain model from a CoreData entity
    static func fromEntity(_ entity: Entity) -> Self
}

// Protocol for Core Data entities that can be converted to domain models
protocol DomainConvertible {
    associatedtype Model
    
    // Convert from CoreData entity to domain model
    func toModel() -> Model
    
    // Create or update entity from domain model
    static func createOrUpdate(from model: Model, in context: NSManagedObjectContext) -> Self
} 