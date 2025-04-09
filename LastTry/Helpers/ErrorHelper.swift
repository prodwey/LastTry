import Foundation

// MARK: - Unified Application Error Type

/// The primary error type used throughout the application
enum AppError: Error, LocalizedError, Identifiable {
    // Authentication domain errors
    case authentication(AuthErrorType)
    
    // Data domain errors
    case data(DataErrorType)
    
    // Media domain errors
    case media(MediaErrorType)
    
    // Network domain errors
    case network(NetworkErrorType)
    
    // General application errors
    case general(GeneralErrorType)
    
    // Raw error pass-through for legacy code
    case unknown(Error)
    
    // MARK: - Error Sub-Types
    
    /// Authentication-related error types
    enum AuthErrorType {
        case invalidCredentials
        case userNotFound
        case signInFailed(String)
        case signUpFailed(String)
        case signOutFailed(String)
        case sessionExpired
        case unauthorized
        case accountDisabled
    }
    
    /// Data-related error types
    enum DataErrorType {
        case notFound(entity: String, id: String? = nil)
        case failedToSave(entity: String, reason: String? = nil)
        case failedToLoad(entity: String, reason: String? = nil)
        case failedToUpdate(entity: String, reason: String? = nil)
        case failedToDelete(entity: String, reason: String? = nil)
        case invalidData(entity: String, reason: String? = nil)
        case duplicateEntry(entity: String, field: String? = nil)
        case entityRelationError(message: String)
    }
    
    /// Media-related error types
    enum MediaErrorType {
        case fileNotFound(path: String? = nil)
        case invalidFormat(expected: String? = nil, received: String? = nil)
        case playbackError(String)
        case recordingError(String)
        case fileSizeExceeded
        case storageError(String)
        case metadataError(String)
    }
    
    /// Network-related error types
    enum NetworkErrorType {
        case noConnection
        case serverError(code: Int? = nil)
        case timeout
        case badResponse
        case invalidURL
    }
    
    /// General application error types 
    enum GeneralErrorType {
        case internalError(String)
        case notImplemented
        case userCancelled
        case missingPermissions(String)
        case resourceUnavailable(String)
    }
    
    // MARK: - Identifiable Conformance
    
    public var id: String {
        switch self {
        case .authentication(let type):
            return "auth.\(String(describing: type))"
        case .data(let type):
            return "data.\(String(describing: type))"
        case .media(let type):
            return "media.\(String(describing: type))"
        case .network(let type):
            return "network.\(String(describing: type))"
        case .general(let type):
            return "general.\(String(describing: type))"
        case .unknown(let error):
            return "unknown.\(error.localizedDescription)"
        }
    }
    
    // MARK: - LocalizedError Conformance
    
