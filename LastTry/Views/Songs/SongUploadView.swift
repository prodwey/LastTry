import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

// DocumentPicker for audio files
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    var completion: (Result<URL, Error>) -> Void = { _ in }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Define the audio file types we want to support
        let supportedTypes: [UTType] = [
            .audio,             // Generic audio
            .mp3,               // MP3 audio
            .wav,               // WAV audio
            .aiff,              // AIFF audio
            .m4a,               // M4A audio
            .mpeg4Audio,        // MPEG-4 audio
            .aac,               // AAC audio
            .flac               // FLAC audio
        ]
        
        // Create a document picker configured for audio files
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Get a security-scoped URL and start accessing it
            let secureURL = url.startAccessingSecurityScopedResource() ? url : nil
            
            // Update the binding
            parent.selectedURL = secureURL
            
            // Call the completion handler
            parent.completion(.success(url))
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.completion(.failure(NSError(domain: "DocumentPicker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Document picker was cancelled"])))
        }
    }
}

// Helper wrapper to avoid "error" naming conflict
struct SongErrorDisplayWrapper<Content: View>: View {
    let content: Content
    let message: String
    @Binding var isPresented: Bool
    
    init(message: String, isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.message = message
        self._isPresented = isPresented
        self.content = content()
    }
    
    var body: some View {
        content
            .withErrorDisplay(
                message: message,
                severity: DisplayErrorSeverity.errorSeverity,
                isPresented: $isPresented
            )
    }
}

