import SwiftUI

/// A demonstration view showing how to use SongLibrary without AppState
struct SongLibraryDemoView: View {
    @State private var songs: [Song] = []
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                VStack {
                    // Header
                    Text("Song Library Demo")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    Text("Using SongLibrary without AppState")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.bottom, 20)
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search songs", text: $searchText)
                            .foregroundColor(.white)
                            .onChange(of: searchText) { _, _ in
                                updateSongsList()
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                updateSongsList()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.appElevatedBackground)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    // Songs list
                    if songs.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            
                            Image(systemName: "music.note.list")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No songs found")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(searchText.isEmpty ? "Your library is empty" : "No songs match your search")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(songs) { song in
                                SongRow(song: song)
                                    .listRowBackground(Color.appElevatedBackground)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            deleteSong(song)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(PlainListStyle())
                    }
                    
                    // Demo buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            loadAllSongs()
                        }) {
                            Text("Load All")
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 15)
                                .background(Color.appPrimary)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            addDemoSong()
                        }) {
                            Text("Add Demo")
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 15)
                                .background(Color.appPrimary)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding()
            }
            .navigationTitle("Song Library")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showError) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                // Load all songs when the view appears
                loadAllSongs()
                
                // Set up notification observer for errors
                NotificationCenter.default.addObserver(forName: .songErrorOccurred, object: nil, queue: .main) { notification in
                    if let error = notification.object as? SongError {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadAllSongs() {
        // Load all songs using SongLibrary
        SongLibrary.loadAllSongs()
        updateSongsList()
    }
    
    private func updateSongsList() {
        if searchText.isEmpty {
            // Get all songs from SongLibrary
            songs = SongLibrary.songs
        } else {
            // Search songs using SongLibrary
            songs = SongLibrary.search(searchText)
        }
    }
    
    private func deleteSong(_ song: Song) {
        // Delete song using SongLibrary
        if SongLibrary.deleteSong(id: song.id) {
            updateSongsList()
        } else {
            errorMessage = "Failed to delete song"
            showError = true
        }
    }
    
    private func addDemoSong() {
        // Create a demo song
        let demoSong = Song(
            id: UUID().uuidString,
            name: "Demo Song \(Int.random(in: 1...100))",
            fileURL: nil,
            format: .mp3,
            artists: [Artist(id: UUID().uuidString, name: "Demo Artist")],
            lyrics: "This is a demo song created using SongLibrary",
            dateCreated: Date(),
            fileSize: 1024 * 1024,
            duration: 180,
            sessionId: "demo-session"
        )
        
        // Add song to library
        if let firstSession = SessionLibrary.sessions.first {
            SongManager.shared.songs.append(demoSong)
            SongLibrary.addSongToSession(sessionId: firstSession.id, song: demoSong)
            updateSongsList()
        } else {
            errorMessage = "No sessions available to add song to"
            showError = true
        }
    }
}

// MARK: - Helper Components

struct SongRow: View {
    let song: Song
    
    var body: some View {
        HStack(spacing: 15) {
            // Album art placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "music.note")
                    .foregroundColor(.white)
            }
            
            // Song details
            VStack(alignment: .leading, spacing: 4) {
                Text(song.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(song.artists.map { $0.name }.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Duration
            if let duration = song.duration {
                Text(formatDuration(duration))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 5)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// Notification sent when a song error occurs
    static let songErrorOccurred = Notification.Name("songErrorOccurred")
}

#Preview {
    SongLibraryDemoView()
} 