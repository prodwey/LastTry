import Foundation
import CoreData
import Firebase
import FirebaseAuth

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
    
    func signUp(name: String, email: String, password: String, dateOfBirth: Date, role: UserRole) {
        print("UserManager: Starting sign up process for \(email)")
        self.authError = nil
        
        // Create the user in Firebase Authentication
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error {
                print("UserManager: Error creating user: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.authError = error.localizedDescription
                }
                return
            }
            
            guard let authResult = authResult else {
                print("UserManager: Authentication result is nil")
                DispatchQueue.main.async {
                    self.authError = "Authentication result is nil"
                }
                return
            }
            
            print("UserManager: User created successfully in Firebase, uid: \(authResult.user.uid)")
            
            // Update the display name
            let changeRequest = authResult.user.createProfileChangeRequest()
            changeRequest.displayName = name
            changeRequest.commitChanges { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    print("UserManager: Error updating display name: \(error.localizedDescription)")
                } else {
                    print("UserManager: Display name updated successfully")
                }
                
                // Create a user model from Firebase user data
                let newUser = User(
                    id: authResult.user.uid,
                    name: name,
                    email: email,
                    dateOfBirth: dateOfBirth,
                    role: role
                )
                
                // Save to CoreData
                self.saveUserToCoreData(newUser)
            }
        }
    }
    
    func login(email: String, password: String) {
        print("UserManager: Starting login process for \(email)")
        self.authError = nil
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error {
                print("UserManager: Error signing in: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.authError = error.localizedDescription
                }
                return
            }
            
            // Auth state listener in AppState will handle the rest
            print("UserManager: Login successful")
        }
    }
    
    func logout() {
        print("UserManager: Attempting to sign out")
        do {
            try Auth.auth().signOut()
            print("UserManager: Successfully signed out")
            
            // Auth state listener in AppState will handle state updates
        } catch {
            print("UserManager: Error signing out: \(error.localizedDescription)")
        }
    }
    
    func updateUserProfile(name: String, email: String, dateOfBirth: Date, role: UserRole) -> Bool {
        guard var user = currentUser, let firebaseUser = Auth.auth().currentUser else { return false }
        
        // Update profile in Firebase Auth
        let changeRequest = firebaseUser.createProfileChangeRequest()
        changeRequest.displayName = name
        
        var success = true
        
        changeRequest.commitChanges { error in
            if let error = error {
                print("Error updating display name: \(error.localizedDescription)")
                success = false
            }
        }
        
        // Update email if changed
        if email != user.email {
            firebaseUser.updateEmail(to: email) { error in
                if let error = error {
                    print("Error updating email: \(error.localizedDescription)")
                    success = false
                }
            }
        }
        
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
        return success
    }
    
    func updatePassword(currentPassword: String, newPassword: String) -> Bool {
        guard let firebaseUser = Auth.auth().currentUser, let email = firebaseUser.email else { 
            return false 
        }
        
        // Re-authenticate user before password change
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        
        var success = true
        
        firebaseUser.reauthenticate(with: credential) { [weak self] _, error in
            if let error = error {
                print("Error re-authenticating: \(error.localizedDescription)")
                success = false
                return
            }
            
            // Change password
            firebaseUser.updatePassword(to: newPassword) { error in
                if let error = error {
                    print("Error updating password: \(error.localizedDescription)")
                    success = false
                }
            }
        }
        
        return success
    }
    
    // Debug function to reset all user data
    func resetUserData() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: isLoggedInKey)
        if Auth.auth().currentUser != nil {
            try? Auth.auth().signOut()
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