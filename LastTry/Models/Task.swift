import Foundation
import CoreData

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