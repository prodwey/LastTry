import SwiftUI

// MARK: - Color Extensions
extension Color {
    // Main theme colors
    static let appPrimary = Color(red: 1.0, green: 0.18, blue: 0.18) // YouTube Music red
    static let appSecondary = Color(red: 0.15, green: 0.15, blue: 0.15) // Dark gray for cards
    
    // Background colors
    static let appBackground = Color(red: 0.07, green: 0.07, blue: 0.07) // Almost black
    static let appSurfaceBackground = Color(red: 0.11, green: 0.11, blue: 0.11) // Card backgrounds
    static let appElevatedBackground = Color(red: 0.15, green: 0.15, blue: 0.15) // Elevated components
    
    // Text colors
    static let appTextPrimary = Color.white
    static let appTextSecondary = Color(white: 0.7)
    static let appTextTertiary = Color(white: 0.5)
    
    // Utility colors
    static let appSuccess = Color.green
    static let appWarning = Color.orange
    static let appError = Color.red
    static let appDivider = Color(white: 0.2)
}

// MARK: - Text Styles
struct TitleText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(.appTextPrimary)
    }
}

struct HeadingText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.appTextPrimary)
    }
}

struct SubheadingText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.title3)
            .fontWeight(.medium)
            .foregroundColor(.appTextPrimary)
    }
}

struct BodyText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.body)
            .foregroundColor(.appTextPrimary)
    }
}

struct CaptionText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.appTextSecondary)
    }
}

// MARK: - Button Styles
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.appTextPrimary)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.appDivider, lineWidth: 1)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// MARK: - Card Styles
struct MediaCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.appSurfaceBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Input Styles
struct AppTextField: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    
    @State private var isPasswordVisible: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.appTextSecondary)
            
            if isSecure {
                HStack {
                    if isPasswordVisible {
                        TextField(placeholder, text: $text)
                            .autocorrectionDisabled(true)
                            .textContentType(.oneTimeCode) // Prevents password autofill
                            .foregroundColor(.appTextPrimary)
                    } else {
                        SecureField(placeholder, text: $text)
                            .textContentType(.oneTimeCode) // Prevents password autofill
                            .foregroundColor(.appTextPrimary)
                    }
                    
                    // Toggle password visibility button
                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.appTextSecondary)
                    }
                }
                .padding()
                .background(Color.appSurfaceBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appDivider, lineWidth: 1)
                )
            } else {
                TextField(placeholder, text: $text)
                    .padding()
                    .background(Color.appSurfaceBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.appDivider, lineWidth: 1)
                    )
            }
        }
        .foregroundColor(.appTextPrimary)
    }
}

// MARK: - Tab Styles
struct CustomTabStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(height: 50)
            .background(Color.appBackground)
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color.appDivider),
                alignment: .top
            )
    }
}

// MARK: - Navigation Bar Styles
struct CustomNavigationBar: ViewModifier {
    var title: String
    
    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - View Modifiers
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    func withMediaCard() -> some View {
        modifier(MediaCard())
    }
    
    func withCustomNavBar(title: String) -> some View {
        modifier(CustomNavigationBar(title: title))
    }
    
    func withCustomTabBar() -> some View {
        modifier(CustomTabStyle())
    }
}

// MARK: - Error Display
enum ErrorSeverity {
    case info
    case warning
    case error
    
    var icon: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .info:
            return Color.blue
        case .warning:
            return Color.orange
        case .error:
            return Color.appError
        }
    }
}

struct ErrorDisplayView: View {
    var message: String
    var severity: ErrorSeverity
    var isPresented: Binding<Bool>
    var action: (() -> Void)? = nil
    
