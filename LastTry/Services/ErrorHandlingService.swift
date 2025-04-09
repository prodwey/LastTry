import Foundation
import Combine
import SwiftUI

/// A service that provides centralized error handling and reporting for the entire application
class ErrorHandlingService: ObservableObject {
    // MARK: - Published Properties
    
    /// The current error being displayed to the user
    @Published private(set) var currentError: AppError?
    
    /// Formatted display error for UI components
    @Published private(set) var displayError: DisplayError?
    
    /// Flag to indicate if an error is being presented
    @Published var isShowingError: Bool = false
    
    // MARK: - Private Properties
    
    /// Subject for receiving errors from different parts of the app
    private let errorSubject = PassthroughSubject<AppError, Never>()
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupSubscriptions()
    }
    
    // MARK: - Public Methods
    
    /// Report an error to the centralized error handling system
    /// - Parameter error: The AppError to report
    func reportError(_ error: AppError) {
        errorSubject.send(error)
    }
    
    /// Report an error from a legacy error type
    /// - Parameter error: Legacy error type (SongError, AuthError, etc.)
    func reportError<E: Error>(_ error: E) {
        let appError = convertToAppError(error)
        errorSubject.send(appError)
    }
    
    /// Clear the current error state
    func clearError() {
        withAnimation {
            self.currentError = nil
            self.displayError = nil
            self.isShowingError = false
        }
    }
    
    /// Handle a Result type, extracting either the success value or reporting the error
    /// - Parameters:
    ///   - result: The Result to handle
    ///   - successHandler: Closure to handle the success value
    func handleResult<T>(_ result: Result<T, Error>, successHandler: (T) -> Void) {
        switch result {
        case .success(let value):
            successHandler(value)
        case .failure(let error):
            reportError(error)
        }
    }
    
    /// Handle an optional error, reporting it if non-nil
    /// - Parameter error: Optional error to handle
    /// - Returns: Whether an error was reported
    @discardableResult
    func handleOptionalError(_ error: Error?) -> Bool {
        guard let error = error else {
            return false
        }
        
        reportError(error)
        return true
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Subscribe to the error subject
        errorSubject
            .debounce(for: 0.3, scheduler: RunLoop.main) // Debounce to prevent rapid error changes
            .removeDuplicates { $0.id == $1.id } // Only process unique errors
            .sink { [weak self] error in
                guard let self = self else { return }
                
                // Log the error
                self.logError(error)
                
                // Update the current error
                self.currentError = error
                
                // Convert to display error
                self.displayError = DetailedErrorProcessor.convertAppError(error)
                
                // Show the error
                withAnimation {
                    self.isShowingError = true
                }
            }
            .store(in: &cancellables)
    }
    
    private func logError(_ error: AppError) {
        #if DEBUG
        print("🔴 ERROR: \(error.localizedDescription)")
        if let recoverySuggestion = error.recoverySuggestion {
            print("💡 SUGGESTION: \(recoverySuggestion)")
        }
        #endif
    }
    
    private func convertToAppError<E: Error>(_ error: E) -> AppError {
        // First check if it's already an AppError
        if let appError = error as? AppError {
            return appError
        }
        
        // Convert from known legacy error types
        switch error {
        case let songError as SongError:
            return songError.toAppError()
        case let authError as AuthError:
            return authError.toAppError()
        case let audioError as AudioError:
            return audioError.toAppError()
        case let sessionError as SessionError:
            return sessionError.toAppError()
        case let userError as UserError:
            return userError.toAppError()
        case let coreDataError as CoreDataError:
            return .data(.failedToLoad(entity: "Data", reason: coreDataError.localizedDescription))
        case let nsError as NSError:
            // Handle common system errors
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet:
                    return .network(.noConnection)
                case NSURLErrorTimedOut:
                    return .network(.timeout)
                case NSURLErrorBadURL:
                    return .network(.invalidURL)
                default:
                    return .network(.serverError(code: nsError.code))
                }
            } else if nsError.domain == "CoreDataError" {
                return .data(.failedToLoad(entity: "Data", reason: nsError.localizedDescription))
            }
            
            // Fall through to default
            return .unknown(error)
        default:
            return .unknown(error)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply standard error handling to a view
    /// - Parameters:
    ///   - errorService: The ErrorHandlingService to use
    ///   - action: Optional action to perform when error is dismissed
    /// - Returns: View with error handling
    func withErrorHandling(_ errorService: ErrorHandlingService, onDismiss action: (() -> Void)? = nil) -> some View {
        self.modifier(ErrorHandlingViewModifier(errorService: errorService, onDismiss: action))
    }
}

// MARK: - View Modifier

struct ErrorHandlingViewModifier: ViewModifier {
    @ObservedObject var errorService: ErrorHandlingService
    var onDismiss: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .alert(
                errorService.displayError?.message ?? "An error occurred",
                isPresented: $errorService.isShowingError
            ) {
                Button("OK") {
                    errorService.clearError()
                    onDismiss?()
                }
                
                if errorService.currentError?.isRecoverable == true {
                    Button("Retry") {
                        errorService.clearError()
                        // Note: The retry action would need to be handled by the parent view
                    }
                }
            } message: {
                if let suggestion = errorService.displayError?.suggestion {
                    Text(suggestion)
                }
            }
    }
} 