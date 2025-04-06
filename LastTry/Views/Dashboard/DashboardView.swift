import SwiftUI

// Helper wrapper to avoid "error" naming conflict
struct ErrorDisplayWrapper<Content: View>: View {
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

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddTaskSheet = false
    @State private var showingAITaskPrompt = false
    @State private var aiTaskPrompt = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isCreatingTask = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ErrorDisplayWrapper(message: errorMessage, isPresented: $showError) {
                    mainScrollView
                        .navigationTitle("Home")
                        .foregroundColor(.appTextPrimary)
                        .toolbarBackground(Color.appBackground, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                        .sheet(isPresented: $showingAddTaskSheet) {
                            AddTaskView()
                        }
                        .alert("AI Task Creation", isPresented: $showingAITaskPrompt) {
                            TextField("Describe your task...", text: $aiTaskPrompt)
                            
                            Button("Cancel", role: .cancel) {
                                aiTaskPrompt = ""
                            }
                            
                            Button("Create", action: createAITask)
                                .disabled(aiTaskPrompt.isEmpty || isCreatingTask)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                            checkForTaskErrors()
                        }
                        .onAppear {
                            checkForTaskErrors()
                        }
                }
            }
        }
    }
    
    private func checkForTaskErrors() {
        if let taskError = appState.taskManager.taskError {
            if let processedError = DetailedErrorProcessor.convertTaskError(taskError) {
                errorMessage = processedError.message
                showError = true
                isCreatingTask = false
                
                // Clear error after processing
                appState.taskManager.taskError = nil
            }
        }
    }
    
    // MARK: - Private Views
    
    private var mainScrollView: some View {
        ScrollView {
            VStack(spacing: 24) {
                quickActionsSection
                recentlyPlayedSection
                tasksSection
                upcomingSessionsSection
                
                // Past sessions with missing uploads
                if shouldShowPastSessionsSection {
                    pastSessionsWithoutUploadsSection
                }
                
                newsFeedSection
            }
            .padding(.bottom, 24)
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Quick Actions")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    QuickActionButton(
                        icon: "plus.circle.fill",
                        title: "New Session",
                        color: .appPrimary
                    ) {
                        // Navigate to new session creation
                    }
                    
                    QuickActionButton(
                        icon: "music.note.list",
                        title: "Upload Song",
                        color: Color(red: 0.24, green: 0.65, blue: 1.0)
                    ) {
                        // Navigate to song upload
                    }
                    
                    QuickActionButton(
                        icon: "checklist",
                        title: "New Task",
                        color: Color(red: 0.0, green: 0.78, blue: 0.32)
                    ) {
                        showingAddTaskSheet = true
                    }
                    
                    QuickActionButton(
                        icon: "wand.and.stars",
                        title: "AI Assistant",
                        color: Color(red: 0.67, green: 0.0, blue: 1.0)
                    ) {
                        showingAITaskPrompt = true
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top)
    }
    
    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Recently Played")
            
            if appState.songManager.songs.isEmpty {
                EmptyStateView(
                    icon: "music.note.list",
                    title: "No Recent Songs",
                    message: "Songs you listen to will appear here"
                )
                .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(appState.songManager.songs.prefix(5)) { song in
                            SongCardView(song: song) {
                                appState.playSong(song)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Tasks")
            
            if appState.taskManager.tasks.isEmpty {
                EmptyStateView(
                    icon: "checklist",
                    title: "No Tasks",
                    message: "Add tasks to keep track of your work"
                )
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 2) {
                    ForEach(appState.taskManager.sortedByPriority().prefix(3)) { task in
                        TaskRowView(task: task)
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(Color.appElevatedBackground)
                            .cornerRadius(8)
                    }
                    
                    if appState.taskManager.tasks.count > 3 {
                        NavigationLink(destination: TaskListView()) {
                            Text("View All Tasks")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appTextSecondary)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var upcomingSessionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Upcoming Sessions")
            
            let upcomingSessions = appState.sessionManager.upcomingSessions()
            
            if upcomingSessions.isEmpty {
                EmptyStateView(
                    icon: "calendar",
                    title: "No Upcoming Sessions",
                    message: "Book a session to get started"
                )
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 2) {
                    ForEach(upcomingSessions.prefix(3)) { session in
                        SessionRowView(session: session)
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(Color.appElevatedBackground)
                            .cornerRadius(8)
                    }
                    
                    if upcomingSessions.count > 3 {
                        Button(action: {
                            appState.tabSelection = 1
                        }) {
                            Text("View All Sessions")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appTextSecondary)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var shouldShowPastSessionsSection: Bool {
        let pastSessionsWithoutSongs = appState.sessionManager.pastSessions().filter { !$0.hasUploadedAudio }
        return !pastSessionsWithoutSongs.isEmpty
    }
    
    private var pastSessionsWithoutUploadsSection: some View {
        let pastSessionsWithoutSongs = appState.sessionManager.pastSessions().filter { !$0.hasUploadedAudio }
        
        return VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Missing Uploads")
            
            VStack(spacing: 2) {
                ForEach(pastSessionsWithoutSongs.prefix(2)) { session in
                    PastSessionReminderView(session: session)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(Color.appElevatedBackground)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var newsFeedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Music News")
            
            NewsFeedView()
                .padding(.horizontal)
        }
    }
    
    private func createAITask() {
        guard !aiTaskPrompt.isEmpty else {
            errorMessage = "Please enter a task description"
            showError = true
            return
        }
        
        isCreatingTask = true
        
        // Here we would typically make an API call to an AI service
        // For now, we'll simulate a delay and create a simple task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Create a task with the AI prompt as description
            let success = appState.taskManager.addTask(
                title: "AI Generated Task",
                description: aiTaskPrompt,
                priority: .medium,
                dueDate: Date().addingTimeInterval(24 * 60 * 60), // Tomorrow
                assignedTo: appState.userManager.currentUser?.id,
                createdBy: appState.userManager.currentUser?.id ?? ""
            )
            
            if success {
                isCreatingTask = false
                aiTaskPrompt = ""
            } else if appState.taskManager.taskError == nil {
                isCreatingTask = false
                errorMessage = "Failed to create AI task. Please try again."
                showError = true
            }
            // Error handling for specific errors is done through the onChange observer
        }
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    var icon: String
    var title: String
    var color: Color
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.appElevatedBackground)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .frame(width: 90)
        }
    }
}

// MARK: - Song Card View
struct SongCardView: View {
    var song: Song
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Album artwork
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.appElevatedBackground)
                        .frame(width: 140, height: 140)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.appTextSecondary)
                    
                    // Play button overlay on hover (in a real app, would show on hover)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.appPrimary.opacity(0.8))
                        .opacity(0)
                        .padding(50)
                }
                
                VStack(alignment: .leading, spacing: 4) {
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
                .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Task Row View
struct TaskRowView: View {
    @EnvironmentObject var appState: AppState
    var task: Task
    
    var body: some View {
        NavigationLink(destination: EditTaskView(task: task)) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: {
                    appState.taskManager.toggleTaskCompletion(taskId: task.id)
                }) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? .green : .appTextSecondary)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 16, weight: .medium))
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .appTextSecondary : .appTextPrimary)
                    
                    Text(task.description)
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(2)
                    
                    if let dueDate = task.dueDate {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.caption)
                            
                            Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                            
                            if task.isOverdue {
                                Text("Overdue")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .foregroundColor(.appTextSecondary)
                        .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                PriorityBadge(priority: task.priority)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Priority Badge
struct PriorityBadge: View {
    var priority: TaskPriority
    
    var body: some View {
        Text(priority.displayName)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor.opacity(0.2))
            .foregroundColor(priorityColor)
            .cornerRadius(12)
    }
    
    var priorityColor: Color {
        switch priority {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}

// MARK: - Session Row View
struct SessionRowView: View {
    var session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.studio.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.appPrimary)
                
                Spacer()
                
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
            }
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Producer:")
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                    
                    Text(session.mainProducer)
                        .font(.system(size: 14))
                        .foregroundColor(.appTextPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Artists:")
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                    
                    Text(session.singers.joined(separator: ", "))
                        .font(.system(size: 14))
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(1)
                }
            }
            
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.appTextSecondary)
                
                Text("\(Int(session.duration / 60)) hours")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
            }
        }
    }
}

