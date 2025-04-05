import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddTaskSheet = false
    @State private var showingAITaskPrompt = false
    @State private var aiTaskPrompt = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
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
                        
                        Button("Create") {
                            // In a real app, this would parse the AI prompt and create the task
                            // For demo we'll create a simple task with the prompt as the title
                            if !aiTaskPrompt.isEmpty {
                                appState.taskManager.addTask(
                                    title: aiTaskPrompt,
                                    description: "Task created via AI",
                                    priority: .medium,
                                    dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
                                    assignedTo: appState.userManager.currentUser?.id,
                                    createdBy: appState.userManager.currentUser?.id ?? ""
                                )
                                aiTaskPrompt = ""
                            }
                        }
                    }
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
                        Button(action: {
                            // Would navigate to a full task list
                        }) {
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
}

// MARK: - Section Header
struct SectionHeaderView: View {
    var title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.appTextPrimary)
            
            Spacer()
            
            Button(action: {}) {
                Text("See All")
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
            }
        }
        .padding(.horizontal)
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

// MARK: - Add Task View
struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var title = ""
    @State private var description = ""
    @State private var priority: TaskPriority = .medium
    @State private var dueDate = Date.now.addingTimeInterval(60*60*24*7) // One week ahead
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                taskFormContent
                    .navigationTitle("Add Task")
                    .navigationBarTitleDisplayMode(.inline)
                    .foregroundColor(.appTextPrimary)
                    .toolbarBackground(Color.appBackground, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            cancelButton
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            saveButton
                        }
                    }
            }
        }
    }
    
    private var taskFormContent: some View {
        VStack {
            Form {
                Section(header: Text("Task Details").foregroundColor(.appTextPrimary)) {
                    TextField("Title", text: $title)
                        .foregroundColor(.appTextPrimary)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .foregroundColor(.appTextPrimary)
                    
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases) { priority in
                            Text(priority.displayName)
                        }
                    }
                    .foregroundColor(.appTextPrimary)
                    
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
                        .foregroundColor(.appTextPrimary)
                }
            }
            .scrollContentBackground(.hidden)
        }
    }
    
    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
        }
        .foregroundColor(.appTextSecondary)
    }
    
    private var saveButton: some View {
        Button("Save") {
            saveTask()
            dismiss()
        }
        .bold()
        .foregroundColor(.appPrimary)
        .disabled(title.isEmpty)
    }
    
    private func saveTask() {
        guard !title.isEmpty else { return }
        
        appState.taskManager.addTask(
            title: title,
            description: description,
            priority: priority,
            dueDate: dueDate,
            assignedTo: appState.userManager.currentUser?.id,
            createdBy: appState.userManager.currentUser?.id ?? ""
        )
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