struct SongUploadView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var session: Session
    
    @State private var songName = ""
    @State private var lyrics = ""
    @State private var artists: [Artist] = []
    @State private var selectedAudioURL: URL? = nil
    @State private var audioFormat: AudioFormat? = nil
    @State private var isUploadComplete = false
    @State private var showingNoAudioAlert = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    @State private var currentArtistName = ""
    @State private var currentArtistCPF = ""
    @State private var currentArtistEmail = ""
    @State private var addingNewArtist = false
    
    @State private var showAudioFilePicker = false
    
    // Explicit initializer to avoid ambiguity
    init(session: Session) {
        self.session = session
    }
    
    var body: some View {
        SongErrorDisplayWrapper(message: errorMessage, isPresented: $showError) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        sessionHeaderSection
                        audioPickerSection
                        songNameSection
                        artistsSection
                        lyricsSection
                        buttonsSection
                    }
                    .padding()
                }
                .background(Color.appBackground)
                .navigationTitle("Upload Song")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                .alert("Mark Session", isPresented: $showingNoAudioAlert) {
                    Button("Yes", role: .destructive) {
                        markNoAudio()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to mark this session as having no audio? This can't be undone.")
                }
                .alert("Upload Complete", isPresented: $isUploadComplete) {
                    Button("OK") {
                        dismiss()
                    }
                } message: {
                    Text("Your song has been uploaded successfully.")
                }
                .withLoading(isLoading: isLoading, message: "Uploading song...")
                .onChange(of: appState.songManager.songError) { _, newError in
                    if let songError = newError as? SongError, let processedError = DetailedErrorProcessor.convertSongError(songError) {
                        errorMessage = processedError.message
                        showError = true
                        isLoading = false
                        
                        // Clear error after user has seen it
                        appState.songManager.songError = nil
                    }
                }
                .onDisappear {
                    // Clear any errors when leaving the view
                    appState.songManager.songError = nil
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var sessionHeaderSection: some View {
        SessionInfoHeader(session: session)
            .padding(.bottom, 10)
    }
    
    private var audioPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upload Audio File")
                .font(.headline)
            
            Button {
                // Show document picker when button is tapped
                showAudioFilePicker = true
            } label: {
                HStack {
                    Image(systemName: "music.note")
                    Text(selectedAudioURL != nil ? "Change File" : "Select Audio File")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appPrimary)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .sheet(isPresented: $showAudioFilePicker) {
                DocumentPicker(selectedURL: $selectedAudioURL) { result in
                    showAudioFilePicker = false
                    
                    switch result {
                    case .success(let url):
                        handleSelectedAudioFile(url)
                    case .failure(let error):
                        print("Error selecting audio file: \(error.localizedDescription)")
                    }
                }
                .ignoresSafeArea()
            }
            
            if let audioFormat = audioFormat {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("File selected: \(audioFormat.rawValue) format")
                        .font(.caption)
                }
                .padding(.top, 4)
            }
            
            Divider()
                .padding(.vertical, 8)
        }
    }
    
    private var songNameSection: some View {
        FormFieldWithError(
            title: "Song Name",
            placeholder: "Enter song name",
            text: $songName,
            errorMessage: songName.isEmpty ? "Song name is required" : nil
        )
    }
    
    private var artistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Artists/Singers")
                .font(.headline)
            
            // List existing artists
            ForEach(artists.indices, id: \.self) { index in
                ArtistListItem(artist: artists[index], onDelete: {
                    artists.remove(at: index)
                })
            }
            
            // Add new artist button
            if !addingNewArtist {
                addArtistButton
            } else {
                newArtistForm
            }
        }
    }
    
    private var addArtistButton: some View {
        Button(action: {
            addingNewArtist = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Artist")
            }
        }
        .padding(.vertical, 8)
        .foregroundColor(.appPrimary)
    }
    
    private var lyricsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lyrics (Optional)")
                .font(.headline)
            
            TextEditor(text: $lyrics)
                .frame(minHeight: 120)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var buttonsSection: some View {
        HStack {
            Button("Upload Song") {
                uploadSong()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canUpload || isLoading)
            
            Button("I Don't Have Audio") {
                showingNoAudioAlert = true
            }
            .buttonStyle(OutlineButtonStyle())
            .disabled(isLoading)
        }
        .padding(.top, 20)
    }
    
    private var newArtistForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New Artist")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            // Name field
            artistNameField
            
            // Optional fields
            HStack {
                cpfField
                emailField
            }
            
            // Buttons
            artistFormButtons
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
    
    private var artistNameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Name")
                    .font(.caption)
                
                Text("*")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            TextField("Artist name", text: $currentArtistName)
                .padding()
                .background(Color.appBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var cpfField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CPF")
                .font(.caption)
            
            TextField("CPF number", text: $currentArtistCPF)
                .padding()
                .background(Color.appBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var emailField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Email")
                .font(.caption)
            
            TextField("Email address", text: $currentArtistEmail)
                .padding()
                .background(Color.appBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var artistFormButtons: some View {
        HStack {
            Button("Add") {
                addArtist()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(currentArtistName.isEmpty)
            
            Button("Cancel") {
                resetArtistForm()
            }
            .buttonStyle(OutlineButtonStyle())
        }
    }
    
    // MARK: - Helper Methods
    
    private var canUpload: Bool {
        !songName.isEmpty && !artists.isEmpty && selectedAudioURL != nil
    }
    
    private func addArtist() {
        guard !currentArtistName.isEmpty else { return }
        
        let newArtist = Artist(
            id: UUID().uuidString,
            name: currentArtistName,
            cpf: currentArtistCPF.isEmpty ? nil : currentArtistCPF,
            rg: nil,
            dateOfBirth: nil,
            email: currentArtistEmail.isEmpty ? nil : currentArtistEmail,
            phone: nil,
            publisher: nil,
            recordingLabel: nil
        )
        
        artists.append(newArtist)
        resetArtistForm()
    }
    
    private func resetArtistForm() {
        currentArtistName = ""
        currentArtistCPF = ""
        currentArtistEmail = ""
        addingNewArtist = false
    }
    
    private func uploadSong() {
        guard canUpload else { 
            if songName.isEmpty {
                errorMessage = "Song name is required"
                showError = true
                return
            } else if artists.isEmpty {
                errorMessage = "At least one artist is required"
                showError = true
                return
            } else if selectedAudioURL == nil {
                errorMessage = "Please select an audio file"
                showError = true
                return
            }
            return
        }
        
        isLoading = true
        
        guard let audioURL = selectedAudioURL else { return }
        guard let _ = audioFormat else { return }
        
        let success = appState.songManager.addSong(
            name: songName,
            fileURL: audioURL,
            artists: artists,
            lyrics: lyrics.isEmpty ? nil : lyrics,
            sessionId: session.id
        )
        
        if success {
            if let song = appState.songManager.songs.last {
                appState.sessionManager.addSongToSession(sessionId: session.id, song: song)
            }
            
            isLoading = false
            isUploadComplete = true
        } else if appState.songManager.songError == nil {
            // If there's no specific error set but upload failed
            isLoading = false
            errorMessage = "Failed to upload song. Please try again."
            showError = true
        }
        // Otherwise, the onChange handler will catch the specific error
    }
    
    private func markNoAudio() {
        let emptySong = Song(
            id: UUID().uuidString,
            name: "No Recording",
            fileURL: nil,
            format: .wav,
            artists: session.singers.map { Artist(id: UUID().uuidString, name: $0) },
            lyrics: nil,
            dateCreated: Date(),
            fileSize: nil,
            duration: nil,
            sessionId: session.id
        )
        
        appState.sessionManager.addSongToSession(sessionId: session.id, song: emptySong)
        
        dismiss()
    }
    
    private func handleSelectedAudioFile(_ url: URL) {
        // Handle the selected audio file
        selectedAudioURL = url
        if let fileExtension = url.pathExtension {
            audioFormat = AudioFormat.fromFileExtension(fileExtension)
        }
    }
}

struct ArtistListItem: View {
    var artist: Artist
    var onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.headline)
                
                if let cpf = artist.cpf {
                    Text("CPF: \(cpf)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let email = artist.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct SessionInfoHeader: View {
    var session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(session.studio.rawValue) Session")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(session.date.formatted(date: .long, time: .shortened))
                .font(.callout)
                .foregroundColor(.secondary)
            
            Divider()
                .padding(.vertical, 4)
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Producer:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(session.mainProducer)
                        .font(.body)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Artists:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(session.singers.joined(separator: ", "))
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    let session = Session(
        id: "1",
        studio: .studioA,
        mainProducer: "John Producer",
        additionalProducers: ["Assistant Producer"],
        singers: ["Singer 1", "Singer 2"],
        date: Date(),
        duration: 180,
        songs: nil
    )
    
    return SongUploadView(session: session)
        .environmentObject(AppState())
} 