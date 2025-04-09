import SwiftUI
import AVFoundation

struct SongPlayerView: View {
    @EnvironmentObject var appState: AppState
    let song: Song
    
    // Get services from ServiceLocator
    private let audioService = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
    
    @State private var currentTime: TimeInterval = 0
    @State private var sliderValue: Double = 0
    @State private var isEditing = false
    @State private var timer: Timer? = nil
    @State private var showAudioManagerDemo = false
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Album art
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.appElevatedBackground)
                        .frame(width: 280, height: 280)
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.top, 40)
                
                // Song info
                VStack(spacing: 8) {
                    Text(song.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.center)
                    
                    if !song.artists.isEmpty {
                        Text(song.artists.map { $0.name }.joined(separator: ", "))
                            .font(.headline)
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // Playback progress
                VStack(spacing: 8) {
                    Slider(
                        value: $sliderValue,
                        in: 0...max(1, song.duration ?? 0),
                        onEditingChanged: { editing in
                            isEditing = editing
                            if !editing {
                                appState.seekToPosition(sliderValue)
                            }
                        }
                    )
                    .accentColor(.appPrimary)
                    
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption)
                            .foregroundColor(.appTextSecondary)
                        
                        Spacer()
                        
                        Text(formatTime(song.duration ?? 0))
                            .font(.caption)
                            .foregroundColor(.appTextSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // Playback controls
                HStack(spacing: 40) {
                    Button(action: {
                        let newPosition = max(0, currentTime - 10)
                        appState.seekToPosition(newPosition)
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 28))
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
                            .font(.system(size: 64))
                            .foregroundColor(.appPrimary)
                    }
                    
                    Button(action: {
                        let newPosition = min(song.duration ?? 0, currentTime + 10)
                        appState.seekToPosition(newPosition)
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.appTextPrimary)
                    }
                }
                .padding(.top, 16)
                
                Spacer()
                
                // Demo Button
                Button("Try New Audio Manager Demo") {
                    showAudioManagerDemo = true
                }
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.bottom, 20)
            }
            .padding()
        }
        .sheet(isPresented: $showAudioManagerDemo) {
            AudioManagerDemoView()
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [self] _ in
            if !isEditing && appState.isPlaying {
                if let audioService = self.audioService {
                    self.currentTime = audioService.currentTime
                    self.sliderValue = self.currentTime
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    SongPlayerView(song: Song(
        id: "1", 
        name: "Preview Song", 
        fileURL: nil,
        format: .mp3,
        artists: [Artist(id: "1", name: "Sample Artist")],
        lyrics: "Sample lyrics for preview...",
        dateCreated: Date(),
        fileSize: 5000000,
        duration: 180,
        sessionId: "preview-session"
    ))
    .environmentObject(AppState())
} 