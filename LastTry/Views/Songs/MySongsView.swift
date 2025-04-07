import SwiftUI
import AVFoundation

struct MySongsView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedSong: Song? = nil
    @State private var isShowingFullPlayer = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var filteredSongs: [Song] {
        if searchText.isEmpty {
            return appState.songManager.songs
        } else {
            return appState.songManager.searchSongs(query: searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Song list
                    if appState.songManager.songs.isEmpty {
                        EmptyStateView(
                            icon: "music.note.list",
                            title: "No Songs",
                            message: "Your uploaded songs will appear here"
                        )
                        .padding(.top, 80)
                    } else {
                        // Categories/Filters
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                CategoryPill(title: "All", isSelected: true)
                                CategoryPill(title: "Recent")
                                CategoryPill(title: "Artists")
                                CategoryPill(title: "Albums")
                                CategoryPill(title: "Downloads")
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        
                        // Song list
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(filteredSongs) { song in
                                    SongRowView(
                                        song: song,
                                        isPlaying: song.id == appState.currentPlayingSong?.id && appState.isPlaying,
                                        onTap: {
                                            self.playSong(song)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search songs")
                .foregroundColor(.appTextPrimary)
                .navigationTitle("Songs")
                .toolbarBackground(Color.appBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .sheet(isPresented: $isShowingFullPlayer) {
                    if let song = appState.currentPlayingSong {
                        FullPlayerView(song: song)
                    }
                }
            }
        }
    }
    
    private func playSong(_ song: Song) {
        // If the song is already playing, show the full player
        if appState.currentPlayingSong?.id == song.id {
            isShowingFullPlayer = true
            return
        }
        
        // Otherwise, start playing the song using real audio service
        appState.playSong(song)
        
        // Check for errors
        if let error = appState.audioError {
            errorMessage = error.localizedDescription
            showError = true
            return
        }
        
        // If playback started successfully, show the full player
        isShowingFullPlayer = true
    }
}

struct CategoryPill: View {
    var title: String
    var isSelected: Bool = false
    
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: isSelected ? .bold : .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.appElevatedBackground : Color.clear)
            .foregroundColor(isSelected ? .appTextPrimary : .appTextSecondary)
            .cornerRadius(16)
    }
}

struct SongRowView: View {
    var song: Song
    var isPlaying: Bool
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appElevatedBackground)
                        .frame(width: 56, height: 56)
                    
                    if isPlaying {
                        Image(systemName: "music.note")
                            .foregroundColor(.appPrimary)
                    } else {
                        Image(systemName: "music.note")
                            .foregroundColor(.appTextSecondary)
                    }
                }
                
                // Song info
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(.system(size: 16, weight: isPlaying ? .semibold : .regular))
                        .foregroundColor(isPlaying ? .appPrimary : .appTextPrimary)
                        .lineLimit(1)
                    
                    if !song.artists.isEmpty {
                        Text(song.artists.map { $0.name }.joined(separator: ", "))
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Duration + Options menu
                HStack(spacing: 16) {
                    if let duration = song.duration {
                        Text(formatTime(duration))
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                    }
                    
                    Image(systemName: "ellipsis")
                        .foregroundColor(.appTextSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct FullPlayerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var song: Song
    @State private var isScrubbing = false
    @State private var scrubbingValue: Double = 0
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Background
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Navigation bar
                HStack {
                    Button(action: { 
                        dismiss() 
                        // Don't stop playback when dismissing, just keep the mini-player
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .foregroundColor(.appTextPrimary)
                    }
                    
                    Spacer()
                    
                    Text("NOW PLAYING")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                    
                    Spacer()
                    
                    // Close and stop playback button
                    Button(action: { 
                        appState.stopPlayback()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.appTextPrimary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                Spacer()
                
                // Album art
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appElevatedBackground)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 300)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(.appTextSecondary)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Spacer()
                
                // Song info
                VStack(spacing: 8) {
                    Text(song.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.appTextPrimary)
                    
                    Text(song.artists.map { $0.name }.joined(separator: ", "))
                        .font(.system(size: 18))
                        .foregroundColor(.appTextSecondary)
                }
                
                Spacer()
                
                // Playback progress
                VStack(spacing: 8) {
                    // Use scrubbing state to avoid constant updates while dragging
                    Slider(
                        value: Binding(
                            get: { 
                                isScrubbing ? scrubbingValue : appState.currentPlaybackPosition 
                            },
                            set: { newValue in
                                scrubbingValue = newValue
                                isScrubbing = true
                            }
                        ),
                        in: 0...(appState.audioService.duration > 0 ? appState.audioService.duration : (song.duration ?? 180))
                    )
                    .accentColor(.appPrimary)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { _ in
                                // When user finishes dragging, apply the seek
                                if isScrubbing {
                                    appState.seekToPosition(scrubbingValue)
                                    isScrubbing = false
                                }
                            }
                    )
                    
                    HStack {
                        Text(formatTime(appState.currentPlaybackPosition))
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary)
                        
                        Spacer()
                        
                        let duration = appState.audioService.duration > 0 ? 
                                       appState.audioService.duration : 
                                       (song.duration ?? 180)
                        Text(formatTime(duration))
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary)
                    }
                }
                .padding(.horizontal)
                
                // Playback controls
                HStack(spacing: 32) {
                    Button(action: {}) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 24))
                            .foregroundColor(.appTextSecondary)
                    }
                    
                    Button(action: {
                        // Seek 10 seconds backward
                        let newPosition = max(0, appState.currentPlaybackPosition - 10)
                        appState.seekToPosition(newPosition)
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.appTextPrimary)
                    }
                    
                    Button(action: {
                        if appState.isPlaying {
                            appState.pausePlayback()
                        } else {
                            appState.resumePlayback()
                        }
                    }) {
                        Image(systemName: appState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(.appTextPrimary)
                    }
                    
                    Button(action: {
                        // Seek 10 seconds forward
                        let maxDuration = appState.audioService.duration > 0 ? 
                                        appState.audioService.duration : 
                                        (song.duration ?? 180)
                        let newPosition = min(maxDuration, appState.currentPlaybackPosition + 10)
                        appState.seekToPosition(newPosition)
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.appTextPrimary)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "repeat")
                            .font(.system(size: 24))
                            .foregroundColor(.appTextSecondary)
                    }
                }
                
                Spacer()
            }
            .padding(.bottom, 24)
        }
        .onAppear {
            // Initialize scrubbing value with current position when view appears
            scrubbingValue = appState.currentPlaybackPosition
            
            // Check for errors from audio playback
            if let error = appState.audioError {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        // Instead of using onChange, use a timer to check for errors
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            // This periodically checks for errors instead of using onChange
            if let error = appState.audioError {
                // Only show if we have a new error message
                if errorMessage != error.localizedDescription {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Playback Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// Helper method to format time
func formatTime(_ timeInSeconds: TimeInterval) -> String {
    let minutes = Int(timeInSeconds) / 60
    let seconds = Int(timeInSeconds) % 60
    return String(format: "%d:%02d", minutes, seconds)
}

#Preview {
    MySongsView()
        .environmentObject({
            let state = AppState()
            state.loadDemoData()
            return state
        }())
        .preferredColorScheme(.dark)
} 