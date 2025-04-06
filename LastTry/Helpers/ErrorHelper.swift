import Foundation

// Renamed to avoid conflicting with existing types
struct DisplayError {
    let message: String
    let severity: DisplayErrorSeverity
    let actionType: DisplayErrorActionType
    let suggestion: String?
    
    init(
        message: String,
        severity: DisplayErrorSeverity = .error,
        actionType: DisplayErrorActionType = .retry,
        suggestion: String? = nil
    ) {
        self.message = message
        self.severity = severity
        self.actionType = actionType
        self.suggestion = suggestion
    }
}

// Renamed to avoid conflicting with existing types
enum DisplayErrorSeverity {
    case info
    case warning
    case error
    case critical
    
    // Static properties to avoid dot syntax ambiguity
    static let errorSeverity: DisplayErrorSeverity = .error
    static let warningSeverity: DisplayErrorSeverity = .warning
    static let infoSeverity: DisplayErrorSeverity = .info
    static let criticalSeverity: DisplayErrorSeverity = .critical
}

// Renamed to avoid conflicting with existing types
enum DisplayErrorActionType {
    case dismiss
    case retry
    case restart
    case contact
}

// Completely renamed to avoid any conflict with ErrorHelper
struct DetailedErrorProcessor {
    
    // Process task errors - renamed method to avoid ambiguity
    static func convertTaskError(_ error: TaskError) -> DisplayError? {
        switch error {
        case .invalidTaskData(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.warning,
                actionType: DisplayErrorActionType.dismiss
            )
        case .taskNotFound(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.warning,
                actionType: DisplayErrorActionType.dismiss,
                suggestion: "The task you're looking for may have been deleted."
            )
        case .failedToLoad(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry,
                suggestion: "Please check your internet connection and try again."
            )
        case .failedToSave(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry,
                suggestion: "Your changes could not be saved. Please try again."
            )
        case .failedToUpdate(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry,
                suggestion: "Your changes could not be updated. Please try again."
            )
        case .failedToDelete(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry,
                suggestion: "The task could not be deleted. Please try again."
            )
        case .aiGenerationFailed(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.warning,
                actionType: DisplayErrorActionType.dismiss,
                suggestion: "AI task generation failed. Try a different prompt or create a task manually."
            )
        // Handle all remaining cases with a default message
        case .unauthorizedAccess:
            return DisplayError(
                message: "You don't have permission to perform this action.",
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.dismiss
            )
        case .priorityConflict(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.warning,
                actionType: DisplayErrorActionType.dismiss
            )
        case .incompleteTask(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.warning,
                actionType: DisplayErrorActionType.dismiss
            )
        case .overdueTask(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.warning,
                actionType: DisplayErrorActionType.dismiss
            )
        case .coreDataError(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry
            )
        }
    }
    
    // Process session booking errors - updated to match the actual SessionError cases and renamed
    static func convertSessionError(_ error: SessionError) -> DisplayError? {
        switch error {
        case .invalidSessionData(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.warning,
                actionType: DisplayErrorActionType.dismiss
            )
        case .sessionNotFound(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.warning,
                actionType: DisplayErrorActionType.dismiss,
                suggestion: "The session you're looking for may have been cancelled."
            )
        case .failedToSave(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry,
                suggestion: "Session booking failed. Please try again later."
            )
        case .failedToLoad(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry,
                suggestion: "Please check your internet connection and try again."
            )
        case .failedToUpdate(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry,
                suggestion: "Could not update the session. Please try again."
            )
        case .failedToDelete(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry,
                suggestion: "Could not cancel the session. Please try again."
            )
        case .studioUnavailable(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.warning,
                actionType: DisplayErrorActionType.dismiss,
                suggestion: "Please choose a different studio."
            )
        case .schedulingConflict(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.warning,
                actionType: DisplayErrorActionType.dismiss,
                suggestion: "Please choose a different time slot."
            )
        case .invalidDuration:
            return DisplayError(
                message: "Invalid session duration",
                severity: DisplayErrorSeverity.warning,
                actionType: DisplayErrorActionType.dismiss,
                suggestion: "Please select a valid duration for the session."
            )
        case .pastDateBooking:
            return DisplayError(
                message: "Cannot book sessions in the past",
                severity: DisplayErrorSeverity.warning,
                actionType: DisplayErrorActionType.dismiss,
                suggestion: "Please select a future date."
            )
        case .coreDataError(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry
            )
        }
    }
    
    // Process song upload errors - updated to match the actual SongError cases and renamed
    static func convertSongError(_ error: SongError) -> DisplayError? {
        switch error {
        case .songNotFound(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.warning,
                actionType: DisplayErrorActionType.dismiss,
                suggestion: "The song you're looking for may have been deleted."
            )
        case .failedToSave(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry,
                suggestion: "Song upload failed. Please try again with a smaller file or check your connection."
            )
        case .failedToLoad(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry,
                suggestion: "Please check your internet connection and try again."
            )
        case .failedToUpdate(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry,
                suggestion: "Failed to update song information. Please try again."
            )
        case .failedToDelete(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry,
                suggestion: "The song could not be deleted. Please try again."
            )
        case .invalidFileFormat(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.warning,
                actionType: DisplayErrorActionType.dismiss,
                suggestion: "Please choose a different audio file with a supported format."
            )
        case .fileError(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry,
                suggestion: "There was a problem with the audio file. Please try again."
            )
        case .metadataError(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.warning,
                actionType: DisplayErrorActionType.dismiss,
                suggestion: "Could not read file metadata. Please try a different file."
            )
        case .playbackError(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry,
                suggestion: "Could not play the audio file. Please try again."
            )
        case .fileNotFound:
            return DisplayError(
                message: "Audio file not found",
                severity: DisplayErrorSeverity.warning,
                actionType: DisplayErrorActionType.dismiss,
                suggestion: "Please select an audio file."
            )
        case .coreDataError(let message):
            return DisplayError(
                message: message,
                severity: DisplayErrorSeverity.error,
                actionType: DisplayErrorActionType.retry
            )
        }
    }
} 