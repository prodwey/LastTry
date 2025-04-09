import SwiftUI

// Helper wrapper to avoid potential conflicts with error handling
struct TaskListErrorDisplayWrapper<Content: View>: View {
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

struct TaskListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingDeleteAlert = false
    @State private var taskToDelete: Task? = nil
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showAddTaskSheet = false
    @State private var isLoading = false
    
    var body: some View {
        TaskListErrorDisplayWrapper(message: errorMessage, isPresented: $showError) {
            NavigationStack {
                ZStack {
                    Color.appBackground
                        .ignoresSafeArea()
                    
                    if appState.taskManager.tasks.isEmpty && !isLoading {
                        EmptyStateView(
                            icon: "checklist",
                            title: "No Tasks",
                            message: "You don't have any tasks yet. Add one to get started."
                        )
                    } else {
                        List {
                            ForEach(appState.taskManager.sortedByPriority()) { task in
                                NavigationLink(destination: EditTaskView(task: task)) {
                                    TaskRowView(task: task)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                taskToDelete = task
                                                showingDeleteAlert = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.appBackground)
                    }
                }
                .navigationTitle("Tasks")
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button {
                            loadTasks()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        
                        Button {
                            showAddTaskSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .alert("Delete Task", isPresented: $showingDeleteAlert) {
                    Button("Cancel", role: .cancel) {
                        taskToDelete = nil
                    }
                    
                    Button("Delete", role: .destructive) {
                        if let task = taskToDelete {
                            deleteTask(task: task)
                        }
                        taskToDelete = nil
                    }
                } message: {
                    if let task = taskToDelete {
                        Text("Are you sure you want to delete '\(task.title)'?")
                    } else {
                        Text("Are you sure you want to delete this task?")
                    }
                }
                .sheet(isPresented: $showAddTaskSheet) {
                    AddTaskView()
                }
                .withLoading(isLoading: isLoading, message: "Loading tasks...")
                .onChange(of: appState.taskManager.taskError) { _, newError in
                    if let taskError = newError, let processedError = DetailedErrorProcessor.convertTaskError(taskError) {
                        errorMessage = processedError.message
                        showError = true
                        
                        // Clear error after user has seen it
                        appState.taskManager.setTaskError(nil)
                    }
                }
                .onAppear {
                    loadTasks()
                }
            }
        }
    }
    
    private func loadTasks() {
        isLoading = true
        
        // Using a slight delay to simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            appState.taskManager.loadTasks()
            isLoading = false
        }
    }
    
    private func deleteTask(task: Task) {
        _ = appState.taskManager.removeTask(taskId: task.id)
        // Error handling is done through the onChange observer
    }
}

struct TaskListView_Previews: PreviewProvider {
    static var previews: some View {
        TaskListView()
            .environmentObject(AppState())
    }
} 