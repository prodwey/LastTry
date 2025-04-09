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

class UserManager: ObservableObject, UserManagerProtocol {
    // MARK: - Singleton
    
    /// Shared instance for global access
    static let shared = UserManager()
    
    // MARK: - Published Properties
    
    @Published var currentUser: User?
    @Published var isLoggedIn: Bool = false
    @Published var authError: UserError? = nil
    
    // MARK: - Private Properties
    
    private let userDefaultsKey = "currentUser"
    private let isLoggedInKey = "isLoggedIn"
    
    // Service dependencies
    private let coreDataManager = CoreDataManager.shared
    private let userDataManager = UserDataManager()
    private let authService: AuthenticationServiceProtocol
    private let errorService: ErrorHandlingServiceProtocol
    
    // Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Private initializer for singleton pattern
    private init() {
        print("UserManager: Initializing shared instance")
        
        // Get dependencies through ServiceLocator
        self.authService = ServiceLocator.shared.resolve(AuthenticationServiceProtocol.self) ?? AuthenticationService.shared
        self.errorService = ServiceLocator.shared.resolve(ErrorHandlingServiceProtocol.self) ?? ErrorHandlingService.shared
        
        // Setup auth state observation
        setupAuthStateSubscription()
    }
    
    /// Dependency injection initializer for testing
    init(authService: AuthenticationServiceProtocol, errorService: ErrorHandlingServiceProtocol) {
        print("UserManager: Initializing with custom dependencies")
        self.authService = authService
        self.errorService = errorService
    }
    
    // MARK: - Private Methods
    
    private func setupAuthStateSubscription() {
        // Subscribe to authentication state changes
        authService.authStatePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] isAuthenticated in
                guard let self = self else { return }
                
                // Update our authentication state
                self.isLoggedIn = isAuthenticated
                
                // Handle logout - clear user if needed
                if !isAuthenticated && self.currentUser != nil {
                    self.currentUser = nil
                    self.saveUserData()
                    print("UserManager: Cleared user data due to authentication state change")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Load user data from Firebase user
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
    
    /// Save user data to UserDefaults for backward compatibility
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
    
    // MARK: - Authentication Methods
    
    /// Sign up user using the authentication service
    func signUp(name: String, email: String, password: String, dateOfBirth: Date, role: UserRole) {
        print("UserManager: Starting sign up process for \(email)")
        self.authError = nil
        
        // Use a separate async function to handle the sign-up logic
        startSignUpProcess(
            name: name,
            email: email,
            password: password,
            dateOfBirth: dateOfBirth,
            role: role
        )
    }
    
    // Helper method to perform sign-up asynchronously
    private func startSignUpProcess(
        name: String,
        email: String,
        password: String,
        dateOfBirth: Date,
        role: UserRole
    ) {
        // Using runAsync helper instead of ConcurrencyTask
        runAsync {
            let result = await self.authService.signUp(email: email, password: password, name: name)
            
            switch result {
            case .success(let firebaseUser):
                print("UserManager: User created successfully in Firebase, uid: \(firebaseUser.uid)")
                
                // Update the display name using our service
                let profileResult = await self.authService.updateUserDisplayName(name)
                
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
    
    /// Login using the authentication service
    func login(email: String, password: String) {
        print("UserManager: Starting login process for \(email)")
        self.authError = nil
        
        // Use a separate async function to handle the login logic
        startLoginProcess(email: email, password: password)
    }
    
    // Helper method to perform login asynchronously
    private func startLoginProcess(email: String, password: String) {
        // Using runAsync helper instead of ConcurrencyTask
        runAsync {
            let result = await self.authService.signIn(email: email, password: password)
            
            await runOnMainActor {
                if case .failure(let error) = result {
                    self.authError = .invalidUserData(error.localizedDescription)
                } else {
                    print("UserManager: Login successful")
                    // Auth state listener will handle the rest
                }
            }
        }
    }
    
    /// Logout using the authentication service
    func logout() {
        print("UserManager: Attempting to sign out")
        
        let result = authService.signOut()
        
        if case .failure(let error) = result {
            print("UserManager: Error signing out: \(error.localizedDescription)")
            self.authError = .invalidUserData(error.localizedDescription)
        } else {
            print("UserManager: Successfully signed out")
            // Auth state listener will handle state updates
        }
    }

    // MARK: - User Profile Management
    
    /// Update user profile information
    func updateProfile(name: String, email: String, dateOfBirth: Date, role: UserRole) -> Bool {
        guard let currentUser = currentUser else {
            authError = .userNotFound("No user is currently logged in")
            return false
        }
        
        // Create updated user
        let updatedUser = currentUser
        updatedUser.name = name
        updatedUser.email = email
        updatedUser.dateOfBirth = dateOfBirth
        updatedUser.role = role
        
        // Update user in CoreData
        saveUserToCoreData(updatedUser)
        
        // Update Firebase profile if email or name changed
        if name != currentUser.name || email != currentUser.email {
            updateFirebaseProfile(name: name, email: email)
        }
        
        return true
    }
    
    private func updateFirebaseProfile(name: String, email: String) {
        runAsync {
            // Update display name if changed
            if let currentUser = self.currentUser, name != currentUser.name {
                let result = await self.authService.updateUserDisplayName(name)
                if case .failure(let error) = result {
                    await runOnMainActor {
                        self.authError = .failedToUpdate("Failed to update display name: \(error.localizedDescription)")
                    }
                }
            }
            
            // Update email if changed
            if let currentUser = self.currentUser, email != currentUser.email {
                let result = await self.authService.updateUserEmail(email)
                if case .failure(let error) = result {
                    await runOnMainActor {
                        self.authError = .failedToUpdate("Failed to update email: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Protocol Conformance Methods
    
    /// Set the current user directly
    func setCurrentUser(_ user: User?) {
        self.currentUser = user
    }
    
    /// Set the login state directly
    func setLoggedIn(_ isLoggedIn: Bool) {
        self.isLoggedIn = isLoggedIn
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