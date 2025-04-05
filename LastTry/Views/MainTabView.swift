import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main tab view
            TabView(selection: $appState.tabSelection) {
                // Dashboard Tab (Home)
                DashboardView()
                    .tabItem {
                        Label {
                            Text("Home")
                                .font(.system(size: 10))
                        } icon: {
                            Image(systemName: "house")
                                .renderingMode(.template)
                        }
                    }
                    .tag(0)
                
                // Sessions Tab (Explore)
                SessionsContainerView()
                    .tabItem {
                        Label {
                            Text("Sessions")
                                .font(.system(size: 10))
                        } icon: {
                            Image(systemName: "calendar")
                                .renderingMode(.template)
                        }
                    }
                    .tag(1)
                
                // My Songs Tab (Library)
                MySongsView()
                    .tabItem {
                        Label {
                            Text("Songs")
                                .font(.system(size: 10))
                        } icon: {
                            Image(systemName: "music.note.list")
                                .renderingMode(.template)
                        }
                    }
                    .tag(2)
                
                // Configuration Tab (Account)
                ConfigurationView()
                    .tabItem {
                        Label {
                            Text("Account")
                                .font(.system(size: 10))
                        } icon: {
                            Image(systemName: "person.circle")
                                .renderingMode(.template)
                        }
                    }
                    .tag(3)
            }
            .tint(.appPrimary) // Using app's primary color for selected items
            // Add safe area inset to all tab views to reserve space for mini-player
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if appState.currentPlayingSong != nil {
                    Spacer().frame(height: 60) // Height of mini-player
                }
            }
            .onAppear {
                // Set the tab bar appearance
                customizeTabBar()
            }
            
            // Now Playing mini-player positioned above tab bar
            if appState.currentPlayingSong != nil {
                VStack(spacing: 0) {
                    Spacer()
                    minimalPlaybackControl
                    Spacer().frame(height: 49) // Height of tab bar
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .ignoresSafeArea(.keyboard)
    }
    
    private var minimalPlaybackControl: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.appDivider)
            
            HStack(spacing: 12) {
                // Album art
                if let song = appState.currentPlayingSong {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.appElevatedBackground)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.appTextSecondary)
                            )
                    }
                    
                    // Song info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appTextPrimary)
                            .lineLimit(1)
                        
                        if !song.artists.isEmpty {
                            Text(song.artists.map { $0.name }.joined(separator: ", "))
                                .font(.system(size: 12))
                                .foregroundColor(.appTextSecondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Play/pause button
                    Button(action: {
                        if appState.isPlaying {
                            appState.pausePlayback()
                        } else {
                            appState.resumePlayback()
                        }
                    }) {
                        Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.appTextPrimary)
                            .frame(width: 44, height: 44)
                    }
                    
                    // Close button
                    Button(action: {
                        appState.stopPlayback()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18))
                            .foregroundColor(.appTextSecondary)
                            .frame(width: 30, height: 30)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.appBackground)
            .cornerRadius(10, corners: [.topLeft, .topRight])
            .shadow(color: Color.black.opacity(0.2), radius: 4, y: -2)
        }
    }
    
    // Function to customize tab bar appearance
    private func customizeTabBar() {
        // Set tab bar appearance to match app design
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(Color.appBackground)
        
        // Set divider at top of tab bar
        tabBarAppearance.shadowColor = UIColor(Color.appDivider)
        tabBarAppearance.shadowImage = UIImage.createTabBarShadowImage(color: UIColor(Color.appDivider))
        
        // Direct color setup for the tab bar items
        UITabBar.appearance().tintColor = UIColor(Color.appPrimary)
        UITabBar.appearance().unselectedItemTintColor = UIColor(Color.appTextSecondary)
        
        // Apply the appearance
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Customize tab bar item font
        let fontAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10, weight: .regular)]
        UITabBarItem.appearance().setTitleTextAttributes(fontAttributes, for: .normal)
        
        let selectedFontAttributes = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            NSAttributedString.Key.foregroundColor: UIColor(Color.appPrimary)
        ]
        UITabBarItem.appearance().setTitleTextAttributes(selectedFontAttributes, for: .selected)
    }
}

// Extension to create a 1-pixel shadow image for tab bar
extension UIImage {
    static func createTabBarShadowImage(color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(color.cgColor)
        context?.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
}

#Preview {
    MainTabView()
        .environmentObject({
            let state = AppState()
            state.currentPlayingSong = Song(
                id: "1",
                name: "Havana",
                fileURL: nil,
                format: .mp3,
                artists: [Artist(id: "1", name: "Camila Cabello")],
                lyrics: nil,
                dateCreated: Date(),
                fileSize: nil,
                duration: 181,
                sessionId: "1"
            )
            return state
        }())
        .preferredColorScheme(.dark)
} 