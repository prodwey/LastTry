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
        do {
            let entity = createEntity(from: model, in: context)
            
            // Save all changes
            try context.save()
            
            return .success(entity)
        } catch {
            return .failure(.saveFailed(error.localizedDescription))
        }
    }
    
    /// Delete an entity by ID
    func deleteById(
        id: String,
        idKey: String = "id",
        in context: NSManagedObjectContext,
        transactionId: String? = nil
    ) -> Result<Void, CoreDataError> {
        // Begin a transaction to ensure atomicity
        context.transactionAuthor = "deleteById"
        
        switch fetchById(id: id, idKey: idKey, in: context) {
        case .success(let fetchedEntity):
            // Check if the entity exists before trying to delete it
            if let entityToDelete = fetchedEntity {
                // Notify about database operation start if we have a transaction ID
                if let transactionId = transactionId {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DatabaseOperationStarted"),
                        object: nil,
                        userInfo: [
                            "transactionId": transactionId,
                            "operation": "deleteById"
                        ]
                    )
                }
                
                context.delete(entityToDelete)
                
                do {
                    try context.save()
                    
                    // Notify about database operation completion if we have a transaction ID
                    if let transactionId = transactionId {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("DatabaseOperationCompleted"),
                            object: nil,
                            userInfo: [
                                "transactionId": transactionId,
                                "operation": "deleteById",
                                "success": true
                            ]
                        )
                    }
                    
                    return .success(())
                } catch {
                    // Roll back the transaction
                    context.rollback()
                    
                    // Notify about database operation failure if we have a transaction ID
                    if let transactionId = transactionId {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("DatabaseOperationFailed"),
                            object: nil,
                            userInfo: [
                                "transactionId": transactionId,
                                "operation": "deleteById",
                                "error": error.localizedDescription
                            ]
                        )
                    }
                    
                    return .failure(.deleteFailed(error.localizedDescription))
                }
            } else {
                // Entity not found is not necessarily an error when deleting
                // It might have been deleted already
                return .success(())
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
    
    /// Save with file references - handles atomic database + file operation
    func saveWithFileReferences(
        model: ModelType,
        in context: NSManagedObjectContext
    ) -> Result<EntityType, CoreDataError> {
        // Begin a transaction to ensure atomicity
        context.transactionAuthor = "fileReferenceSave"
        
        // Notify TransactionJournal about database operation start
        if let song = model as? Song {
            let metadata = try? JSONEncoder().encode(["operation": "saveWithFileReferences"])
            
            // Only log to journal if we're not already in a transaction
            // (the file operation should have already started one)
            NotificationCenter.default.post(
                name: NSNotification.Name("DatabaseOperationStarted"),
                object: nil,
                userInfo: [
                    "resourceId": song.id,
                    "operation": "saveWithFileReferences"
                ]
            )
        }
        
        do {
            // Create the entity from the model
            let entity = createEntity(from: model, in: context)
            
            // Save the context to persist changes
            try context.save()
            
            // Notify TransactionJournal about database operation completion
            if let song = model as? Song {
                NotificationCenter.default.post(
                    name: NSNotification.Name("DatabaseOperationCompleted"),
                    object: nil,
                    userInfo: [
                        "resourceId": song.id,
                        "operation": "saveWithFileReferences",
                        "success": true
                    ]
                )
            }
            
            return .success(entity)
        } catch {
            // Attempt to roll back the transaction
            context.rollback()
            
            // Notify TransactionJournal about database operation failure
            if let song = model as? Song {
                NotificationCenter.default.post(
                    name: NSNotification.Name("DatabaseOperationFailed"),
                    object: nil,
                    userInfo: [
                        "resourceId": song.id,
                        "operation": "saveWithFileReferences",
                        "error": error.localizedDescription
                    ]
                )
            }
            
            return .failure(.saveFailed(error.localizedDescription))
        }
    }
    
    /// Transactional save with proper rollback and error handling
    func transactionalSave<T>(
        operation: String,
        resourceId: String,
        in context: NSManagedObjectContext,
        work: () throws -> T
    ) -> Result<T, CoreDataError> {
        // Set transaction metadata
        context.transactionAuthor = operation
        
        // Notify about database operation start
        NotificationCenter.default.post(
            name: NSNotification.Name("DatabaseOperationStarted"),
            object: nil,
            userInfo: [
                "resourceId": resourceId,
                "operation": operation
            ]
        )
        
        do {
            // Execute the work within a transaction
            let result = try work()
            
            // Save changes
            if context.hasChanges {
                try context.save()
            }
            
            // Notify about database operation completion
            NotificationCenter.default.post(
                name: NSNotification.Name("DatabaseOperationCompleted"),
                object: nil,
                userInfo: [
                    "resourceId": resourceId,
                    "operation": operation,
                    "success": true
                ]
            )
            
            return .success(result)
        } catch {
            // Roll back changes
            context.rollback()
            
            // Notify about database operation failure
            NotificationCenter.default.post(
                name: NSNotification.Name("DatabaseOperationFailed"),
                object: nil,
                userInfo: [
                    "resourceId": resourceId,
                    "operation": operation,
                    "error": error.localizedDescription
                ]
            )
            
            return .failure(.saveFailed(error.localizedDescription))
        }
    }
}

// MARK: - File Management Extensions

extension CoreDataManaging where ModelType == Song, EntityType == SongEntity {
    
