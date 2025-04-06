import Foundation
import CoreData

/// A generic error type for CoreData operations
enum CoreDataError: Error, LocalizedError {
    case fetchFailed(String)
    case saveFailed(String)
    case deleteFailed(String)
    case entityNotFound
    case invalidModel
    case invalidOperation(String)
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Failed to fetch data: \(message)"
        case .saveFailed(let message):
            return "Failed to save data: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete data: \(message)"
        case .entityNotFound:
            return "Entity not found"
        case .invalidModel:
            return "Invalid model data"
        case .invalidOperation(let message):
            return "Invalid operation: \(message)"
        }
    }
}

/// Protocol for CoreData managers to implement standard CRUD operations
protocol CoreDataManaging {
    associatedtype EntityType: NSManagedObject
    associatedtype ModelType
    
    /// Convert from domain model to CoreData entity
    func createEntity(from model: ModelType, in context: NSManagedObjectContext) -> EntityType
    
    /// Convert from CoreData entity to domain model
    func createModel(from entity: EntityType) -> ModelType
    
    /// Get the entity name for fetch requests
    var entityName: String { get }
}

extension CoreDataManaging {
    /// Fetch entities with an optional predicate and sort descriptors
    func fetch(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        in context: NSManagedObjectContext
    ) -> Result<[EntityType], CoreDataError> {
        let fetchRequest = NSFetchRequest<EntityType>(entityName: entityName)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = sortDescriptors
        
        do {
            let results = try context.fetch(fetchRequest)
            return .success(results)
        } catch {
            return .failure(.fetchFailed(error.localizedDescription))
        }
    }
    
    /// Fetch a single entity by ID
    func fetchById(
        id: String,
        idKey: String = "id",
        in context: NSManagedObjectContext
    ) -> Result<EntityType?, CoreDataError> {
        let predicate = NSPredicate(format: "%K == %@", idKey, id)
        
        switch fetch(predicate: predicate, in: context) {
        case .success(let entities):
            return .success(entities.first)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Save or update an entity from a model
    func saveOrUpdate(
        model: ModelType,
        idValue: String,
        idKey: String = "id",
        in context: NSManagedObjectContext
    ) -> Result<EntityType, CoreDataError> {
        // First try to find the existing entity
        switch fetchById(id: idValue, idKey: idKey, in: context) {
        case .success(let existingEntity):
            if let entity = existingEntity {
                // Update the existing entity with new model data
                // The implementation will update the entity's properties
                let updatedEntity = createEntity(from: model, in: context)
                return .success(updatedEntity)
            } else {
                // Create a new entity
                let newEntity = createEntity(from: model, in: context)
                
                // Save the context
                do {
                    try context.save()
                    return .success(newEntity)
                } catch {
                    return .failure(.saveFailed(error.localizedDescription))
                }
            }
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Delete an entity by ID
    func deleteById(
        id: String,
        idKey: String = "id",
        in context: NSManagedObjectContext
    ) -> Result<Void, CoreDataError> {
        switch fetchById(id: id, idKey: idKey, in: context) {
        case .success(let entity):
            guard let entity = entity else {
                return .failure(.entityNotFound)
            }
            
            context.delete(entity)
            
            do {
                try context.save()
                return .success(())
            } catch {
                return .failure(.deleteFailed(error.localizedDescription))
            }
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Save changes in a context
    func saveContext(_ context: NSManagedObjectContext) -> Result<Void, CoreDataError> {
        guard context.hasChanges else { return .success(()) }
        
        do {
            try context.save()
            return .success(())
        } catch {
            return .failure(.saveFailed(error.localizedDescription))
        }
    }
    
    /// Perform an operation in a background context and return the result
    func performBackgroundTask<T>(
        operation: @escaping (NSManagedObjectContext) -> Result<T, CoreDataError>
    ) -> Result<T, CoreDataError> {
        let context = CoreDataManager.shared.createBackgroundContext()
        var result: Result<T, CoreDataError> = .failure(.invalidOperation("Task did not complete"))
        
        let semaphore = DispatchSemaphore(value: 0)
        
        context.perform {
            result = operation(context)
            semaphore.signal()
        }
        
        // Wait for the operation to complete
        _ = semaphore.wait(timeout: .now() + 10.0)  // Add timeout to prevent deadlock
        
        return result
    }
    
    /// Perform an async operation in a background context
    func performBackgroundTaskAsync<T>(
        operation: @escaping (NSManagedObjectContext) -> Result<T, CoreDataError>
    ) async -> Result<T, CoreDataError> {
        await withCheckedContinuation { continuation in
            let context = CoreDataManager.shared.createBackgroundContext()
            
            context.perform {
                let result = operation(context)
                continuation.resume(returning: result)
            }
        }
    }
} 