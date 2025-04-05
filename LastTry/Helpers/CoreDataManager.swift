import Foundation
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        // Note: Make sure the model name matches the actual .xcdatamodeld file name
        let container = NSPersistentContainer(name: "StudioManager")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Handle the error appropriately instead of using fatalError in a shipping app
                print("CoreData error: \(error), \(error.userInfo)")
                // During development, it can be useful to know when CoreData setup fails
                #if DEBUG
                fatalError("CoreData error: \(error), \(error.userInfo)")
                #endif
            }
        })
        // Better performance by merging changes automatically
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()
    
    // MARK: - Core Data Saving
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("CoreData save error: \(nserror), \(nserror.userInfo)")
                #if DEBUG
                // Only in debug mode, we want to be alerted of these issues
                if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                    // Don't crash during unit testing
                    print("Unresolved CoreData error: \(nserror), \(nserror.userInfo)")
                }
                #endif
            }
        }
    }
    
    // MARK: - Convenience methods
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func createBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // Perform a task in a background context and save
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = createBackgroundContext()
        context.perform {
            block(context)
            
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("Error saving background context: \(error)")
                }
            }
        }
    }
    
    // MARK: - Migration support
    
    /// Checks if this is the first launch of the app with CoreData
    var isFirstLaunch: Bool {
        if UserDefaults.standard.bool(forKey: "coreDataMigrationPerformed") {
            return false
        } else {
            return true
        }
    }
    
    /// Marks the migration as complete
    func markMigrationAsComplete() {
        UserDefaults.standard.set(true, forKey: "coreDataMigrationPerformed")
    }
    
    /// Deletes all records of a given entity type
    func deleteAllRecords(of entityName: String) {
        let context = viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(batchDeleteRequest)
            try context.save()
        } catch {
            print("Error deleting all \(entityName): \(error)")
        }
    }
} 