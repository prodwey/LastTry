//
//  FirebaseAuthService.swift
//  LastTry
//
//  Created on 04/05/25.
//

import Foundation
import FirebaseAuth
import Combine

/// Firebase implementation of the AuthenticationService protocol
class FirebaseAuthService: AuthenticationService {
    // Singleton instance for easy access
    static let shared = FirebaseAuthService()
    
    // Track auth state changes
    private var authStateChanges: AnyCancellable?
    
    // Initialize and set up auth state monitoring
    init() {
        monitorAuthState()
    }
    
    // MARK: - AuthenticationService Protocol
    
    var isUserSignedIn: Bool {
        return Auth.auth().currentUser != nil
    }
    
    func signUp(name: String, email: String, password: String, dateOfBirth: Date, role: UserRole, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            if let error = error {
                let authError = self?.handleFirebaseError(error)
                completion(.failure(authError ?? error))
                return
            }
            
            guard let authResult = authResult else {
                completion(.failure(AuthError.unknownError(message: "No auth result returned")))
                return
            }
            
            // Set the user's display name
            let changeRequest = authResult.user.createProfileChangeRequest()
            changeRequest.displayName = name
            changeRequest.commitChanges { error in
                if let error = error {
                    let authError = self?.handleFirebaseError(error)
                    completion(.failure(authError ?? error))
                    return
                }
                
                // Create user from Firebase data
                let user = User(
                    id: authResult.user.uid,
                    name: name,
                    email: email,
                    dateOfBirth: dateOfBirth,
                    role: role
                )
                
                // Store additional user data that Firebase doesn't store
                // In a real app, you would save this to Firestore or another database
                self?.saveAdditionalUserData(user: user) { success in
                    if success {
                        completion(.success(user))
                    } else {
                        completion(.failure(AuthError.unknownError(message: "Failed to save additional user data")))
                    }
                }
            }
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            if let error = error {
                let authError = self?.handleFirebaseError(error)
                completion(.failure(authError ?? error))
                return
            }
            
            guard let authResult = authResult else {
                completion(.failure(AuthError.unknownError(message: "No auth result returned")))
                return
            }
            
            // Load the user's additional data
            self?.loadUserData(userId: authResult.user.uid) { result in
                switch result {
                case .success(let user):
                    completion(.success(user))
                case .failure(let error):
                    // If we can't load additional data, create a basic user
                    let basicUser = User(
                        id: authResult.user.uid,
                        name: authResult.user.displayName ?? "User",
                        email: authResult.user.email ?? "",
                        dateOfBirth: Date(), // Default value
                        role: .artist // Default value
                    )
                    completion(.success(basicUser))
                    print("Warning: Could not load additional user data: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    func updateUserProfile(name: String, email: String, dateOfBirth: Date, role: UserRole, completion: @escaping (Bool) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(false)
            return
        }
        
        // Update display name if changed
        if currentUser.displayName != name {
            let changeRequest = currentUser.createProfileChangeRequest()
            changeRequest.displayName = name
            changeRequest.commitChanges { [weak self] error in
                if let error = error {
                    print("Error updating display name: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                // Continue with email update if needed
                self?.updateEmailIfNeeded(currentUser: currentUser, newEmail: email) { success in
                    if success {
                        // Update additional data
                        let user = User(
                            id: currentUser.uid,
                            name: name,
                            email: email,
                            dateOfBirth: dateOfBirth,
                            role: role
                        )
                        self?.saveAdditionalUserData(user: user, completion: completion)
                    } else {
                        completion(false)
                    }
                }
            }
        } else {
            // Email needs to be updated but name doesn't
            updateEmailIfNeeded(currentUser: currentUser, newEmail: email) { [weak self] success in
                if success {
                    // Update additional data
                    let user = User(
                        id: currentUser.uid,
                        name: name,
                        email: email,
                        dateOfBirth: dateOfBirth,
                        role: role
                    )
                    self?.saveAdditionalUserData(user: user, completion: completion)
                } else {
                    completion(false)
                }
            }
        }
    }
    
    func resetPassword(forEmail email: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            completion(error)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func monitorAuthState() {
        authStateChanges = Auth.auth().authStateDidChangePublisher()
            .sink { auth in
                // This will be called whenever auth state changes (login/logout)
                // Here you would typically update your app state
                print("Firebase Auth state changed: \(auth != nil ? "Signed In" : "Signed Out")")
            }
    }
    
    private func handleFirebaseError(_ error: Error) -> AuthError {
        let nsError = error as NSError
        let errorCode = AuthErrorCode(_bridgedNSError: nsError).rawValue
        
        switch errorCode {
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .invalidEmail:
            return .invalidEmail
        case .wrongPassword:
            return .wrongPassword
        case .userNotFound:
            return .userNotFound
        case .networkRequestFailed:
            return .networkError
        case .userDisabled:
            return .accountDisabled
        default:
            return .unknownError(message: error.localizedDescription)
        }
    }
    
    // In a real app, you would save this to Firestore or another database
    // For now, we'll use UserDefaults as a placeholder
    private func saveAdditionalUserData(user: User, completion: @escaping (Bool) -> Void) {
        do {
            let encoder = JSONEncoder()
            let userData = try encoder.encode(user)
            UserDefaults.standard.set(userData, forKey: "user_\(user.id)")
            completion(true)
        } catch {
            print("Error saving user data: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    // In a real app, you would load this from Firestore or another database
    // For now, we'll use UserDefaults as a placeholder
    private func loadUserData(userId: String, completion: @escaping (Result<User, Error>) -> Void) {
        if let userData = UserDefaults.standard.data(forKey: "user_\(userId)") {
            do {
                let decoder = JSONDecoder()
                let user = try decoder.decode(User.self, from: userData)
                completion(.success(user))
            } catch {
                completion(.failure(error))
            }
        } else {
            completion(.failure(AuthError.userNotFound))
        }
    }
    
    private func updateEmailIfNeeded(currentUser: FirebaseAuth.User, newEmail: String, completion: @escaping (Bool) -> Void) {
        if currentUser.email != newEmail {
            // Using the new recommended method instead of the deprecated updateEmail
            currentUser.sendEmailVerification(beforeUpdatingEmail: newEmail) { error in
                if let error = error {
                    print("Error updating email: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                completion(true)
            }
        } else {
            // No need to update email
            completion(true)
        }
    }
}

// MARK: - FirebaseAuth Extensions

extension Auth {
    func authStateDidChangePublisher() -> AnyPublisher<User?, Never> {
        let subject = PassthroughSubject<User?, Never>()
        
        let handle = addStateDidChangeListener { _, user in
            subject.send(user)
        }
        
        return subject
            .handleEvents(receiveCancel: { [weak self] in
                self?.removeStateDidChangeListener(handle)
            })
            .eraseToAnyPublisher()
    }
} 