    var body: some View {
        if isPresented.wrappedValue {
            VStack {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: severity.icon)
                        .font(.system(size: 16))
                        .foregroundColor(severity.color)
                    
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            isPresented.wrappedValue = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                    }
                }
                .padding()
                .background(Color.appElevatedBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(severity.color.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                .onTapGesture {
                    if let action = action {
                        action()
                    }
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .padding(.horizontal)
            .animation(.easeInOut, value: isPresented.wrappedValue)
            .zIndex(100) // Ensure it appears above other content
        }
    }
}

// Extension to easily add error display to any view
extension View {
    func withErrorDisplay(
        message: String,
        severity: ErrorSeverity = .error,
        isPresented: Binding<Bool>,
        action: (() -> Void)? = nil
    ) -> some View {
        ZStack(alignment: .top) {
            self
            
            ErrorDisplayView(
                message: message,
                severity: severity,
                isPresented: isPresented,
                action: action
            )
            .padding(.top, 8)
        }
    }
}

// MARK: - Error Helper
struct ErrorHelper {
    // Convert domain errors to human-friendly messages and determine severity
    static func processAuthError(_ error: AuthError?) -> (message: String, severity: ErrorSeverity)? {
        guard let error = error else { return nil }
        
        let severity: ErrorSeverity = {
            switch error {
            case .networkError:
                return .warning
            case .signInFailed, .signUpFailed, .signOutFailed, .userNotFound, 
                 .invalidCredentials, .unknown, .none:
                return .error
            }
        }()
        
        return (message: error.localizedDescription, severity: severity)
    }
    
    static func processUserError(_ error: UserError?) -> (message: String, severity: ErrorSeverity)? {
        guard let error = error else { return nil }
        
        let severity: ErrorSeverity = {
            switch error {
            case .userNotFound, .invalidUserData, .duplicateUser, .missingRequiredFields:
                return .warning
            case .failedToSave, .failedToLoad, .failedToUpdate, .failedToDelete, 
                 .unauthorized, .coreDataError:
                return .error
            }
        }()
        
        return (message: error.localizedDescription, severity: severity)
    }
    
    static func processSessionError(_ error: SessionError?) -> (message: String, severity: ErrorSeverity)? {
        guard let error = error else { return nil }
        
        let severity: ErrorSeverity = {
            switch error {
            case .pastDateBooking, .invalidDuration, .studioUnavailable, 
                 .schedulingConflict, .invalidSessionData:
                return .warning
            case .sessionNotFound, .failedToSave, .failedToLoad, .failedToUpdate, 
                 .failedToDelete, .coreDataError:
                return .error
            }
        }()
        
        return (message: error.localizedDescription, severity: severity)
    }
    
    static func processSongError(_ error: SongError?) -> (message: String, severity: ErrorSeverity)? {
        guard let error = error else { return nil }
        
        let severity: ErrorSeverity = {
            switch error {
            case .invalidFileFormat, .fileNotFound, .metadataError:
                return .warning
            case .songNotFound, .failedToSave, .failedToLoad, .failedToUpdate, 
                 .failedToDelete, .fileError, .playbackError, .coreDataError:
                return .error
            }
        }()
        
        return (message: error.localizedDescription, severity: severity)
    }
    
    static func processTaskError(_ error: TaskError?) -> (message: String, severity: ErrorSeverity)? {
        guard let error = error else { return nil }
        
        let severity: ErrorSeverity = {
            switch error {
            case .invalidTaskData, .priorityConflict, .incompleteTask, .overdueTask:
                return .warning
            case .taskNotFound, .failedToSave, .failedToLoad, .failedToUpdate, 
                 .failedToDelete, .unauthorizedAccess, .coreDataError, .aiGenerationFailed:
                return .error
            }
        }()
        
        return (message: error.localizedDescription, severity: severity)
    }
    
    // Generic method to auto-dismiss error after a delay
    static func autoDismissError(isPresented: Binding<Bool>, delay: TimeInterval = 5.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation {
                isPresented.wrappedValue = false
            }
        }
    }
}

// MARK: - App Error Handling View

