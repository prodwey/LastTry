import Foundation
import CoreData

// Custom error types for task management
enum TaskError: Error, LocalizedError, Equatable {
    case taskNotFound(String)
    case failedToSave(String)
    case failedToLoad(String)
    case failedToUpdate(String)
    case failedToDelete(String)
    case invalidTaskData(String)
    case unauthorizedAccess
    case priorityConflict(String)
    case incompleteTask(String)
    case overdueTask(String)
    case coreDataError(String)
    case aiGenerationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .taskNotFound(let message):
            return "Task not found: \(message)"
        case .failedToSave(let message):
            return "Failed to save task: \(message)"
        case .failedToLoad(let message):
            return "Failed to load tasks: \(message)"
        case .failedToUpdate(let message):
            return "Failed to update task: \(message)"
        case .failedToDelete(let message):
            return "Failed to delete task: \(message)"
        case .invalidTaskData(let message):
            return "Invalid task data: \(message)"
        case .unauthorizedAccess:
            return "Unauthorized access to this task"
        case .priorityConflict(let message):
            return "Priority conflict: \(message)"
        case .incompleteTask(let message):
            return "Task is incomplete: \(message)"
        case .overdueTask(let message):
            return "Task is overdue: \(message)"
        case .coreDataError(let message):
            return "Database error: \(message)"
        case .aiGenerationFailed(let message):
            return "AI generation failed: \(message)"
        }
    }
    
    // Implementation of Equatable for cases with associated values
    static func == (lhs: TaskError, rhs: TaskError) -> Bool {
        switch (lhs, rhs) {
        case (.taskNotFound(let lhs), .taskNotFound(let rhs)):
            return lhs == rhs
        case (.failedToSave(let lhs), .failedToSave(let rhs)):
            return lhs == rhs
        case (.failedToLoad(let lhs), .failedToLoad(let rhs)):
            return lhs == rhs
        case (.failedToUpdate(let lhs), .failedToUpdate(let rhs)):
            return lhs == rhs
        case (.failedToDelete(let lhs), .failedToDelete(let rhs)):
            return lhs == rhs
        case (.invalidTaskData(let lhs), .invalidTaskData(let rhs)):
            return lhs == rhs
        case (.unauthorizedAccess, .unauthorizedAccess):
            return true
        case (.priorityConflict(let lhs), .priorityConflict(let rhs)):
            return lhs == rhs
        case (.incompleteTask(let lhs), .incompleteTask(let rhs)):
            return lhs == rhs
        case (.overdueTask(let lhs), .overdueTask(let rhs)):
            return lhs == rhs
        case (.coreDataError(let lhs), .coreDataError(let rhs)):
            return lhs == rhs
        case (.aiGenerationFailed(let lhs), .aiGenerationFailed(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

enum TaskPriority: Int, Codable, CaseIterable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2
    
    var id: Int { self.rawValue }
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "red"
        }
    }
}

struct Task: Identifiable, Codable {
    var id: String
    var title: String
    var description: String
    var priority: TaskPriority
    var createdAt: Date
    var dueDate: Date?
    var assignedTo: String?
    var createdBy: String
    var isCompleted: Bool
    
    mutating func toggleCompletion() {
        isCompleted.toggle()
    }
    
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return !isCompleted && Date() > dueDate
    }
}

// MARK: - CoreDataConvertible
extension Task: CoreDataConvertible {
    typealias Entity = TaskEntity
    
    func toEntity(in context: NSManagedObjectContext) -> TaskEntity {
        TaskEntity.createOrUpdate(from: self, in: context)
    }
    
    static func fromEntity(_ entity: TaskEntity) -> Task {
        entity.toModel()
    }
}

// MARK: - Task CoreData Manager

class TaskDataManager: CoreDataManaging {
    typealias EntityType = TaskEntity
    typealias ModelType = Task
    
    var entityName: String { "TaskEntity" }
    
    func createEntity(from model: Task, in context: NSManagedObjectContext) -> TaskEntity {
        // Try to find existing entity first
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", model.id)
        
        if let existingEntity = try? context.fetch(fetchRequest).first {
            // Update existing entity
            updateEntity(existingEntity, from: model)
            return existingEntity
        } else {
            // Create new entity
            let entity = TaskEntity(context: context)
            updateEntity(entity, from: model)
            return entity
        }
    }
    
    private func updateEntity(_ entity: TaskEntity, from model: Task) {
        entity.id = model.id
        entity.title = model.title
        entity.descriptionText = model.description
        entity.priority = Int16(model.priority.rawValue)
        entity.createdAt = model.createdAt
        entity.dueDate = model.dueDate
        entity.assignedTo = model.assignedTo
        entity.createdBy = model.createdBy
        entity.isCompleted = model.isCompleted
    }
    
    func createModel(from entity: TaskEntity) -> Task {
        return Task(
            id: entity.id ?? UUID().uuidString,
            title: entity.title ?? "",
            description: entity.descriptionText ?? "",
            priority: TaskPriority(rawValue: Int(entity.priority)) ?? .medium,
            createdAt: entity.createdAt ?? Date(),
            dueDate: entity.dueDate,
            assignedTo: entity.assignedTo,
            createdBy: entity.createdBy ?? "",
            isCompleted: entity.isCompleted
        )
    }
    
