import SwiftUI

/// A demonstration view showing how to use SessionLibrary without AppState
struct SessionLibraryDemoView: View {
    @State private var sessions: [Session] = []
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPastSessions = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                VStack {
                    // Header
                    Text("Session Library Demo")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    Text("Using SessionLibrary without AppState")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.bottom, 20)
                    
                    // Filter toggle
                    Picker("Session Filter", selection: $showPastSessions) {
                        Text("Upcoming").tag(false)
                        Text("Past").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: showPastSessions) { _, _ in
                        updateSessionsList()
                    }
                    
                    // Sessions list
                    if sessions.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            
                            Image(systemName: "calendar")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No sessions found")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(showPastSessions ? "No past sessions" : "No upcoming sessions")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(sessions) { session in
                                SessionRow(session: session)
                                    .listRowBackground(Color.appElevatedBackground)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(PlainListStyle())
                    }
                    
                    // Demo buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            loadAllSessions()
                        }) {
                            Text("Load All")
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 15)
                                .background(Color.appPrimary)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            bookDemoSession()
                        }) {
                            Text("Book Demo")
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
            .navigationTitle("Session Library")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showError) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                // Load all sessions when the view appears
                loadAllSessions()
                
                // Set up notification observer for errors
                NotificationCenter.default.addObserver(forName: .sessionErrorOccurred, object: nil, queue: .main) { notification in
                    if let error = notification.object as? SessionError {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadAllSessions() {
        // Load all sessions using SessionLibrary
        SessionLibrary.loadAllSessions()
        updateSessionsList()
    }
    
    private func updateSessionsList() {
        if showPastSessions {
            // Get past sessions from SessionLibrary
            sessions = SessionLibrary.pastSessions
        } else {
            // Get upcoming sessions from SessionLibrary
            sessions = SessionLibrary.upcomingSessions
        }
    }
    
    private func bookDemoSession() {
        // Create a demo session for 3 days from now
        let futureDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        
        // Book session using SessionLibrary
        let success = SessionLibrary.bookSession(
            studio: .studioA,
            mainProducer: "Demo Producer",
            singers: ["Demo Singer 1", "Demo Singer 2"],
            additionalProducers: ["Assistant Producer"],
            date: futureDate,
            duration: 180 // 3 hours
        )
        
        if success {
            updateSessionsList()
        } else {
            errorMessage = "Failed to book session"
            showError = true
        }
    }
}

// MARK: - Helper Components

struct SessionRow: View {
    let session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Session title and studio
            HStack {
                Text(session.studio.rawValue)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Date badge
                Text(formatDate(session.date))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(session.isPastSession ? Color.gray.opacity(0.5) : Color.appPrimary)
                    .cornerRadius(4)
            }
            
            // Session details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Producer: \(session.mainProducer)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    if !session.singers.isEmpty {
                        Text("Singers: \(session.singers.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Duration
                Text(formatDuration(session.duration))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Song count if available
            if let songs = session.songs, !songs.isEmpty {
                HStack {
                    Image(systemName: "music.note")
                        .foregroundColor(.appPrimary)
                        .font(.caption)
                    
                    Text("\(songs.count) song\(songs.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.appPrimary)
                }
            }
        }
        .padding(.vertical, 5)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ minutes: TimeInterval) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins) min"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// Notification sent when a session error occurs
    static let sessionErrorOccurred = Notification.Name("sessionErrorOccurred")
}

#Preview {
    SessionLibraryDemoView()
} 