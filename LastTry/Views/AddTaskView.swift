import SwiftUI

// Helper wrapper to avoid potential conflicts with error handling
struct TaskErrorDisplayWrapper<Content: View>: View {
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

struct AddTaskView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var priority = TaskPriority.medium
    @State private var dueDate = Date().addingTimeInterval(24 * 60 * 60) // Tomorrow
    @State private var showDueDatePicker = false
    @State private var isCreatingTask = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Explicit initializer to avoid ambiguity
    init() {
        // Default initialization
    }
    
    var body: some View {
        TaskErrorDisplayWrapper(message: errorMessage, isPresented: $showError) {
            NavigationStack {
                ZStack {
                    Color.appBackground
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // Task title
                            FormFieldWithError(
                                title: "Task Title",
                                placeholder: "Enter task title...",
                                text: $title,
                                errorMessage: title.isEmpty ? "Title is required" : nil
                            )
                            
                            // Task description
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.headline)
                                    .foregroundColor(.appTextPrimary)
                                
                                TextEditor(text: $description)
                                    .frame(minHeight: 120)
                                    .padding(8)
                                    .background(Color.appElevatedBackground)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.appDivider, lineWidth: 1)
                                    )
                            }
                            
                            // Priority selector
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Priority")
                                    .font(.headline)
                                    .foregroundColor(.appTextPrimary)
                                
                                HStack(spacing: 16) {
                                    ForEach(TaskPriority.allCases) { priorityOption in
                                        PriorityButton(
                                            priority: priorityOption, 
                                            isSelected: priority == priorityOption,
                                            action: { priority = priorityOption }
                                        )
                                    }
                                }
                            }
                            
                            // Due date selector
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Due Date")
                                    .font(.headline)
                                    .foregroundColor(.appTextPrimary)
                                
                                Button {
                                    withAnimation {
                                        showDueDatePicker.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.appPrimary)
                                        
                                        Text(dueDate.formatted(date: .abbreviated, time: .shortened))
                                            .foregroundColor(.appTextPrimary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.up.chevron.down")
                                            .foregroundColor(.appTextSecondary)
                                            .font(.caption)
                                    }
                                    .padding()
                                    .background(Color.appElevatedBackground)
                                    .cornerRadius(8)
                                }
                                
                                if showDueDatePicker {
                                    DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.graphical)
                                        .padding()
                                        .background(Color.appElevatedBackground)
                                        .cornerRadius(12)
                                        .transition(.opacity)
                                }
                            }
                            
                            // Create button
                            Button(action: createTask) {
                                Text("Create Task")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(title.isEmpty || isCreatingTask)
                            .padding(.top, 16)
                            .padding(.bottom, 24)
                        }
                        .padding()
                    }
                }
                .navigationTitle("New Task")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                .withLoading(isLoading: isCreatingTask, message: "Creating task...")
                .onChange(of: appState.taskManager.taskError) { _, newError in
                    if let taskError = newError, let processedError = DetailedErrorProcessor.convertTaskError(taskError) {
                        errorMessage = processedError.message
                        showError = true
                        isCreatingTask = false
                        
                        // Clear error after user has seen it
                        appState.taskManager.taskError = nil
                    }
                }
                .onDisappear {
                    // Clear any errors when leaving the view
                    appState.taskManager.taskError = nil
                }
            }
        }
    }
    
    private func createTask() {
        guard !title.isEmpty else {
            errorMessage = "Task title is required"
            showError = true
            return
        }
        
        isCreatingTask = true
        
        let success = appState.taskManager.addTask(
            title: title,
            description: description,
            priority: priority,
            dueDate: dueDate,
            assignedTo: appState.userManager.currentUser?.id,
            createdBy: appState.userManager.currentUser?.id ?? ""
        )
        
        if success {
            isCreatingTask = false
            dismiss()
        } else if appState.taskManager.taskError == nil {
            // If there's no specific error set but task creation failed
            isCreatingTask = false
            errorMessage = "Failed to create task. Please try again."
            showError = true
        }
        // Otherwise, the onChange handler will catch the specific error
    }
}

// MARK: - Priority Button Component
struct PriorityButton: View {
    let priority: TaskPriority
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                let iconName = isSelected ? "checkmark.circle.fill" : "circle"
                Image(systemName: iconName)
                    .foregroundColor(isSelected ? priorityColor : .appTextSecondary)
                
                Text(priority.displayName)
                    .foregroundColor(isSelected ? priorityColor : .appTextPrimary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(isSelected ? priorityColor.opacity(0.1) : Color.appElevatedBackground)
            .cornerRadius(16)
        }
    }
    
    private var priorityColor: Color {
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

#Preview {
    AddTaskView()
        .environmentObject(AppState())
} 