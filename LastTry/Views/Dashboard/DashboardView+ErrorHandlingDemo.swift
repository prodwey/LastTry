import SwiftUI

extension DashboardView {
    
    /// Example view showing the different ways to use the error handling service after refactoring
    struct ErrorHandlingDemoView: View {
        // The entire demo can be built without requiring AppState
        
        var body: some View {
            VStack(spacing: 20) {
                Text("Error Handling Demo")
                    .font(.headline)
                
                // Method 1: Using the service via withErrorHandling() extension
                Button("Report Error (View Extension)") {
                    reportErrorUsingViewExtension()
                }
                .buttonStyle(.borderedProminent)
                
                // Method 2: Using the static functions on the protocol
                Button("Report Error (Static Functions)") {
                    reportErrorUsingStaticFunctions()
                }
                .buttonStyle(.borderedProminent)
                
                // Method 3: Using the shared instance directly
                Button("Report Error (Shared Instance)") {
                    reportErrorUsingSharedInstance()
                }
                .buttonStyle(.borderedProminent)
                
                // Method 4: Using the service through ServiceLocator
                Button("Report Error (Service Locator)") {
                    reportErrorUsingServiceLocator()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            // The view automatically has error handling with no AppState reference
            .withErrorHandling()
        }
        
        // MARK: - Demo Methods
        
        private func reportErrorUsingViewExtension() {
            // This approach is great for views that need to show errors
            // The error will be shown automatically via the withErrorHandling modifier
            let error = AppError.general(.internalError("Test error using View Extension"))
            ErrorReporter.report(error)
        }
        
        private func reportErrorUsingStaticFunctions() {
            // This approach is great for utility functions and shared code
            // The static functions make the code very clean
            ErrorReporter.report(
                AppError.data(.failedToLoad(entity: "Demo", reason: "Static function demo"))
            )
        }
        
        private func reportErrorUsingSharedInstance() {
            // This approach gives you access to all methods on the service
            let error = AppError.media(.playbackError("Failed to play audio"))
            ErrorHandlingService.shared.reportError(error)
        }
        
        private func reportErrorUsingServiceLocator() {
            // This approach is useful for code that might use different implementations
            // in different contexts (like testing)
            if let errorService = ServiceLocator.shared.resolve(ErrorHandlingServiceProtocol.self) {
                errorService.reportError(
                    AppError.authentication(.signInFailed("Service Locator demo"))
                )
            }
        }
    }
} 