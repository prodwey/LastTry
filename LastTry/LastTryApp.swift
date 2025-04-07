//
//  LastTryApp.swift
//  LastTry
//
//  Created by Stefan Wey on 04/04/25.
//

import SwiftUI
import CoreData
import Firebase
import AVFoundation

@main
struct LastTryApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        // Initialize Firebase first, so AuthenticationService can use it
        FirebaseApp.configure()
        
        // Set up audio session for background playback
        configureAudioSession()
        
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
    
    // Configure audio session for background playback
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .allowAirPlay, .allowBluetooth]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Enable background modes programmatically (Note: this is usually set in Info.plist)
            // This is just for notification purposes - the actual background modes need to be set in project settings
            print("Audio session configured for background playback")
            print("IMPORTANT: Be sure to enable 'Audio, AirPlay, and Picture in Picture' background mode in your app's Capabilities tab")
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
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