// A view that listens for errors from multiple services and displays them
struct AppErrorView: View {
    @EnvironmentObject var appState: AppState
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var errorSeverity: ErrorSeverity = .error
    
    // Get services from ServiceLocator
    private let authService = ServiceLocator.shared.resolve(AuthenticationServiceProtocol.self)
    private let userManager = ServiceLocator.shared.resolve(UserManagerProtocol.self)
    private let sessionManager = ServiceLocator.shared.resolve(SessionManager.self)
    private let songManager = ServiceLocator.shared.resolve(SongManager.self)
    private let taskManager = ServiceLocator.shared.resolve(TaskManagerProtocol.self)
    
    var body: some View {
        Group {
            // This is an empty view that just observes errors
        }
        .onChange(of: authService?.authError) { _, newError in
            if let error = newError, let processedError = ErrorHelper.processAuthError(error) {
                showError(message: processedError.message, severity: processedError.severity)
            }
        }
        .onChange(of: userManager?.authError) { _, newError in
            if let error = newError, let processedError = ErrorHelper.processUserError(error) {
                showError(message: processedError.message, severity: processedError.severity)
            }
        }
        .onChange(of: sessionManager?.sessionError) { _, newError in
            if let error = newError, let processedError = ErrorHelper.processSessionError(error) {
                showError(message: processedError.message, severity: processedError.severity)
            }
        }
        .onChange(of: songManager?.songError) { _, newError in
            if let error = newError, let processedError = ErrorHelper.processSongError(error) {
                showError(message: processedError.message, severity: processedError.severity)
            }
        }
        .onChange(of: taskManager?.taskError) { _, newError in
            if let error = newError, let processedError = ErrorHelper.processTaskError(error) {
                showError(message: processedError.message, severity: processedError.severity)
            }
        }
        .withErrorDisplay(
            message: errorMessage,
            severity: errorSeverity,
            isPresented: $showError
        )
    }
    
    private func showError(message: String, severity: ErrorSeverity) {
        errorMessage = message
        errorSeverity = severity
        
        withAnimation {
            showError = true
        }
        
        // Auto dismiss after a delay
        ErrorHelper.autoDismissError(isPresented: $showError)
    }
}

// Extension to easily add app-wide error handling to any view
extension View {
    func withAppErrorHandling() -> some View {
        ZStack(alignment: .top) {
            self
            
            AppErrorView()
        }
    }
}

// MARK: - Loading View
enum LoadingSize {
    case small
    case medium
    case large
    
    var dimensions: CGFloat {
        switch self {
        case .small: return 40
        case .medium: return 80
        case .large: return 120
        }
    }
    
    var strokeWidth: CGFloat {
        switch self {
        case .small: return 2
        case .medium: return 3
        case .large: return 4
        }
    }
}

struct LoadingView: View {
    var size: LoadingSize = .medium
    var message: String? = nil
    var tint: Color = .appPrimary
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: tint))
                .scaleEffect(size == .small ? 1.0 : (size == .medium ? 1.5 : 2.0))
                .frame(width: size.dimensions, height: size.dimensions)
            
            if let message = message {
                Text(message)
                    .font(.callout)
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color.appElevatedBackground.opacity(0.8))
        .cornerRadius(12)
    }
}

// Overlay modifier for showing loading state
extension View {
    func withLoading(isLoading: Bool, message: String? = nil) -> some View {
        ZStack {
            self
                .disabled(isLoading)
                .blur(radius: isLoading ? 1 : 0)
            
            if isLoading {
                LoadingOverlay(isLoading: isLoading, message: message)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// Convenience modifier for form validation
extension View {
    func withFormValidation(
        showValidation: Bool,
        validationMessage: String? = nil
    ) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        showValidation ? 
                            (validationMessage == nil ? Color.appSuccess : Color.appError) : 
                            Color.clear,
                        lineWidth: 1
                    )
            )
    }
} 