// MARK: - Past Session Reminder
struct PastSessionReminderView: View {
    var session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.yellow)
                
                Text("Missing Uploads")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.appTextPrimary)
                
                Spacer()
                
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
            }
            
            Text("Studio: \(session.studio.rawValue)")
                .font(.system(size: 14))
                .foregroundColor(.appTextSecondary)
            
            HStack {
                Button(action: {
                    // Navigate to upload screen
                }) {
                    Text("Upload Now")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.appElevatedBackground.opacity(0.3))
                        .cornerRadius(16)
                }
                
                Spacer()
                
                Button(action: {
                    // Dismiss/ignore reminder
                }) {
                    Text("Dismiss")
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary)
                }
            }
        }
    }
}

// MARK: - News Feed
struct NewsFeedView: View {
    @State private var selectedTab = 0
    let tabs = ["For You", "Industry", "Artists"]
    
    var body: some View {
        VStack(spacing: 16) {
            // Tabs
            HStack {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button(action: {
                        selectedTab = index
                    }) {
                        Text(tabs[index])
                            .font(.system(size: 14, weight: selectedTab == index ? .bold : .regular))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(selectedTab == index ? Color.appElevatedBackground : Color.clear)
                            .foregroundColor(selectedTab == index ? .appTextPrimary : .appTextSecondary)
                            .cornerRadius(16)
                    }
                    
                    if index < tabs.count - 1 {
                        Spacer()
                    }
                }
            }
            
            // News content
            ForEach(0...2, id: \.self) { _ in 
                NewsItemView()
                    .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - News Item
struct NewsItemView: View {
    var body: some View {
        HStack(spacing: 12) {
            // News thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.appElevatedBackground)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "newspaper")
                        .foregroundColor(.appTextSecondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Music Industry Updates")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.appTextPrimary)
                
                Text("Stay updated with the latest trends, technology and opportunities in the music production industry.")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(2)
                
                Text("5 hours ago")
                    .font(.system(size: 12))
                    .foregroundColor(.appTextSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews
#Preview {
    DashboardView()
        .environmentObject({
            let state = AppState()
            state.loadDemoData()
            return state
        }())
        .preferredColorScheme(.dark)
}