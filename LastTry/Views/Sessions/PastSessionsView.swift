import SwiftUI
import PhotosUI
import AVFoundation

struct PastSessionsView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var selectedSession: Session? = nil
    @State private var showingUploadSheet = false
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    
    var filteredSessions: [Session] {
        let pastSessions = appState.sessionManager.pastSessions()
        
        // First apply text search
        let textFiltered = searchText.isEmpty ? pastSessions : pastSessions.filter { session in
            session.studio.rawValue.localizedCaseInsensitiveContains(searchText) ||
            session.mainProducer.localizedCaseInsensitiveContains(searchText) ||
            session.singers.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
        }
        
        // Then apply category filter
        switch selectedFilter {
        case "Missing Uploads":
            return textFiltered.filter { !$0.hasUploadedAudio }
        case "This Month":
            return textFiltered.filter {
                Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
            }
        case "Last Month":
            if let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date()) {
                return textFiltered.filter {
                    Calendar.current.isDate($0.date, equalTo: lastMonth, toGranularity: .month)
                }
            }
            return textFiltered
        default: // "All"
            return textFiltered
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.appTextSecondary)
                        .font(.system(size: 16))
                        .frame(width: 24)
                    
                    ZStack(alignment: .leading) {
                        if searchText.isEmpty {
                            Text("Search sessions")
                                .foregroundColor(.appTextSecondary)
                                .font(.system(size: 16))
                        }
                        
                        TextField("", text: $searchText)
                            .foregroundColor(.appTextPrimary)
                            .font(.system(size: 16))
                    }
                }
                .padding(12)
                .background(Color.appElevatedBackground)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                // Filter buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        FilterButton(title: "All", isActive: selectedFilter == "All") {
                            selectedFilter = "All"
                        }
                        
                        FilterButton(title: "Missing Uploads", isActive: selectedFilter == "Missing Uploads") {
                            selectedFilter = "Missing Uploads"
                        }
                        
                        FilterButton(title: "This Month", isActive: selectedFilter == "This Month") {
                            selectedFilter = "This Month"
                        }
                        
                        FilterButton(title: "Last Month", isActive: selectedFilter == "Last Month") {
                            selectedFilter = "Last Month"
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                
                if filteredSessions.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.clock",
                        title: "No Past Sessions",
                        message: "Your past recording sessions will appear here"
                    )
                    .padding(.top, 40)
                } else {
                    // List past sessions
                    LazyVStack(spacing: 16) {
                        ForEach(filteredSessions) { session in
                            PastSessionCard(session: session)
                                .onTapGesture {
                                    if !session.hasUploadedAudio {
                                        selectedSession = session
                                        showingUploadSheet = true
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Past Sessions")
        .background(Color.appBackground)
        .foregroundColor(.appTextPrimary)
        .sheet(isPresented: $showingUploadSheet, onDismiss: {
            selectedSession = nil
        }) {
            if let session = selectedSession {
                SongUploadView(session: session)
            }
        }
    }
}

struct FilterButton: View {
    var title: String
    var isActive: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isActive ? Color.appElevatedBackground : Color.clear)
                )
                .foregroundColor(isActive ? .appPrimary : .appTextSecondary)
        }
    }
}

struct PastSessionCard: View {
    var session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with studio name and date
            HStack {
                Text(session.studio.rawValue)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.appPrimary)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary)
                    
                    Text(formatDate(session.date))
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary)
                }
            }
            
            // People involved
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Producer")
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary)
                    
                    Text(session.mainProducer)
                        .font(.system(size: 16))
                        .foregroundColor(.appTextPrimary)
                        .padding(.top, 1)
                    
                    if !session.additionalProducers.isEmpty {
                        Text("Also: \(session.additionalProducers.joined(separator: ", "))")
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                            .lineLimit(1)
                            .padding(.top, 1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Artists")
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary)
                    
                    Text(session.singers.joined(separator: ", "))
                        .font(.system(size: 16))
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(2)
                        .padding(.top, 1)
                }
            }
            .padding(.top, 4)
            
            // Session info footer
            HStack(spacing: 16) {
                // Duration
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary)
                    
                    Text("\(Int(session.duration / 60)) hours")
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary)
                }
                
                Spacer()
                
                // Session status
                if session.hasUploadedAudio {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                        
                        Text("\(session.songs?.count ?? 0) songs")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.appPrimary)
                        
                        Text("Upload Songs")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.appPrimary)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color.appElevatedBackground)
        .cornerRadius(12)
    }
    
    // Format date as "1 Apr 2025 at 12:57"
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy 'at' HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    PastSessionsView()
        .environmentObject({
            let state = AppState()
            state.loadDemoData()
            return state
        }())
        .preferredColorScheme(.dark)
} 