    // Convert [TaskEntity] to [Task]
    func createModels(from entities: [TaskEntity]) -> [Task] {
        entities.map { createModel(from: $0) }
    }
}

class TaskManager: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var taskError: TaskError? = nil
    
    // Reference to CoreData manager
    private let coreDataManager = CoreDataManager.shared
    // Reference to the task data manager
    private lazy var taskDataManager = TaskDataManager()
    
    // Load all tasks from CoreData
    func loadTasks() {
        let context = coreDataManager.viewContext
        
        // Create sort descriptor
        let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
        
        // Use taskDataManager to fetch with Result
        let result = taskDataManager.fetch(
            sortDescriptors: [sortDescriptor],
            in: context
        )
        
        switch result {
        case .success(let entities):
            let loadedTasks = taskDataManager.createModels(from: entities)
            DispatchQueue.main.async {
                self.tasks = loadedTasks
            }
        case .failure(let error):
            print("Error loading tasks from CoreData: \(error.localizedDescription)")
            taskError = .failedToLoad("Failed to load tasks: \(error.localizedDescription)")
        }
    }
    
    func addTask(title: String, description: String, priority: TaskPriority, 
                dueDate: Date?, assignedTo: String?, createdBy: String) -> Bool {
        // Validate inputs
        guard !title.isEmpty else {
            taskError = .invalidTaskData("Task title cannot be empty")
            return false
        }
        
        let newTask = Task(
            id: UUID().uuidString,
            title: title,
            description: description,
            priority: priority,
            createdAt: Date(),
            dueDate: dueDate,
            assignedTo: assignedTo,
            createdBy: createdBy,
            isCompleted: false
        )
        
        // Save to CoreData using Result
        let result = taskDataManager.performBackgroundTask { context in
            let saveResult = self.taskDataManager.saveOrUpdate(
                model: newTask, 
                idValue: newTask.id, 
                in: context
            )
            
            switch saveResult {
            case .success(_):
                return .success(())
            case .failure(let error):
                return .failure(error)
            }
        }
        
        switch result {
        case .success(_):
            DispatchQueue.main.async {
                self.tasks.append(newTask)
            }
            return true
        case .failure(let error):
            taskError = .failedToSave("Failed to save task: \(error.localizedDescription)")
            return false
        }
    }
    
    func toggleTaskCompletion(taskId: String) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else {
            taskError = .taskNotFound("Could not find task to toggle completion")
            return false
        }
        
        var updatedTask = tasks[index]
        updatedTask.toggleCompletion()
        
        // Update task in CoreData
        let result = taskDataManager.performBackgroundTask { context in
            return self.taskDataManager.saveOrUpdate(
                model: updatedTask,
                idValue: updatedTask.id,
                in: context
            )
        }
        
        switch result {
        case .success(_):
            DispatchQueue.main.async {
                self.tasks[index] = updatedTask
            }
            return true
        case .failure(let error):
            taskError = .failedToUpdate("Failed to update task completion status: \(error.localizedDescription)")
            return false
        }
    }
    
    func removeTask(taskId: String) -> Bool {
        // Check if task exists
        guard tasks.contains(where: { $0.id == taskId }) else {
            taskError = .taskNotFound("Could not find task to remove")
            return false
        }
        
        // Delete task from CoreData
        let result = taskDataManager.performBackgroundTask { context in
            return self.taskDataManager.deleteById(id: taskId, in: context)
        }
        
        switch result {
        case .success(_):
            DispatchQueue.main.async {
                self.tasks.removeAll { $0.id == taskId }
            }
            return true
        case .failure(let error):
            taskError = .failedToDelete("Failed to delete task: \(error.localizedDescription)")
            return false
        }
    }
    
    func updateTask(task: Task) -> Bool {
        // Check if task exists
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else {
            taskError = .taskNotFound("Could not find task to update")
            return false
        }
        
        // Update task in CoreData
        let result = taskDataManager.performBackgroundTask { context in
            return self.taskDataManager.saveOrUpdate(
                model: task,
                idValue: task.id,
                in: context
            )
        }
        
        switch result {
        case .success(_):
            DispatchQueue.main.async {
                self.tasks[index] = task
            }
            return true
        case .failure(let error):
            taskError = .failedToUpdate("Failed to update task: \(error.localizedDescription)")
            return false
        }
    }
    
    func sortedByPriority() -> [Task] {
        return tasks.sorted { 
            if $0.isCompleted && !$1.isCompleted {
                return false
            } else if !$0.isCompleted && $1.isCompleted {
                return true
            } else if $0.isOverdue && !$1.isOverdue {
                return true
            } else if !$0.isOverdue && $1.isOverdue {
                return false
            } else {
                return $0.priority.rawValue > $1.priority.rawValue
            }
        }
    }
    
    func tasksAssignedTo(userId: String) -> [Task] {
        return tasks.filter { $0.assignedTo == userId }
    }
    
    // Helper method to clear errors
    func clearError() {
        taskError = nil
    }
} 