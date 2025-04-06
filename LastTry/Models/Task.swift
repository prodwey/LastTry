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

class TaskManager: ObservableObject {
    @Published var tasks: [Task] = []
    
    // Reference to CoreData manager
    private let coreDataManager = CoreDataManager.shared
    
    func addTask(title: String, description: String, priority: TaskPriority, 
                dueDate: Date?, assignedTo: String?, createdBy: String) {
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
        
        tasks.append(newTask)
    }
    
    func toggleTaskCompletion(taskId: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[index].toggleCompletion()
    }
    
    func removeTask(taskId: String) {
        tasks.removeAll { $0.id == taskId }
    }
    
    func updateTask(task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
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
} 