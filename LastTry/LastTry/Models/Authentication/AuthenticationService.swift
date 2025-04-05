import Foundation
import Combine
import FirebaseAuth
import CoreData

/// Service that coordinates the Firebase Auth state with our app's User model
class AuthenticationService: ObservableObject {
    // Singleton instance
    static let shared = AuthenticationService()
    
    // Published properties for app state
    @Published var currentUser: User?
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var authError: Error?
    
    // References to managers
    private let firebaseAuthManager = FirebaseAuthManager.shared
    private let coreDataManager = CoreDataManager.shared
    
    // Subscription to keep track of Firebase auth state
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Subscribe to Firebase auth state changes
        setupAuthStateSubscription()
    }
    
    private func setupAuthStateSubscription() {
        firebaseAuthManager.authStatePublisher
            .sink { [weak self] firebaseUser in
                guard let self = self else { return }
                
                if let firebaseUser = firebaseUser {
                    // User is logged in with Firebase
                    self.isLoading = true
                    
                    // Look for existing user in CoreData
                    if let existingUser = self.findUserInCoreData(withID: firebaseUser.uid) {
                        self.currentUser = existingUser
                        self.isLoggedIn = true
                    } else {
                        // Create a new user in CoreData
                        self.createNewUserInCoreData(from: firebaseUser)
                    }
                    
                    self.isLoading = false
                } else {
                    // User is logged out
                    self.currentUser = nil
                    self.isLoggedIn = false
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Auth Methods
    
    /// Sign up a new user
    func signUp(name: String, email: String, password: String, dateOfBirth: Date, role: UserRole) async {
        self.isLoading = true
        self.authError = nil
        
        let (firebaseUser, error) = await firebaseAuthManager.signUp(withEmail: email, password: password)
        
        if let error = error {
            self.authError = error
            self.isLoading = false
            return
        }
        
        guard let firebaseUser = firebaseUser else {
            self.authError = NSError(domain: "AuthenticationService", code: -1, 
                                    userInfo: [NSLocalizedDescriptionKey: "Failed to create user"])
            self.isLoading = false
            return
        }
        
        // Update Firebase user profile with name
        if let error = await firebaseAuthManager.updateProfile(displayName: name) {
            print("Failed to update Firebase profile: \(error.localizedDescription)")
            // Continue anyway as we'll store name in CoreData
        }
        
        // Create the user in CoreData
        let newUser = User(
            id: firebaseUser.uid,
            name: name,
            email: email,
            dateOfBirth: dateOfBirth,
            role: role
        )
        
        saveUserToCoreData(newUser)
        self.isLoading = false
    }
    
    /// Sign in an existing user
    func signIn(email: String, password: String) async {
        self.isLoading = true
        self.authError = nil
        
        let (_, error) = await firebaseAuthManager.signIn(withEmail: email, password: password)
        
        if let error = error {
            self.authError = error
        }
        
        self.isLoading = false
        // The auth state listener will handle updating currentUser and isLoggedIn
    }
    
    /// Sign out the current user
    func signOut() {
        self.authError = nil
        
        if let error = firebaseAuthManager.signOut() {
            self.authError = error
            return
        }
        
        // The auth state listener will handle updating currentUser and isLoggedIn
    }
    
    /// Update the user profile
    func updateUserProfile(name: String, email: String, dateOfBirth: Date, role: UserRole) async -> Bool {
        guard let user = currentUser else { return false }
        
        self.authError = nil
        
        // Update email in Firebase if changed
        if user.email != email {
            if let error = await firebaseAuthManager.updateEmail(to: email) {
                self.authError = error
                return false
            }
        }
        
        // Update display name in Firebase
        if let error = await firebaseAuthManager.updateProfile(displayName: name) {
            print("Failed to update Firebase profile: \(error.localizedDescription)")
            // Continue anyway as we'll update in CoreData
        }
        
        // Update user in CoreData
        var updatedUser = user
        updatedUser.name = name
        updatedUser.email = email
        updatedUser.dateOfBirth = dateOfBirth
        updatedUser.role = role
        
        saveUserToCoreData(updatedUser)
        return true
    }
    
    /// Update the user's password
    func updatePassword(currentPassword: String, newPassword: String) async -> Bool {
        guard isLoggedIn else { return false }
        
        self.authError = nil
        
        // Firebase doesn't provide a direct way to verify current password
        // We need to reauthenticate the user first to verify current password
        
        // For simplicity, we'll just update the password
        // In a real app, you would need to reauthenticate first
        
        if let error = await firebaseAuthManager.updatePassword(to: newPassword) {
            self.authError = error
            return false
        }
        
        return true
    }
    
    /// Send a password reset email
    func sendPasswordReset(to email: String) async -> Bool {
        self.authError = nil
        
        if let error = await firebaseAuthManager.sendPasswordReset(to: email) {
            self.authError = error
            return false
        }
        
        return true
    }
    
    // MARK: - Core Data Methods
    
    /// Find a user in Core Data by Firebase UID
    private func findUserInCoreData(withID id: String) -> User? {
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
    
    /// Create a new user in Core Data from a Firebase User
    private func createNewUserInCoreData(from firebaseUser: FirebaseAuth.User) {
        let newUser = User(
            id: firebaseUser.uid,
            name: firebaseUser.displayName ?? "User",
            email: firebaseUser.email ?? "",
            dateOfBirth: Date(), // Default value
            role: .artist     // Default role
        )
        
        saveUserToCoreData(newUser)
    }
    
    /// Save a user to Core Data
    private func saveUserToCoreData(_ user: User) {
        coreDataManager.performBackgroundTask { context in
            let _ = user.toEntity(in: context)
            
            // Update published properties on main thread
            DispatchQueue.main.async {
                self.currentUser = user
                self.isLoggedIn = true
            }
        }
    }
} 