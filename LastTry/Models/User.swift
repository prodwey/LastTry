import Foundation

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

class UserManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoggedIn: Bool = false
    
    private let userDefaultsKey = "currentUser"
    private let isLoggedInKey = "isLoggedIn"
    
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
    
    private func saveUserData() {
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
            self.currentUser = User(
                id: UUID().uuidString,
                name: "Demo User",
                email: email,
                dateOfBirth: Date(),
                role: .artist
            )
            self.isLoggedIn = true
            saveUserData()
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
} 