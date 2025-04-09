import SwiftUI
import AVFoundation

extension SongPlayerView {
    
    /// A demonstration view showing how to use the AudioManager without AppState
    struct AudioManagerDemoView: View {
        // State for UI
        @State private var isPlaying = false
        @State private var currentTime: TimeInterval = 0
        @State private var duration: TimeInterval = 0
        @State private var currentSong: Song?
        @State private var showError = false
        @State private var errorMessage = ""
        
        // State for timer to update current time
        @State private var timer: Timer?
        
        // Observers for audio notifications
        @State private var observers: [NSObjectProtocol] = []
        
        // Demo songs for testing
        let demoSongs: [Song] = [
            // Only use if the files exist in your app - replace with your actual files
            Song(
                id: "demo-song-1",
                name: "Demo Song 1",
                fileURL: Bundle.main.url(forResource: "demo-song", withExtension: "mp3"),
                format: .mp3,
                artists: [Artist(id: "demo-artist", name: "Demo Artist")],
                lyrics: "Demo lyrics...",
                dateCreated: Date(),
                fileSize: 1024 * 1024,
                duration: 180,
                sessionId: "demo-session"
            )
        ]
        
        var body: some View {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header
                    Text("Audio Manager Demo")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(.top, 40)
                    
                    // Current song display
                    VStack(spacing: 8) {
                        Text(currentSong?.name ?? "No song playing")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if let artists = currentSong?.artists.map({ $0.name }).joined(separator: ", ") {
                            Text(artists)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 20)
                    
                    // Progress bar
                    ProgressView(value: currentTime, total: max(duration, 1))
                        .accentColor(.appPrimary)
                        .frame(height: 8)
                        .padding(.horizontal)
                    
                    // Time display
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text(formatTime(duration))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    // Playback controls
                    HStack(spacing: 40) {
                        // Skip backward button (placeholder)
                        Button(action: {
                            seekBackward()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        }
                        
                        // Play/Pause button
                        Button(action: {
                            togglePlayback()
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.appPrimary)
                        }
                        
                        // Skip forward button (placeholder)
                        Button(action: {
                            seekForward()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Demo song selection
                    VStack {
                        Text("Demo Songs")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top, 30)
                        
                        if demoSongs.isEmpty {
                            Text("No demo songs available")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(demoSongs) { song in
                                Button(action: {
                                    playSong(song)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(song.name)
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            
                                            Text(song.artists.map { $0.name }.joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(formatTime(song.duration ?? 0))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal)
                                    .background(currentSong?.id == song.id ? Color.appElevatedBackground : Color.clear)
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Status
                    Text(isPlaying ? "Playing" : "Paused")
                        .foregroundColor(isPlaying ? .green : .gray)
                        .padding(.bottom)
                }
                .padding()
            }
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Playback Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                // Set up timer for updating current time
                timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    updatePlaybackState()
                }
                
                // Set up notification observers
                setupNotificationObservers()
            }
            .onDisappear {
                // Clean up timer
                timer?.invalidate()
                timer = nil
                
                // Clean up notification observers
                for observer in observers {
                    NotificationCenter.default.removeObserver(observer)
                }
                observers.removeAll()
                
                // Stop playback when view disappears
                AudioManager.stopPlayback()
            }
        }
        
        // MARK: - Private Methods
        
        private func playSong(_ song: Song) {
            let success = AudioManager.playSong(song)
            if !success {
                errorMessage = "Failed to play song. Please check if the file exists."
                showError = true
            }
        }
        
        private func togglePlayback() {
            if isPlaying {
                AudioManager.pausePlayback()
            } else {
                if currentSong != nil {
                    AudioManager.resumePlayback()
                } else if let firstSong = demoSongs.first {
                    playSong(firstSong)
                }
            }
        }
        
        private func seekForward() {
            let newTime = min(currentTime + 10, duration)
            AudioManager.seek(to: newTime)
        }
        
        private func seekBackward() {
            let newTime = max(currentTime - 10, 0)
            AudioManager.seek(to: newTime)
        }
        
        private func updatePlaybackState() {
            isPlaying = AudioManager.isPlaying
            currentTime = AudioManager.currentTime
            duration = AudioManager.duration
            currentSong = AudioManager.currentSong
        }
        
        private func setupNotificationObservers() {
            // Observe playback end
            let endObserver = NotificationCenter.default.addObserver(
                forName: .audioPlaybackDidEnd,
                object: nil,
                queue: .main
            ) { _ in
                updatePlaybackState()
            }
            observers.append(endObserver)
            
            // Observe interruptions
            let interruptObserver = NotificationCenter.default.addObserver(
                forName: .audioPlaybackInterrupted,
                object: nil,
                queue: .main
            ) { _ in
                updatePlaybackState()
            }
            observers.append(interruptObserver)
            
            // Observe playback resume
            let resumeObserver = NotificationCenter.default.addObserver(
                forName: .audioPlaybackResumed,
                object: nil,
                queue: .main
            ) { _ in
                updatePlaybackState()
            }
            observers.append(resumeObserver)
            
            // Observe errors
            let errorObserver = NotificationCenter.default.addObserver(
                forName: .audioPlaybackError,
                object: nil,
                queue: .main
            ) { notification in
                updatePlaybackState()
                
                if let error = notification.object as? AudioError {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            observers.append(errorObserver)
        }
        
        private func formatTime(_ timeInSeconds: TimeInterval) -> String {
            let minutes = Int(timeInSeconds) / 60
            let seconds = Int(timeInSeconds) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    NavigationStack {
        SongPlayerView.AudioManagerDemoView()
    }
} 