    /// Delete an entity by ID, including its associated file
    func deleteWithFileById(id: String, in context: NSManagedObjectContext) -> Result<Void, CoreDataError> {
        // First find the entity to get its format information
        let result = fetchById(id: id, in: context)
        
        switch result {
        case .success(let entityOptional):
            guard let entity = entityOptional else {
                return .success(()) // Entity not found, nothing to delete
            }
            
            // Get format and create AudioFormat if possible
            guard let formatString = entity.format,
                  let format = AudioFormat(rawValue: formatString) else {
                // Continue with entity deletion even if format is invalid
                return deleteById(id: id, in: context)
            }
            
            // Check if the file exists
            if AudioFileManager.shared.songAudioFileExists(songId: id, format: format) {
                do {
                    // Begin file operation with transaction journal
                    let transactionId = TransactionJournal.shared.beginTransaction(
                        operation: "deleteSong",
                        resourceId: id,
                        metadata: formatString
                    )
                    
                    // Delete the file first
                    try AudioFileManager.shared.deleteSongAudioFile(songId: id, format: format)
                    
                    // Update transaction state
                    TransactionJournal.shared.updateTransaction(id: transactionId, state: .fileOperationCompleted)
                    
                    // Now delete the entity with the transaction ID
                    let deleteResult = deleteById(id: id, in: context, transactionId: transactionId)
                    
                    switch deleteResult {
                    case .success(_):
                        // Transaction completion is handled by notification
                        return .success(())
                    case .failure(let error):
                        // Transaction failure is handled by notification
                        return .failure(error)
                    }
                    
                } catch {
                    // If file deletion fails but isn't critical, continue with entity deletion
                    print("Warning: Failed to delete audio file: \(error.localizedDescription)")
                    return deleteById(id: id, in: context)
                }
            } else {
                // No file to delete, just remove the entity
                return deleteById(id: id, in: context)
            }
            
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Enhanced save with file references that ensures atomicity between file and database operations
    func saveWithFileReferences(model: Song, in context: NSManagedObjectContext) -> Result<SongEntity, CoreDataError> {
        // Check if we need to update the file URL
        var updatedModel = model
        
        // Use transactional save for atomicity
        return transactionalSave(
            operation: "saveSongWithFileReferences",
            resourceId: model.id,
            in: context
        ) {
            // If we don't have a file URL but we have format and ID, try to resolve the URL
            if updatedModel.fileURL == nil, 
               !updatedModel.id.isEmpty,
               let format = AudioFormat(rawValue: updatedModel.format.rawValue) {
                
                // Check if file exists at the expected location
                if AudioFileManager.shared.songAudioFileExists(songId: updatedModel.id, format: format) {
                    do {
                        // Get the URL and update the model
                        let url = try AudioFileManager.shared.getSongAudioFile(songId: updatedModel.id, format: format)
                        updatedModel.fileURL = url
                        
                        // If we're missing metadata, try to extract it
                        if updatedModel.fileSize == nil || updatedModel.duration == nil {
                            do {
                                let (duration, fileSize) = try AudioFileManager.shared.extractAudioMetadata(from: url)
                                if updatedModel.duration == nil {
                                    updatedModel.duration = duration
                                }
                                if updatedModel.fileSize == nil {
                                    updatedModel.fileSize = fileSize
                                }
                            } catch {
                                print("Warning: Couldn't extract metadata: \(error.localizedDescription)")
                            }
                        }
                    } catch {
                        print("Warning: Couldn't resolve audio file: \(error.localizedDescription)")
                    }
                }
            }
            
            // Create the entity from the updated model
            let entity = createEntity(from: updatedModel, in: context)
            
            // Return the entity - the transactionalSave method will handle saving and errors
            return entity
        }
    }
    
    /// Perform a batch operation on all songs, validating their file references
    func validateAllSongFiles(in context: NSManagedObjectContext) -> Result<[String: Bool], CoreDataError> {
        let result = fetch(in: context)
        
        switch result {
        case .success(let entities):
            var validationResults = [String: Bool]()
            
            for entity in entities {
                guard let id = entity.id, let format = entity.format else { continue }
                
                if let audioFormat = AudioFormat(rawValue: format) {
                    let exists = AudioFileManager.shared.songAudioFileExists(songId: id, format: audioFormat)
                    validationResults[id] = exists
                    
                    // Update the entity's file URL if needed
                    if exists && entity.fileURL == nil {
                        do {
                            let url = try AudioFileManager.shared.getSongAudioFile(songId: id, format: audioFormat)
                            entity.fileURL = url
                            entity.fileURLString = FilePersistenceHelper.shared.persistFileURL(url)
                        } catch {
                            print("Warning: Couldn't update file URL: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            // Save changes if we made any
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("Warning: Couldn't save file validation updates: \(error.localizedDescription)")
                }
            }
            
            return .success(validationResults)
            
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Perform a background task that returns a Result
    func performBackgroundTaskWithResult<T>(_ block: @escaping (NSManagedObjectContext) -> Result<T, Error>) -> Result<T, Error> {
        // Create a semaphore to make this synchronous
        let semaphore = DispatchSemaphore(value: 0)
        
        // Create a container for the result
        var operationResult: Result<T, Error> = .failure(CoreDataError.invalidOperation("Operation did not complete"))
        
        // Get a background context
        let context = CoreDataManager.shared.createBackgroundContext()
        
        // Perform the operation on the context
        context.perform {
            operationResult = block(context)
            
            // If we have changes and the operation succeeded, save the context
            if case .success(_) = operationResult, context.hasChanges {
                do {
                    try context.save()
                } catch {
                    operationResult = .failure(CoreDataError.saveFailed(error.localizedDescription))
                }
            }
            
            // Signal that we're done
            semaphore.signal()
        }
        
        // Wait for the operation to complete (with a timeout)
        _ = semaphore.wait(timeout: .now() + 10.0)
        
        return operationResult
    }
} 