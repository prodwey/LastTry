import Foundation
import CoreData

enum UserRole: String, CaseIterable, Identifiable, Codable {
    case producer = "Producer"
    case artist = "Artist"
    case admin = "Admin"
    
    var id: String { self.rawValue }
}

struct User: Identifiable, Codable {
    var id: String
    var name: String
    var email: String
    var dateOfBirth: Date
    var role: UserRole
    
    // Authentication-related fields would normally be handled separately
    // and not stored in plain text in a real app
}

// MARK: - CoreDataConvertible
extension User: CoreDataConvertible {
    typealias Entity = UserEntity
    
    func toEntity(in context: NSManagedObjectContext) -> UserEntity {
        UserEntity.createOrUpdate(from: self, in: context)
    }
    
    static func fromEntity(_ entity: UserEntity) -> User {
        entity.toModel()
    }
}

class UserManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoggedIn: Bool = false
    
    private let userDefaultsKey = "currentUser"
    private let isLoggedInKey = "isLoggedIn"
    
    // Reference to CoreData manager
    private let coreDataManager = CoreDataManager.shared
    
    init() {
        loadUserData()
    }
    
    private func loadUserData() {
        // Load isLoggedIn state
        if let isLoggedIn = UserDefaults.standard.object(forKey: isLoggedInKey) as? Bool {
            self.isLoggedIn = isLoggedIn
        }
        
        // Load user data if available
        if isLoggedIn, let userData = UserDefaults.standard.data(forKey: userDefaultsKey) {
            let decoder = JSONDecoder()
            do {
                currentUser = try decoder.decode(User.self, from: userData)
            } catch {
                print("Error decoding user data: \(error.localizedDescription)")
                // Reset state if there's an error
                currentUser = nil
                isLoggedIn = false
                saveUserData()
            }
        }
    }
    
    // Changed from private to public so AppState can call it
    func saveUserData() {
        // Save isLoggedIn state
        UserDefaults.standard.set(isLoggedIn, forKey: isLoggedInKey)
        
        // Save user data if available
        if let user = currentUser, isLoggedIn {
            let encoder = JSONEncoder()
            do {
                let userData = try encoder.encode(user)
                UserDefaults.standard.set(userData, forKey: userDefaultsKey)
            } catch {
                print("Error encoding user data: \(error.localizedDescription)")
            }
        } else {
            // Clean up if user is nil or logged out
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
    }
    
    func signUp(name: String, email: String, password: String, dateOfBirth: Date, role: UserRole) {
        // In a real app, this would make an API call to a backend
        let newUser = User(
            id: UUID().uuidString,
            name: name,
            email: email,
            dateOfBirth: dateOfBirth,
            role: role
        )
        
        self.currentUser = newUser
        self.isLoggedIn = true
        saveUserData()
    }
    
    func login(email: String, password: String) {
        // For demo purposes only - this would validate with a backend in a real app
        if email.contains("@") {
            // Create the user model
            let newUser = User(
                id: UUID().uuidString,
                name: "Demo User",
                email: email,
                dateOfBirth: Date(),
                role: .artist
            )
            
            // Save to CoreData
            coreDataManager.performBackgroundTask { context in
                let _ = newUser.toEntity(in: context)
                
                // Update published properties on main thread
                DispatchQueue.main.async {
                    self.currentUser = newUser
                    self.isLoggedIn = true
                    
                    // For backward compatibility, still save to UserDefaults
                    self.saveUserData()
                }
            }
        }
    }
    
    func logout() {
        self.currentUser = nil
        self.isLoggedIn = false
        saveUserData()
    }
    
    func updateUserProfile(name: String, email: String, dateOfBirth: Date, role: UserRole) -> Bool {
        guard var user = currentUser else { return false }
        
        user.name = name
        user.email = email
        user.dateOfBirth = dateOfBirth
        user.role = role
        
        self.currentUser = user
        saveUserData()
        return true
    }
    
    func updatePassword(currentPassword: String, newPassword: String) -> Bool {
        // In a real app, this would validate the current password and update it securely
        // For demo purposes, we'll just return success
        // This is where you would integrate with a proper auth system
        return true
    }
    
    // Debug function to reset all user data
    func resetUserData() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: isLoggedInKey)
        self.currentUser = nil
        self.isLoggedIn = false
    }
    
    // MARK: - CoreData methods
    
    // Fetch a user by ID from CoreData
    func fetchUser(byID id: String) -> User? {
        let context = coreDataManager.viewContext
        let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let entity = results.first {
                return User.fromEntity(entity)
            }
        } catch {
            print("Error fetching user from CoreData: \(error)")
        }
        
        return nil
    }
    
    // Fetch all users from CoreData
    func fetchAllUsers() -> [User] {
        let context = coreDataManager.viewContext
        let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.map { User.fromEntity($0) }
        } catch {
            print("Error fetching users from CoreData: \(error)")
            return []
        }
    }
} 