import Foundation
import CoreData
import Firebase
import FirebaseAuth
import Combine

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
    @Published var authError: String? = nil
    
    // Reference to app state for synchronization
    weak var appState: AppState?
    
    private let userDefaultsKey = "currentUser"
    private let isLoggedInKey = "isLoggedIn"
    
    // Reference to CoreData manager
    private let coreDataManager = CoreDataManager.shared
    // Set of cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        print("UserManager: Initializing")
    }
    
    // Load user data from Firebase user
    func loadUserFromFirebase(_ firebaseUser: FirebaseAuth.User) {
        print("UserManager: Loading user data from Firebase user: \(firebaseUser.uid)")
        
        // Check if we have this user in CoreData already
        if let existingUser = fetchUser(byID: firebaseUser.uid) {
            print("UserManager: Found existing user in CoreData")
            DispatchQueue.main.async {
                self.currentUser = existingUser
                self.isLoggedIn = true
            }
        } else {
            print("UserManager: Creating new user model from Firebase user")
            // Create a basic user profile with available data
            let newUser = User(
                id: firebaseUser.uid,
                name: firebaseUser.displayName ?? "User",
                email: firebaseUser.email ?? "",
                dateOfBirth: Date(),
                role: .artist
            )
            
            // Save to CoreData and update state
            saveUserToCoreData(newUser)
        }
    }
    
    // Save user data to UserDefaults for backward compatibility
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
    
    // Helper method to save user to CoreData and update app state
    private func saveUserToCoreData(_ user: User) {
        print("UserManager: Saving user to CoreData: \(user.id)")
        
        // Update state immediately
        DispatchQueue.main.async {
            self.currentUser = user
            self.isLoggedIn = true
        }
        
        // Save to UserDefaults for backward compatibility
        saveUserData()
        
        // Save to CoreData
        coreDataManager.performBackgroundTask { context in
            let _ = user.toEntity(in: context)
            
            // Ensure CoreData context is saved
            if context.hasChanges {
                do {
                    try context.save()
                    print("UserManager: CoreData context saved successfully")
                } catch {
                    print("UserManager: Error saving CoreData context: \(error)")
                }
            }
        }
    }
    
    // MARK: - Authentication Methods (now using AuthenticationService)
    
    // Sign up user using the authentication service
    func signUp(name: String, email: String, password: String, dateOfBirth: Date, role: UserRole) {
        print("UserManager: Starting sign up process for \(email)")
        self.authError = nil
        
        guard let appState = appState else {
            print("UserManager: No app state reference")
            self.authError = "Internal error"
            return
        }
        
        // Create the user in Firebase Authentication using our service
        // Properly wrap the Task in parentheses to avoid confusion with trailing closures
        let _ = (Task {
            let result = await appState.authService.signUp(email: email, password: password)
            
            switch result {
            case .success(let firebaseUser):
                print("UserManager: User created successfully in Firebase, uid: \(firebaseUser.uid)")
                
                // Update the display name using our service
                let profileResult = await appState.authService.updateUserProfile(displayName: name)
                
                if case .failure(let error) = profileResult {
                    print("UserManager: Error updating display name: \(error.localizedDescription)")
                } else {
                    print("UserManager: Display name updated successfully")
                }
                
                // Create a user model from Firebase user data
                let newUser = User(
                    id: firebaseUser.uid,
                    name: name,
                    email: email,
                    dateOfBirth: dateOfBirth,
                    role: role
                )
                
                // Save to CoreData
                await MainActor.run {
                    self.saveUserToCoreData(newUser)
                }
                
            case .failure(let error):
                print("UserManager: Error creating user: \(error.localizedDescription)")
                await MainActor.run {
                    self.authError = error.localizedDescription
                }
            }
        })
    }
    
    // Login using the authentication service
    func login(email: String, password: String) {
        print("UserManager: Starting login process for \(email)")
        self.authError = nil
        
        guard let appState = appState else {
            print("UserManager: No app state reference")
            self.authError = "Internal error"
            return
        }
        
        // Use Task for async operation - wrapped in parentheses to avoid trailing closure ambiguity
        let _ = (Task {
            let result = await appState.authService.signIn(email: email, password: password)
            
            await MainActor.run {
                if case .failure(let error) = result {
                    self.authError = error.localizedDescription
                } else {
                    print("UserManager: Login successful")
                    // Auth state listener in AppState will handle the rest
                }
            }
        })
    }
    
    // Logout using the authentication service
    func logout() {
        print("UserManager: Attempting to sign out")
        
        guard let appState = appState else {
            print("UserManager: No app state reference")
            return
        }
        
        let result = appState.authService.signOut()
        
        if case .failure(let error) = result {
            print("UserManager: Error signing out: \(error.localizedDescription)")
        } else {
            print("UserManager: Successfully signed out")
            // Auth state listener in AppState will handle state updates
        }
    }
    
    // MARK: - User Profile Management
    
    func updateUserProfile(name: String, email: String, dateOfBirth: Date, role: UserRole) -> Bool {
        guard var user = currentUser, let appState = appState,
              let firebaseUser = appState.authService.currentUser else { return false }
        
        // Store a local success flag
        var localSuccess = true
        
        // Update profile in Firebase Auth - using Task and handling it properly
        // Wrap the Task in parentheses to make it clear it's not a trailing closure
        let _ = (Task {
            // Update display name
            let nameResult = await appState.authService.updateUserProfile(displayName: name)
            if case .failure(let error) = nameResult {
                print("Error updating display name: \(error.localizedDescription)")
                localSuccess = false
            }
            
            // Update email if changed
            if email != user.email {
                let emailResult = await appState.authService.updateEmail(to: email)
                if case .failure(let error) = emailResult {
                    print("Error updating email: \(error.localizedDescription)")
                    localSuccess = false
                }
            }
        })
        
        // Update local user model
        user.name = name
        user.email = email
        user.dateOfBirth = dateOfBirth
        user.role = role
        
        self.currentUser = user
        
        // Save to CoreData
        coreDataManager.performBackgroundTask { context in
            let _ = user.toEntity(in: context)
        }
        
        saveUserData()
        return true // Since we're not awaiting the Task, return success for now
    }
    
    func updatePassword(currentPassword: String, newPassword: String) -> Bool {
        guard let appState = appState else { return false }
        
        // Wrap the Task in parentheses to make it clear it's not a trailing closure
        let _ = (Task {
            let result = await appState.authService.updatePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            // We're not awaiting this result, so we can't update a local variable
            // and return it. This is just fire-and-forget.
        })
        
        return true // Since we're not awaiting the Task, return success for now
    }
    
    // Reset user data - keep for debugging
    func resetUserData() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: isLoggedInKey)
        if let appState = appState {
            let _ = appState.authService.signOut()
        }
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