    public var errorDescription: String? {
        switch self {
        case .authentication(let type):
            switch type {
            case .invalidCredentials:
                return "Invalid username or password"
            case .userNotFound:
                return "User not found"
            case .signInFailed(let message):
                return "Failed to sign in: \(message)"
            case .signUpFailed(let message):
                return "Failed to sign up: \(message)"
            case .signOutFailed(let message):
                return "Failed to sign out: \(message)"
            case .sessionExpired:
                return "Your session has expired. Please sign in again"
            case .unauthorized:
                return "You are not authorized to perform this action"
            case .accountDisabled:
                return "This account has been disabled"
            }
            
        case .data(let type):
            switch type {
            case .notFound(let entity, let id):
                if let id = id {
                    return "\(entity) with ID \(id) not found"
                }
                return "\(entity) not found"
            case .failedToSave(let entity, let reason):
                if let reason = reason {
                    return "Failed to save \(entity): \(reason)"
                }
                return "Failed to save \(entity)"
            case .failedToLoad(let entity, let reason):
                if let reason = reason {
                    return "Failed to load \(entity): \(reason)"
                }
                return "Failed to load \(entity)"
            case .failedToUpdate(let entity, let reason):
                if let reason = reason {
                    return "Failed to update \(entity): \(reason)"
                }
                return "Failed to update \(entity)"
            case .failedToDelete(let entity, let reason):
                if let reason = reason {
                    return "Failed to delete \(entity): \(reason)"
                }
                return "Failed to delete \(entity)"
            case .invalidData(let entity, let reason):
                if let reason = reason {
                    return "Invalid \(entity) data: \(reason)"
                }
                return "Invalid \(entity) data"
            case .duplicateEntry(let entity, let field):
                if let field = field {
                    return "A \(entity) with this \(field) already exists"
                }
                return "This \(entity) already exists"
            case .entityRelationError(let message):
                return message
            }
            
        case .media(let type):
            switch type {
            case .fileNotFound(let path):
                if let path = path {
                    return "File not found at \(path)"
                }
                return "File not found"
            case .invalidFormat(let expected, let received):
                if let expected = expected, let received = received {
                    return "Invalid file format. Expected: \(expected), received: \(received)"
                } else if let expected = expected {
                    return "Invalid file format. Expected: \(expected)"
                }
                return "Invalid file format"
            case .playbackError(let message):
                return "Playback error: \(message)"
            case .recordingError(let message):
                return "Recording error: \(message)"
            case .fileSizeExceeded:
                return "The file size exceeds the maximum allowed"
            case .storageError(let message):
                return "Storage error: \(message)"
            case .metadataError(let message):
                return "Metadata error: \(message)"
            }
            
        case .network(let type):
            switch type {
            case .noConnection:
                return "No internet connection"
            case .serverError(let code):
                if let code = code {
                    return "Server error (code: \(code))"
                }
                return "Server error"
            case .timeout:
                return "The request timed out"
            case .badResponse:
                return "Received an invalid response from the server"
            case .invalidURL:
                return "Invalid URL"
            }
            
        case .general(let type):
            switch type {
            case .internalError(let message):
                return "Internal error: \(message)"
            case .notImplemented:
                return "This feature is not yet implemented"
            case .userCancelled:
                return "Operation cancelled by user"
            case .missingPermissions(let permission):
                return "Missing required permission: \(permission)"
            case .resourceUnavailable(let resource):
                return "Resource unavailable: \(resource)"
            }
            
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    /// Provides a concise, user-friendly message for the error
    var userMessage: String {
        return errorDescription ?? "An unknown error occurred"
    }
    
    /// Determines if this error is recoverable
    var isRecoverable: Bool {
        switch self {
        case .authentication(.sessionExpired),
             .authentication(.signInFailed),
             .authentication(.signOutFailed),
             .data(.failedToSave),
             .data(.failedToLoad),
             .data(.failedToUpdate),
             .data(.failedToDelete),
             .media(.playbackError),
             .network(.noConnection),
             .network(.timeout),
             .network(.serverError):
            return true
        default:
            return false
        }
    }
    
    /// Returns a suggested action to recover from this error
    var recoverySuggestion: String? {
        switch self {
        case .authentication(.sessionExpired):
            return "Please sign in again to continue"
        case .authentication(.signInFailed), .authentication(.invalidCredentials):
            return "Please check your email and password and try again"
        case .authentication(.signUpFailed):
            return "Please try signing up with different information"
        case .network(.noConnection):
            return "Please check your internet connection and try again"
        case .network(.timeout), .network(.serverError):
            return "Our servers are busy. Please try again later"
        case .media(.fileNotFound):
            return "The file may have been moved or deleted"
        case .media(.invalidFormat):
            return "Please try with a supported file format"
        case .media(.playbackError):
            return "Try closing other applications and playing again"
        case .data(.failedToSave), .data(.failedToUpdate), .data(.failedToDelete):
            return "Please try again. If the problem persists, restart the app"
        default:
            return nil
        }
    }
}

// MARK: - Error Conversion Extensions

// Convert AuthError to AppError
extension AuthError {
    func toAppError() -> AppError {
        switch self {
        case .signInFailed(let message):
            return .authentication(.signInFailed(message))
        case .signUpFailed(let message):
            return .authentication(.signUpFailed(message))
        case .signOutFailed(let message):
            return .authentication(.signOutFailed(message))
        case .userNotFound:
            return .authentication(.userNotFound)
        case .invalidCredentials:
            return .authentication(.invalidCredentials)
        case .networkError:
            return .network(.noConnection)
        case .unknown:
            return .general(.internalError("Unknown authentication error"))
        }
    }
}

// Convert SongError to AppError
extension SongError {
    func toAppError() -> AppError {
        switch self {
        case .songNotFound(let message):
            return .data(.notFound(entity: "Song", id: message))
        case .failedToSave(let message):
            return .data(.failedToSave(entity: "Song", reason: message))
        case .failedToLoad(let message):
            return .data(.failedToLoad(entity: "Song", reason: message))
        case .failedToUpdate(let message):
            return .data(.failedToUpdate(entity: "Song", reason: message))
        case .failedToDelete(let message):
            return .data(.failedToDelete(entity: "Song", reason: message))
        case .invalidFileFormat(let message):
            return .media(.invalidFormat(expected: nil, received: message))
        case .fileError(let message):
            return .media(.storageError(message))
        case .metadataError(let message):
            return .media(.metadataError(message))
        case .playbackError(let message):
            return .media(.playbackError(message))
        case .fileNotFound:
            return .media(.fileNotFound())
        case .coreDataError(let message):
            return .data(.failedToLoad(entity: "Song", reason: message))
        }
    }
}

// Convert AudioError to AppError
extension AudioError {
    func toAppError() -> AppError {
        switch self {
        case .fileNotFound:
            return .media(.fileNotFound())
        case .invalidFileFormat:
            return .media(.invalidFormat())
        case .failedToLoad(let message):
            return .media(.storageError(message))
        case .playbackError(let message):
            return .media(.playbackError(message))
        }
    }
}

// Convert SessionError to AppError
extension SessionError {
    func toAppError() -> AppError {
        switch self {
        case .invalidSessionData(let message):
            return .data(.invalidData(entity: "Session", reason: message))
        case .sessionNotFound(let message):
            return .data(.notFound(entity: "Session", id: message))
        case .failedToSave(let message):
            return .data(.failedToSave(entity: "Session", reason: message))
        case .failedToLoad(let message):
            return .data(.failedToLoad(entity: "Session", reason: message))
        case .failedToUpdate(let message):
            return .data(.failedToUpdate(entity: "Session", reason: message))
        case .failedToDelete(let message):
            return .data(.failedToDelete(entity: "Session", reason: message))
        case .schedulingConflict(let message):
            return .data(.duplicateEntry(entity: "Session", field: message))
        case .pastDateBooking:
            return .data(.invalidData(entity: "Session", reason: "Cannot book session in the past"))
        case .invalidDuration:
            return .data(.invalidData(entity: "Session", reason: "Invalid duration"))
        case .studioUnavailable(let message):
            return .general(.resourceUnavailable("Studio unavailable: \(message)"))
        case .coreDataError(let message):
            return .data(.failedToLoad(entity: "Session", reason: message))
        }
    }
}

// Convert UserError to AppError
extension UserError {
    func toAppError() -> AppError {
        switch self {
        case .userNotFound(_):
            return .authentication(.userNotFound)
        case .invalidUserData(let message):
            return .data(.invalidData(entity: "User", reason: message))
        case .failedToUpdate(let message):
            return .data(.failedToUpdate(entity: "User", reason: message))
        case .coreDataError(let message):
            return .data(.failedToLoad(entity: "User", reason: message))
        case .failedToSave(let message):
            return .data(.failedToSave(entity: "User", reason: message))
        case .failedToLoad(let message):
            return .data(.failedToLoad(entity: "User", reason: message))
        case .failedToDelete(let message):
            return .data(.failedToDelete(entity: "User", reason: message))
        case .duplicateUser(let message):
            return .data(.duplicateEntry(entity: "User", field: message))
        case .missingRequiredFields:
            return .data(.invalidData(entity: "User", reason: "Missing required fields"))
        case .unauthorized:
            return .authentication(.unauthorized)
        }
    }
}

// Convert TaskError to AppError
extension TaskError {
    func toAppError() -> AppError {
        switch self {
        case .taskNotFound(let message):
            return .data(.notFound(entity: "Task", id: message))
        case .failedToSave(let message):
            return .data(.failedToSave(entity: "Task", reason: message))
        case .failedToLoad(let message):
            return .data(.failedToLoad(entity: "Task", reason: message))
        case .failedToUpdate(let message):
            return .data(.failedToUpdate(entity: "Task", reason: message))
        case .failedToDelete(let message):
            return .data(.failedToDelete(entity: "Task", reason: message))
        case .invalidTaskData(let message):
            return .data(.invalidData(entity: "Task", reason: message))
        case .unauthorizedAccess:
            return .authentication(.unauthorized)
        case .priorityConflict(let message):
            return .data(.invalidData(entity: "Task", reason: "Priority conflict: \(message)"))
        case .incompleteTask(let message):
            return .data(.invalidData(entity: "Task", reason: "Task is incomplete: \(message)"))
        case .overdueTask(let message):
            return .data(.invalidData(entity: "Task", reason: "Task is overdue: \(message)"))
        case .coreDataError(let message):
            return .data(.failedToLoad(entity: "Task", reason: message))
        case .aiGenerationFailed(let message):
            return .general(.internalError("AI generation failed: \(message)"))
        }
    }
}

// MARK: - Error Display Helpers

struct DisplayError: Identifiable {
    let id = UUID()
    let message: String
    let severity: DisplayErrorSeverity
    let actionType: DisplayErrorActionType
    var suggestion: String? = nil
    
    init(message: String, severity: DisplayErrorSeverity, actionType: DisplayErrorActionType, suggestion: String? = nil) {
        self.message = message
        self.severity = severity
        self.actionType = actionType
        self.suggestion = suggestion
    }
}

enum DisplayErrorSeverity {
    case info
    case warning
    case error
    case critical
    
    static var infoSeverity: Self { .info }
    static var warningSeverity: Self { .warning }
    static var errorSeverity: Self { .error }
    static var criticalSeverity: Self { .critical }
}

enum DisplayErrorActionType {
    case dismiss
    case retry
    case navigate
}

// Detailled Error Processor
class DetailedErrorProcessor {
    static func convertAppError(_ error: AppError) -> DisplayError {
        let severity: DisplayErrorSeverity
        let actionType: DisplayErrorActionType
        
        switch error {
        case .authentication:
            severity = .warning
            actionType = .retry
        case .data:
            severity = .warning
            actionType = .retry
        case .media:
            severity = .warning
            actionType = .dismiss
        case .network:
            severity = .warning
            actionType = .retry
        case .general:
            severity = .error
            actionType = .dismiss
        case .unknown:
            severity = .error
            actionType = .dismiss
        }
        
        return DisplayError(
            message: error.userMessage,
            severity: severity,
            actionType: actionType,
            suggestion: error.recoverySuggestion
        )
    }
    
    // Legacy conversion methods maintained for backward compatibility
    
    static func convertSongError(_ error: SongError) -> DisplayError? {
        let appError = error.toAppError()
        return convertAppError(appError)
    }
    
    static func convertSessionError(_ error: SessionError) -> DisplayError? {
        let appError = error.toAppError()
        return convertAppError(appError)
    }
    
    static func convertTaskError(_ error: TaskError) -> DisplayError? {
        let appError = error.toAppError()
        return convertAppError(appError)
    }
} 