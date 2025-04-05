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
            if appState.userManager.isLoggedIn {
                MainTabView()
                    .preferredColorScheme(.light)
            } else {
                WelcomeView()
                    .preferredColorScheme(.light)
            }
        }
        .preferredColorScheme(.light) // Enforce light mode at the root level
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
