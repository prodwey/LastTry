//
//  ContentView.swift
//  LastTry
//
//  Created by Stefan Wey on 04/04/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
                    .preferredColorScheme(.light)
                    .onAppear {
                        print("ContentView: MainTabView appeared, user is authenticated")
                    }
            } else {
                WelcomeView()
                    .preferredColorScheme(.light)
                    .onAppear {
                        print("ContentView: WelcomeView appeared, user is NOT authenticated")
                    }
            }
        }
        .preferredColorScheme(.light) // Enforce light mode at the root level
        .onReceive(appState.$isAuthenticated) { newValue in
            print("ContentView: Received isAuthenticated change to \(newValue)")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
