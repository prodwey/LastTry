import Foundation
import CoreData

extension TaskEntity {
    
    // Convert from TaskEntity (CoreData) to Task (Model)
    func toModel() -> Task {
        let priority = TaskPriority(rawValue: Int(self.priority)) ?? .medium
        
        return Task(
            id: self.id ?? UUID().uuidString,
            title: self.title ?? "",
            description: self.descriptionText ?? "",
            priority: priority,
            createdAt: self.createdAt ?? Date(),
            dueDate: self.dueDate,
            assignedTo: self.assignedTo,
            createdBy: self.createdBy ?? "",
            isCompleted: self.isCompleted
        )
    }
    
    // Create or update TaskEntity from Task model
    static func createOrUpdate(from model: Task, in context: NSManagedObjectContext) -> TaskEntity {
        // Try to find existing entity with matching ID
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", model.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            // Use existing entity or create new one
            let entity = results.first ?? TaskEntity(context: context)
            
            // Update properties
            entity.id = model.id
            entity.title = model.title
            entity.descriptionText = model.description
            entity.priority = Int16(model.priority.rawValue)
            entity.createdAt = model.createdAt
            entity.dueDate = model.dueDate
            entity.assignedTo = model.assignedTo
            entity.createdBy = model.createdBy
            entity.isCompleted = model.isCompleted
            
            return entity
        } catch {
            print("Error fetching TaskEntity: \(error)")
            // If fetch fails, create new entity
            let entity = TaskEntity(context: context)
            entity.id = model.id
            entity.title = model.title
            entity.descriptionText = model.description
            entity.priority = Int16(model.priority.rawValue)
            entity.createdAt = model.createdAt
            entity.dueDate = model.dueDate
            entity.assignedTo = model.assignedTo
            entity.createdBy = model.createdBy
            entity.isCompleted = model.isCompleted
            
            return entity
        }
    }
} 