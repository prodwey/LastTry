import SwiftUI
import AVFoundation

struct MySongsView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedSong: Song? = nil
    @State private var isShowingFullPlayer = false
    
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
        
        // Otherwise, start playing the song
        appState.playSong(song)
        
        // In a real app, we'd load and play the audio file here
        // For now, we'll just update the app state
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
                    Slider(
                        value: Binding(
                            get: { appState.currentPlaybackPosition },
                            set: { 
                                appState.currentPlaybackPosition = $0
                                // In a real app, this would seek the audio
                            }
                        ),
                        in: 0...(song.duration ?? 180)
                    )
                    .accentColor(.appPrimary)
                    
                    HStack {
                        Text(formatTime(appState.currentPlaybackPosition))
                            .font(.system(size: 12))
                            .foregroundColor(.appTextSecondary)
                        
                        Spacer()
                        
                        Text(formatTime(song.duration ?? 180))
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
                    
                    Button(action: {}) {
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
                    
                    Button(action: {}) {
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
                
                // Additional controls
                HStack(spacing: 40) {
                    Button(action: {}) {
                        Image(systemName: "heart")
                            .font(.system(size: 24))
                            .foregroundColor(.appTextSecondary)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 24))
                            .foregroundColor(.appTextSecondary)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 24))
                            .foregroundColor(.appTextSecondary)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 24))
                            .foregroundColor(.appTextSecondary)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .padding(.horizontal)
        }
    }
}

// Helper function to format time
func formatTime(_ time: TimeInterval) -> String {
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
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