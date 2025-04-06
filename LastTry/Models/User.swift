import Foundation
import CoreData
import Firebase
import FirebaseAuth
import Combine
import SwiftUI

// Custom error types for user management
enum UserError: Error, LocalizedError, Equatable {
    case userNotFound(String)
    case failedToSave(String)
    case failedToLoad(String)
    case failedToUpdate(String)
    case failedToDelete(String)
    case invalidUserData(String)
    case duplicateUser(String)
    case missingRequiredFields
    case unauthorized
    case coreDataError(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotFound(let message):
            return "User not found: \(message)"
        case .failedToSave(let message):
            return "Failed to save user: \(message)"
        case .failedToLoad(let message):
            return "Failed to load user: \(message)"
        case .failedToUpdate(let message):
            return "Failed to update user: \(message)"
        case .failedToDelete(let message):
            return "Failed to delete user: \(message)"
        case .invalidUserData(let message):
            return "Invalid user data: \(message)"
        case .duplicateUser(let message):
            return "User already exists: \(message)"
        case .missingRequiredFields:
            return "Missing required user fields"
        case .unauthorized:
            return "Unauthorized to perform this operation"
        case .coreDataError(let message):
            return "Database error: \(message)"
        }
    }
    
    // Implementation of Equatable for cases with associated values
    static func == (lhs: UserError, rhs: UserError) -> Bool {
        switch (lhs, rhs) {
        case (.userNotFound(let lhs), .userNotFound(let rhs)):
            return lhs == rhs
        case (.failedToSave(let lhs), .failedToSave(let rhs)):
            return lhs == rhs
        case (.failedToLoad(let lhs), .failedToLoad(let rhs)):
            return lhs == rhs
        case (.failedToUpdate(let lhs), .failedToUpdate(let rhs)):
            return lhs == rhs
        case (.failedToDelete(let lhs), .failedToDelete(let rhs)):
            return lhs == rhs
        case (.invalidUserData(let lhs), .invalidUserData(let rhs)):
            return lhs == rhs
        case (.duplicateUser(let lhs), .duplicateUser(let rhs)):
            return lhs == rhs
        case (.missingRequiredFields, .missingRequiredFields),
             (.unauthorized, .unauthorized):
            return true
        case (.coreDataError(let lhs), .coreDataError(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

enum UserRole: String, CaseIterable, Identifiable, Codable {
    case artist = "Artist"
    case producer = "Producer"
    case engineer = "Sound Engineer"
    case manager = "Studio Manager"
    
    var id: String { self.rawValue }
}

// Change from struct to class to allow for property mutations
class User: Identifiable, Codable {
    let id: String
    var name: String
    var email: String
    var dateOfBirth: Date
    var role: UserRole
    
    required init(id: String, name: String, email: String, dateOfBirth: Date, role: UserRole) {
        self.id = id
        self.name = name
        self.email = email
        self.dateOfBirth = dateOfBirth
        self.role = role
    }
    
    // Authentication-related fields would normally be handled separately
    // and not stored in plain text in a real app
}

// MARK: - CoreDataConvertible
extension User: CoreDataConvertible {
    typealias Entity = UserEntity
    
    func toEntity(in context: NSManagedObjectContext) -> UserEntity {
        UserEntity.createOrUpdate(from: self, in: context)
    }
    
    static func fromEntity(_ entity: UserEntity) -> Self {
        let user = entity.toModel()
        return self.init(
            id: user.id,
            name: user.name,
            email: user.email,
            dateOfBirth: user.dateOfBirth,
            role: user.role
        )
    }
}

// MARK: - User CoreData Manager

class UserDataManager: CoreDataManaging {
    typealias EntityType = UserEntity
    typealias ModelType = User
    
    var entityName: String { "UserEntity" }
    
    func createEntity(from model: User, in context: NSManagedObjectContext) -> UserEntity {
        // Try to find existing entity first
        let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", model.id)
        
        if let existingEntity = try? context.fetch(fetchRequest).first {
            // Update existing entity
            existingEntity.id = model.id
            existingEntity.name = model.name
            existingEntity.email = model.email
            existingEntity.dateOfBirth = model.dateOfBirth
            existingEntity.role = model.role.rawValue
            return existingEntity
        } else {
            // Create new entity
            let entity = UserEntity(context: context)
            entity.id = model.id
            entity.name = model.name
            entity.email = model.email
            entity.dateOfBirth = model.dateOfBirth
            entity.role = model.role.rawValue
            return entity
        }
    }
    
    func createModel(from entity: UserEntity) -> User {
        User(
            id: entity.id ?? UUID().uuidString,
            name: entity.name ?? "",
            email: entity.email ?? "",
            dateOfBirth: entity.dateOfBirth ?? Date(),
            role: UserRole(rawValue: entity.role ?? UserRole.artist.rawValue) ?? .artist
        )
    }
    
    // Convert [UserEntity] to [User]
    func createModels(from entities: [UserEntity]) -> [User] {
        entities.map { createModel(from: $0) }
    }
}

class UserManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoggedIn: Bool = false
    @Published var authError: UserError? = nil
    
    // Reference to app state for synchronization
    weak var appState: AppState?
    
    private let userDefaultsKey = "currentUser"
    private let isLoggedInKey = "isLoggedIn"
    
    // Reference to CoreData manager
    private let coreDataManager = CoreDataManager.shared
    // Reference to the user data manager
    private let userDataManager = UserDataManager()
    // Set of cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        print("UserManager: Initializing")
    }
    
    // Load user data from Firebase user
    func loadUserFromFirebase(_ firebaseUser: FirebaseAuth.User) {
        print("UserManager: Loading user data from Firebase user: \(firebaseUser.uid)")
        
        // Check if we have this user in CoreData already
        let context = coreDataManager.viewContext
        let result = userDataManager.fetchById(id: firebaseUser.uid, in: context)
        
        switch result {
        case .success(let entityOptional):
            if let entity = entityOptional {
                print("UserManager: Found existing user in CoreData")
                let user = userDataManager.createModel(from: entity)
                DispatchQueue.main.async {
                    self.currentUser = user
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
        case .failure(let error):
            print("UserManager: Error fetching user: \(error.localizedDescription)")
            self.authError = .coreDataError("Database error: \(error.localizedDescription)")
            
            // Create a basic user profile anyway
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
        
        // Save to CoreData using background task
        _ = userDataManager.performBackgroundTask { context in
            let result = self.userDataManager.saveOrUpdate(model: user, idValue: user.id, in: context)
            
            switch result {
            case .success(_):
                print("UserManager: CoreData context saved successfully")
                return .success(())
            case .failure(let error):
                print("UserManager: Error saving CoreData context: \(error.localizedDescription)")
                // Need to dispatch to main thread since we're setting a @Published property
                DispatchQueue.main.async {
                    self.authError = .coreDataError("Failed to save user: \(error.localizedDescription)")
                }
                return .failure(error)
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
            self.authError = .invalidUserData("Internal error: Missing app state reference")
            return
        }
        
        // Use a separate async function to handle the sign-up logic
        startSignUpProcess(
            appState: appState,
            name: name,
            email: email,
            password: password,
            dateOfBirth: dateOfBirth,
            role: role
        )
    }
    
    // Helper method to perform sign-up asynchronously
    private func startSignUpProcess(
        appState: AppState,
        name: String,
        email: String,
        password: String,
        dateOfBirth: Date,
        role: UserRole
    ) {
        // Using runAsync helper instead of ConcurrencyTask
        runAsync {
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
                
                // Update UI on main thread
                await runOnMainActor {
                    self.saveUserToCoreData(newUser)
                }
                
            case .failure(let error):
                print("UserManager: Error creating user: \(error.localizedDescription)")
                await runOnMainActor {
                    self.authError = .invalidUserData(error.localizedDescription)
                }
            }
        }
    }
    
    // Login using the authentication service
    func login(email: String, password: String) {
        print("UserManager: Starting login process for \(email)")
        self.authError = nil
        
        guard let appState = appState else {
            print("UserManager: No app state reference")
            self.authError = .invalidUserData("Internal error: Missing app state reference")
            return
        }
        
        // Use a separate async function to handle the login logic
        startLoginProcess(appState: appState, email: email, password: password)
    }
    
    // Helper method to perform login asynchronously
    private func startLoginProcess(appState: AppState, email: String, password: String) {
        // Using runAsync helper instead of ConcurrencyTask
        runAsync {
            let result = await appState.authService.signIn(email: email, password: password)
            
            await runOnMainActor {
                if case .failure(let error) = result {
                    self.authError = .invalidUserData(error.localizedDescription)
                } else {
                    print("UserManager: Login successful")
                    // Auth state listener in AppState will handle the rest
                }
            }
        }
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
    
    func updateUserProfile(name: String, dateOfBirth: Date, role: UserRole) -> Bool {
        guard let currentUser = currentUser else {
            self.authError = .userNotFound("No user is currently logged in")
            return false
        }
        
        // Update user model
        currentUser.name = name
        currentUser.dateOfBirth = dateOfBirth
        currentUser.role = role
        
        // Update in CoreData
        if !updateUserInCoreData(currentUser) {
            self.authError = .failedToUpdate("Failed to update user profile in database")
            return false
        }
        
        // Update in Firebase if we have app state reference
        if let appState = appState {
            startUpdateUserProfileProcess(appState: appState, name: name)
        } else {
            print("UserManager: No app state reference for Firebase profile update")
        }
        
        self.currentUser = currentUser
        return true
    }
    
    // Helper method to update user profile in Firebase asynchronously
    private func startUpdateUserProfileProcess(appState: AppState, name: String) {
        // Using runAsync helper instead of ConcurrencyTask
        runAsync {
            let result = await appState.authService.updateUserProfile(displayName: name)
            
            if case .failure(let error) = result {
                print("UserManager: Error updating Firebase profile: \(error.localizedDescription)")
                await runOnMainActor {
                    self.authError = .failedToUpdate("Error updating profile: \(error.localizedDescription)")
                }
            } else {
                print("UserManager: Firebase profile updated successfully")
            }
        }
    }
    
    // Update user email
    func updateEmail(to newEmail: String) -> Bool {
        guard let appState = appState else {
            self.authError = .invalidUserData("Internal error: Missing app state reference")
            return false
        }
        
        guard let currentUser = self.currentUser else {
            self.authError = .userNotFound("No user is currently logged in")
            return false
        }
        
        // Start email update process in the background
        startEmailUpdateProcess(appState: appState, newEmail: newEmail, user: currentUser)
        
        return true // Since we're starting an async process, return success for now
    }
    
    // Update user in CoreData - updated to use Result
    private func updateUserInCoreData(_ user: User) -> Bool {
        let context = coreDataManager.viewContext
        let result = userDataManager.saveOrUpdate(model: user, idValue: user.id, in: context)
        
        switch result {
        case .success(_):
            return true
        case .failure(let error):
            print("Error updating user in CoreData: \(error.localizedDescription)")
            self.authError = .coreDataError("Database error: \(error.localizedDescription)")
            return false
        }
    }
    
    // Helper method to perform email update asynchronously
    private func startEmailUpdateProcess(appState: AppState, newEmail: String, user: User) {
        // Using runAsync helper instead of ConcurrencyTask
        runAsync {
            let result = await appState.authService.updateEmail(to: newEmail)
            
            await runOnMainActor {
                if case .failure(let error) = result {
                    self.authError = .failedToUpdate("Failed to update email: \(error.localizedDescription)")
                } else {
                    print("UserManager: Email updated successfully")
                    // Update the local user model
                    user.email = newEmail
                    
                    // Save to CoreData
                    if !self.updateUserInCoreData(user) {
                        self.authError = .failedToUpdate("Failed to update email in local database")
                    }
                    
                    // Update the published property to trigger UI updates
                    self.currentUser = user
                }
            }
        }
    }
    
    // Update user password
    func updatePassword(currentPassword: String, newPassword: String) -> Bool {
        guard let appState = appState else {
            self.authError = .invalidUserData("Internal error: Missing app state reference")
            return false
        }
        
        // Start password update process in the background
        startPasswordUpdateProcess(
            appState: appState,
            currentPassword: currentPassword,
            newPassword: newPassword
        )
        
        return true // Since we're starting an async process, return success for now
    }
    
    // Helper method to perform password update asynchronously
    private func startPasswordUpdateProcess(
        appState: AppState,
        currentPassword: String,
        newPassword: String
    ) {
        // Using runAsync helper instead of ConcurrencyTask
        runAsync {
            let result = await appState.authService.updatePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            
            await runOnMainActor {
                if case .failure(let error) = result {
                    self.authError = .failedToUpdate("Failed to update password: \(error.localizedDescription)")
                } else {
                    print("UserManager: Password updated successfully")
                }
            }
        }
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
    
    // Fetch a user by ID from CoreData - updated to use Result
    func fetchUser(byID id: String) -> User? {
        let context = coreDataManager.viewContext
        let result = userDataManager.fetchById(id: id, in: context)
        
        switch result {
        case .success(let entityOptional):
            if let entity = entityOptional {
                return userDataManager.createModel(from: entity)
            }
            return nil
        case .failure(let error):
            print("Error fetching user from CoreData: \(error.localizedDescription)")
            self.authError = .coreDataError("Failed to fetch user: \(error.localizedDescription)")
            return nil
        }
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