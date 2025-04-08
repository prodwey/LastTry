import Foundation
import AVFoundation

// MARK: - Storage Errors

enum FileStorageError: Error, LocalizedError {
    case fileNotFound
    case directoryCreationFailed
    case failedToSaveFile(String)
    case failedToLoadFile(String)
    case failedToDeleteFile(String)
    case invalidFileURL
    case insufficientDiskSpace
    case invalidFileFormat(String)
    case accessDenied
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .directoryCreationFailed:
            return "Failed to create directory"
        case .failedToSaveFile(let message):
            return "Failed to save file: \(message)"
        case .failedToLoadFile(let message):
            return "Failed to load file: \(message)"
        case .failedToDeleteFile(let message):
            return "Failed to delete file: \(message)"
        case .invalidFileURL:
            return "Invalid file URL"
        case .insufficientDiskSpace:
            return "Insufficient disk space"
        case .invalidFileFormat(let format):
            return "Invalid file format: \(format)"
        case .accessDenied:
            return "Access denied to file"
        }
    }
}

// MARK: - File Metadata

struct FileMetadata {
    let fileName: String
    let fileExtension: String
    let mimeType: String
    let fileSize: Int64
    let dateCreated: Date
    let dateModified: Date
    let relativePathComponent: String?
    
    var fullFileName: String {
        return "\(fileName).\(fileExtension)"
    }
}

// MARK: - File Storage Protocol

protocol FileStorageServiceProtocol {
    /// Save a file to persistent storage
    func saveFile(at sourceURL: URL, withName fileName: String?) throws -> URL
    
    /// Save a file to persistent storage with a specific audio format
    func saveAudioFile(at sourceURL: URL, withName fileName: String?, format: AudioFormat) throws -> URL
    
    /// Load a file from storage by name
    func getFile(named fileName: String) throws -> URL
    
    /// Delete a file from storage
    func deleteFile(at fileURL: URL) throws
    
    /// Delete a file from storage by name
    func deleteFile(named fileName: String) throws
    
    /// Check if a file exists
    func fileExists(named fileName: String) -> Bool
    
    /// Get metadata for a file
    func getMetadata(for fileURL: URL) throws -> FileMetadata
    
    /// Create a file URL for a given filename
    func createFileURL(for fileName: String) -> URL
    
    /// Get the available storage space
    func getAvailableStorageSpace() -> Int64?
    
    /// Generate a unique filename
    func generateUniqueFileName(withExtension ext: String) -> String
}

// MARK: - Local File Storage Implementation

class LocalFileStorageService: FileStorageServiceProtocol {
    
    // Singleton instance
    static let shared = LocalFileStorageService()
    
    // Base directory for file storage
    private let baseDirectory: URL
    
    // Audio subdirectory
    private let audioDirectory: URL
    
    // File manager
    private let fileManager = FileManager.default
    
