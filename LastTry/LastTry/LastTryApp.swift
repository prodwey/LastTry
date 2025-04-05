import SwiftUI
import CoreData
import Firebase

@main
struct LastTryApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Force light mode for the entire app by setting the UIKit appearance
        let userInterfaceStyle: UIUserInterfaceStyle = .light
        UIApplication.shared.setUserInterfaceStyle(userInterfaceStyle)
    }
    
    // ... existing code ...
} 