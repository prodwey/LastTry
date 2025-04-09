import SwiftUI

extension DashboardView {
    
    /// Example view showing the different ways to use the error handling service after refactoring
    struct ErrorHandlingDemoView: View {
        @State private var errorMessage: String?
        @State private var showingAlert = false
        
        var body: some View {
            VStack(spacing: 20) {
                Text("Error Handling Service Demo")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("This demo shows how the ErrorHandlingService can be used to report and display errors.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Divider()
                
                Group {
                    Button(action: reportSimpleError) {
                        DemoButton(title: "Report Simple Error (Shared Instance)", systemImage: "exclamationmark.triangle", color: .red)
                    }
                    
                    Button(action: reportNetworkError) {
                        DemoButton(title: "Report Network Error (Static Method)", systemImage: "wifi.slash", color: .orange)
                    }
                    
                    Button(action: reportPermissionError) {
                        DemoButton(title: "Report Permission Error (Static Method)", systemImage: "lock.shield", color: .yellow)
                    }
                    
                    Button(action: reportFileError) {
                        DemoButton(title: "Report File Error (Shared Instance)", systemImage: "doc.badge.xmark", color: .blue)
                    }
                    
                    Button(action: reportCustomError) {
                        DemoButton(title: "Report Custom Error (Static Method)", systemImage: "hammer", color: .purple)
                    }
                }
                
                Spacer()
            }
            .padding()
            .onAppear {
                // Add notification observer when view appears
                NotificationCenter.default.addObserver(
                    forName: .errorOccurred,
                    object: nil,
                    queue: .main
                ) { notification in
                    if let error = notification.userInfo?["error"] as? String {
                        self.errorMessage = error
                        self.showingAlert = true
                    }
                }
            }
            .alert(isPresented: $showingAlert, content: {
                Alert(
                    title: Text("Error Occurred"),
                    message: Text(errorMessage ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            })
        }
        
        // Error reporting functions
        private func reportSimpleError() {
            // Using the shared instance directly
            ErrorHandlingService.shared.reportError(AppError.general(.internalError("This is a simple error message.")))
        }
        
        private func reportNetworkError() {
            // Using the static method on the concrete class
            ErrorHandlingService.report(error: "Failed to connect to server. Please check your internet connection and try again.")
        }
        
        private func reportPermissionError() {
            // Using the static method on the concrete class
            ErrorHandlingService.report(error: "Permission denied. Please enable microphone access in Settings to record audio.")
        }
        
        private func reportFileError() {
            // Using the shared instance
            ErrorHandlingService.shared.reportError(AppError.media(.fileNotFound(path: "file://songs/demo.mp3")))
        }
        
        private func reportCustomError() {
            struct CustomAppError: Error, CustomStringConvertible {
                let code: Int
                let description: String
            }
            
            let customError = CustomAppError(
                code: 1001,
                description: "Critical error in application subsystem (Code: 1001)"
            )
            
            // Using the static method
            ErrorHandlingService.report(error: customError)
        }
    }
    
    struct DemoButton: View {
        let title: String
        let systemImage: String
        let color: Color
        
        var body: some View {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(color)
                    .font(.system(size: 24))
                    .frame(width: 36, height: 36)
                
                Text(title)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.appElevatedBackground)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

// Custom Notification extension for error handling
extension Notification.Name {
    static let errorOccurred = Notification.Name("errorOccurredNotification")
} 