    private init() {
        // Get the documents directory
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Create a LastTry subdirectory for our app files
        baseDirectory = documentsDirectory.appendingPathComponent("LastTry", isDirectory: true)
        
        // Create the audio subdirectory
        audioDirectory = baseDirectory.appendingPathComponent("Audio", isDirectory: true)
        
        // Ensure directories exist
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true, attributes: nil)
        try? fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true, attributes: nil)
        
        print("File storage initialized at: \(baseDirectory.path)")
    }
    
    // MARK: - Public Methods
    
    func saveFile(at sourceURL: URL, withName fileName: String? = nil) throws -> URL {
        // Get file extension from source
        let fileExtension = sourceURL.pathExtension
        
        // Use provided filename or generate one
        let finalFileName = fileName ?? generateUniqueFileName(withExtension: fileExtension)
        
        // Create destination URL
        let destinationURL = baseDirectory.appendingPathComponent(finalFileName)
        
        // Ensure directories exist
        try ensureDirectoryExists(at: baseDirectory)
        
        do {
            // Check if we have enough storage space
            if let fileSize = try sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               let freeSpace = getAvailableStorageSpace(),
               fileSize > freeSpace {
                throw FileStorageError.insufficientDiskSpace
            }
            
            // If file already exists, remove it first
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            // Copy file to destination
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            
            return destinationURL
        } catch let error as FileStorageError {
            throw error
        } catch {
            throw FileStorageError.failedToSaveFile(error.localizedDescription)
        }
    }
    
    func saveAudioFile(at sourceURL: URL, withName fileName: String? = nil, format: AudioFormat) throws -> URL {
        // Check if the source format matches the requested format
        if sourceURL.pathExtension.lowercased() != format.fileExtension {
            // This would typically convert the file format, but for now we'll just validate
            throw FileStorageError.invalidFileFormat("Format conversion not implemented: \(sourceURL.pathExtension) to \(format.fileExtension)")
        }
        
        // Generate a filename if not provided
        let finalFileName = fileName ?? generateUniqueFileName(withExtension: format.fileExtension)
        
        // Create destination URL in audio directory
        let destinationURL = audioDirectory.appendingPathComponent(finalFileName)
        
        // Ensure directories exist
        try ensureDirectoryExists(at: audioDirectory)
        
        do {
            // Check if we have enough storage space
            if let fileSize = try sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               let freeSpace = getAvailableStorageSpace(),
               fileSize > freeSpace {
                throw FileStorageError.insufficientDiskSpace
            }
            
            // If file already exists, remove it first
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            // Copy file to destination
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            
            return destinationURL
        } catch let error as FileStorageError {
            throw error
        } catch {
            throw FileStorageError.failedToSaveFile(error.localizedDescription)
        }
    }
    
    func getFile(named fileName: String) throws -> URL {
        // First check in base directory
        let baseURL = baseDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: baseURL.path) {
            return baseURL
        }
        
        // Then check in audio directory
        let audioURL = audioDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: audioURL.path) {
            return audioURL
        }
        
        throw FileStorageError.fileNotFound
    }
    
    func deleteFile(at fileURL: URL) throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw FileStorageError.fileNotFound
        }
        
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw FileStorageError.failedToDeleteFile(error.localizedDescription)
        }
    }
    
    func deleteFile(named fileName: String) throws {
        do {
            let fileURL = try getFile(named: fileName)
            try deleteFile(at: fileURL)
        } catch let error as FileStorageError {
            throw error
        } catch {
            throw FileStorageError.failedToDeleteFile(error.localizedDescription)
        }
    }
    
    func fileExists(named fileName: String) -> Bool {
        // Check in base directory
        let baseURL = baseDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: baseURL.path) {
            return true
        }
        
        // Check in audio directory
        let audioURL = audioDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: audioURL.path)
    }
    
    func getMetadata(for fileURL: URL) throws -> FileMetadata {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw FileStorageError.fileNotFound
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let creationDate = attributes[.creationDate] as? Date ?? Date()
            let modificationDate = attributes[.modificationDate] as? Date ?? Date()
            
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            let fileExtension = fileURL.pathExtension
            
            // Determine MIME type
            let mimeType = getMIMEType(for: fileExtension)
            
            // Determine relative path component
            let relativePathComponent: String?
            if fileURL.path.hasPrefix(audioDirectory.path) {
                relativePathComponent = "Audio"
            } else if fileURL.path.hasPrefix(baseDirectory.path) {
                relativePathComponent = nil
            } else {
                relativePathComponent = nil
            }
            
            return FileMetadata(
                fileName: fileName,
                fileExtension: fileExtension,
                mimeType: mimeType,
                fileSize: fileSize,
                dateCreated: creationDate,
                dateModified: modificationDate,
                relativePathComponent: relativePathComponent
            )
        } catch {
            throw FileStorageError.failedToLoadFile(error.localizedDescription)
        }
    }
    
    func createFileURL(for fileName: String) -> URL {
        // Determine if this is an audio file based on extension
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        
        if AudioFormat.fromFileExtension(fileExtension) != nil {
            return audioDirectory.appendingPathComponent(fileName)
        } else {
            return baseDirectory.appendingPathComponent(fileName)
        }
    }
    
    func getAvailableStorageSpace() -> Int64? {
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: baseDirectory.path)
            return attributes[.systemFreeSize] as? Int64
        } catch {
            print("Error getting available storage space: \(error.localizedDescription)")
            return nil
        }
    }
    
    func generateUniqueFileName(withExtension ext: String) -> String {
        let uuid = UUID().uuidString
        let timestamp = Int(Date().timeIntervalSince1970)
        return "file_\(timestamp)_\(uuid).\(ext)"
    }
    
    // MARK: - Private Helpers
    
    private func ensureDirectoryExists(at url: URL) throws {
        guard !fileManager.fileExists(atPath: url.path) else {
            return
        }
        
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw FileStorageError.directoryCreationFailed
        }
    }
    
    private func getMIMEType(for fileExtension: String) -> String {
        let type: String
        
        switch fileExtension.lowercased() {
        case "wav":
            type = "audio/wav"
        case "mp3":
            type = "audio/mpeg"
        case "aac":
            type = "audio/aac"
        case "aiff", "aif":
            type = "audio/aiff"
        case "m4a":
            type = "audio/m4a"
        case "ogg":
            type = "audio/ogg"
        case "flac":
            type = "audio/flac"
        case "jpg", "jpeg":
            type = "image/jpeg"
        case "png":
            type = "image/png"
        case "pdf":
            type = "application/pdf"
        case "txt":
            type = "text/plain"
        default:
            type = "application/octet-stream"
        }
        
        return type
    }
} 