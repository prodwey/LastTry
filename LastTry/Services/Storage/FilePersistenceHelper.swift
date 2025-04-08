import Foundation
import AVFoundation
import Combine

// MARK: - File Persistence Helper

class FilePersistenceHelper {
    
    // Singleton instance
    static let shared = FilePersistenceHelper()
    
    // Dependencies
    private let fileManager = FileManager.default
    private let storageService: FileStorageServiceProtocol
    private let audioFileManager: AudioFileManager
    
    // Publisher for upload status
    private let uploadStatusSubject = PassthroughSubject<FileUploadStatus, Never>()
    var uploadStatus: AnyPublisher<FileUploadStatus, Never> {
        return uploadStatusSubject.eraseToAnyPublisher()
    }
    
    // Private initializer for singleton
    private init(
        storageService: FileStorageServiceProtocol = LocalFileStorageService.shared,
        audioFileManager: AudioFileManager = AudioFileManager.shared
    ) {
        self.storageService = storageService
        self.audioFileManager = audioFileManager
        print("FilePersistenceHelper initialized")
    }
    
    // MARK: - File Upload Operations
    
    /// Upload a file for a song from a temporary URL
    /// This copies the file from its temporary location to a permanent one in the app's storage
    func uploadSongFile(from sourceURL: URL, songId: String, format: AudioFormat) -> AnyPublisher<URL, Error> {
        // Create a future that wraps the file operation
        return Future<URL, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(FileStorageError.invalidFileURL))
                return
            }
            
            // Update status to uploading
            self.uploadStatusSubject.send(.uploading(songId: songId, progress: 0))
            
            // Perform the upload on a background queue
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Validate the file exists
                    guard self.fileManager.fileExists(atPath: sourceURL.path) else {
                        self.uploadStatusSubject.send(.failed(songId: songId, error: FileStorageError.fileNotFound))
                        promise(.failure(FileStorageError.fileNotFound))
                        return
                    }
                    
                    // Update progress
                    self.uploadStatusSubject.send(.uploading(songId: songId, progress: 0.3))
                    
                    // Save the file using our AudioFileManager
                    let destinationURL = try self.audioFileManager.saveSongAudioFile(
                        sourceURL: sourceURL,
                        songId: songId,
                        format: format
                    )
                    
                    // Extract audio metadata to return
                    let _ = try self.audioFileManager.extractAudioMetadata(from: destinationURL)
                    
                    // Update progress
                    self.uploadStatusSubject.send(.uploading(songId: songId, progress: 0.8))
                    
                    // Small delay to ensure file operations are complete
                    Thread.sleep(forTimeInterval: 0.1)
                    
                    // Final success
                    self.uploadStatusSubject.send(.completed(songId: songId, fileURL: destinationURL))
                    promise(.success(destinationURL))
                } catch {
                    // Convert to our custom error type if needed
                    let storageError = (error as? FileStorageError) ?? FileStorageError.failedToSaveFile(error.localizedDescription)
                    
                    // Update status to failed
                    self.uploadStatusSubject.send(.failed(songId: songId, error: storageError))
                    promise(.failure(storageError))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// Download a song file (for future implementation with remote storage)
    func downloadSongFile(songId: String, format: AudioFormat) -> AnyPublisher<URL, Error> {
        return Future<URL, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(FileStorageError.invalidFileURL))
                return
            }
            
            do {
                // In local-only mode, this just retrieves the file URL
                let fileURL = try self.audioFileManager.getSongAudioFile(songId: songId, format: format)
                promise(.success(fileURL))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    /// Get song file metadata
    func getSongFileMetadata(songId: String, format: AudioFormat) -> AnyPublisher<(TimeInterval, Int64), Error> {
        return Future<(TimeInterval, Int64), Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(FileStorageError.invalidFileURL))
                return
            }
            
            do {
                // First check if the file exists
                guard self.audioFileManager.songAudioFileExists(songId: songId, format: format) else {
                    promise(.failure(FileStorageError.fileNotFound))
                    return
                }
                
                // Get the file URL
                let fileURL = try self.audioFileManager.getSongAudioFile(songId: songId, format: format)
                
                // Extract metadata
                let (duration, fileSize) = try self.audioFileManager.extractAudioMetadata(from: fileURL)
                
                promise(.success((duration, fileSize)))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    /// Delete a song file
    func deleteSongFile(songId: String, format: AudioFormat) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(FileStorageError.invalidFileURL))
                return
            }
            
            do {
                // Delete the file
                try self.audioFileManager.deleteSongAudioFile(songId: songId, format: format)
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - URL Persistence
    
    /// Persist a fileURL to a string representation
    func persistFileURL(_ fileURL: URL?) -> String? {
        guard let url = fileURL else { return nil }
        return audioFileManager.persistableURLString(from: url)
    }
    
    /// Restore a URL from its persisted string representation
    func restoreFileURL(from persistedURL: String?) -> URL? {
        guard let urlString = persistedURL else { return nil }
        return audioFileManager.resolvePersistedURLString(urlString)
    }
    
    // MARK: - Validation
    
    /// Validate all song files to ensure they exist
    func validateSongFiles(songs: [Song]) -> [String: Bool] {
        var validationResults = [String: Bool]()
        
        for song in songs {
            let exists = audioFileManager.songAudioFileExists(songId: song.id, format: song.format)
            validationResults[song.id] = exists
        }
        
        return validationResults
    }
}

// MARK: - File Upload Status

enum FileUploadStatus {
    case uploading(songId: String, progress: Double)
    case completed(songId: String, fileURL: URL)
    case failed(songId: String, error: Error)
} 