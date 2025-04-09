import SwiftUI
import AVFoundation

struct MySongsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isShowingUploadSheet = false
    @State private var searchText = ""
    @State private var selectedSong: Song? = nil
    @State private var isPlaybackActive = false
    @State private var isShowingFullPlayer = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack {
                    if appState.songManager.songs.isEmpty {
                        emptySongsView
                    } else {
                        songListView
                    }
                }
            }
            .navigationTitle("My Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    addSongButton
                }
            }
            .sheet(isPresented: $isShowingUploadSheet) {
                if let selectedSession = getLatestSession() {
                    SongUploadView(session: selectedSession)
                } else {
                    Text("No sessions available for upload")
                        .padding()
                }
            }
            .sheet(isPresented: $isShowingFullPlayer) {
                if let song = appState.currentPlayingSong {
                    SongPlayerView(song: song)
                }
            }
            // Use the centralized error handling
            .withErrorHandling(appState.errorService)
            // Legacy error handling for backward compatibility
            .onChange(of: appState.songManager.songError) { _, newError in
                if let error = newError {
                    // Forward to the centralized error handling service
                    appState.errorService.reportError(error)
                    
                    // Reset the error in song manager after handling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        appState.songManager.songError = nil
                    }
                }
            }
            .onChange(of: appState.currentPlayingSong) { _, newSong in
                isPlaybackActive = newSong != nil
                
                // Check if we should show the full player automatically
                if newSong != nil && selectedSong != nil && newSong?.id == selectedSong?.id {
                    isShowingFullPlayer = true
                    selectedSong = nil
                }
            }
            .onAppear {
                // Refresh the songs list when view appears
                appState.songManager.loadSongs()
            }
        }
    }
    
    private var emptySongsView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Songs Yet")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Upload your first song from a recording session")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                isShowingUploadSheet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Upload Song")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appPrimary)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .padding()
    }
    
    private var songListView: some View {
        List {
            ForEach(filteredSongs) { song in
                SongListItem(song: song, isPlaying: appState.currentPlayingSong?.id == song.id && appState.isPlaying)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSong = song
                        
                        if appState.currentPlayingSong?.id == song.id {
                            // If the same song is already playing, just show the full player
                            isShowingFullPlayer = true
                        } else {
                            // Otherwise, start playing the song
                            appState.playSong(song)
                        }
                    }
            }
            .onDelete { indexSet in
                deleteSongs(at: indexSet)
            }
        }
        .listStyle(PlainListStyle())
        .overlay(
            // Search bar
            SearchBar(text: $searchText, placeholder: "Search songs")
                .padding(.horizontal)
                .padding(.top, 8),
            alignment: .top
        )
    }
    
    private var addSongButton: some View {
        Button {
            isShowingUploadSheet = true
        } label: {
            Image(systemName: "plus")
        }
    }
    
    // Helper to get filtered songs based on search text
    private var filteredSongs: [Song] {
        if searchText.isEmpty {
            return appState.songManager.songs
        } else {
            return appState.songManager.searchSongs(query: searchText)
        }
    }
    
    // Helper to get the latest session for uploading
    private func getLatestSession() -> Session? {
        return appState.sessionManager.sessions
            .filter { $0.date < Date() } // Only past sessions
            .sorted { $0.date > $1.date } // Most recent first
            .first
    }
    
    // Delete songs at the specified indices
    private func deleteSongs(at indexSet: IndexSet) {
        for index in indexSet {
            let songId = filteredSongs[index].id
            let success = appState.songManager.deleteSong(withID: songId)
            
            if !success {
                // Error will be caught via the onChange handler
                break
            }
        }
    }
}

// A simple list item for a song
struct SongListItem: View {
    let song: Song
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Album art / placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                if isPlaying {
                    Image(systemName: "play.fill")
                        .foregroundColor(.appPrimary)
                } else {
                    Image(systemName: "music.note")
                        .foregroundColor(.gray)
                }
            }
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.name)
                    .font(.headline)
                    .lineLimit(1)
                
                if !song.artists.isEmpty {
                    Text(song.artists.map { $0.name }.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text(song.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(song.formattedFileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status indicator
            if isPlaying {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.appPrimary)
            }
        }
        .padding(.vertical, 8)
    }
}

// A simple search bar component
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.primary)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    MySongsView()
        .environmentObject({
            let state = AppState()
            
            // Add some sample songs for preview
            let songs = [
                Song(
                    id: "1",
                    name: "Feeling Good",
                    fileURL: nil,
                    format: .mp3,
                    artists: [Artist(id: "1", name: "Ana Souza")],
                    lyrics: "Birds flying high, you know how I feel...",
                    dateCreated: Date().addingTimeInterval(-86400), // 1 day ago
                    fileSize: 4523091,
                    duration: 201.5,
                    sessionId: "session1"
                ),
                Song(
                    id: "2",
                    name: "Sunset Boulevard",
                    fileURL: nil,
                    format: .wav,
                    artists: [Artist(id: "2", name: "Rafael Lima")],
                    lyrics: "Walking down that old sunset boulevard...",
                    dateCreated: Date().addingTimeInterval(-172800), // 2 days ago
                    fileSize: 12945834,
                    duration: 184.3,
                    sessionId: "session1"
                ),
                Song(
                    id: "3",
                    name: "Midnight Rain",
                    fileURL: nil,
                    format: .mp3,
                    artists: [Artist(id: "3", name: "Mariana Costa")],
                    lyrics: "The rain falls softly on my window...",
                    dateCreated: Date().addingTimeInterval(-345600), // 4 days ago
                    fileSize: 3854102,
                    duration: 240.8,
                    sessionId: "session2"
                )
            ]
            
            state.songManager.songs = songs
            return state
        }())
} 