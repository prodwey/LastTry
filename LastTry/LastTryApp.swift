//
//  LastTryApp.swift
//  LastTry
//
//  Created by Stefan Wey on 04/04/25.
//

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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.light) // Force light mode in SwiftUI
                .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // Save CoreData context when app moves to background
                    CoreDataManager.shared.saveContext()
                }
        }
    }
}

// Extension to simplify setting the interface style for the whole app
extension UIApplication {
    func setUserInterfaceStyle(_ style: UIUserInterfaceStyle) {
        // This affects any window created after this call
        UIWindow.appearance().overrideUserInterfaceStyle = style
    }
}
