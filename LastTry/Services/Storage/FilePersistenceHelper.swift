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
    private let transactionJournal: TransactionJournal
    
    // Publisher for upload status
    private let uploadStatusSubject = PassthroughSubject<FileUploadStatus, Never>()
    var uploadStatus: AnyPublisher<FileUploadStatus, Never> {
        return uploadStatusSubject.eraseToAnyPublisher()
    }
    
    // Private initializer for singleton
    private init(
        storageService: FileStorageServiceProtocol = LocalFileStorageService.shared,
        audioFileManager: AudioFileManager = AudioFileManager.shared,
        transactionJournal: TransactionJournal = TransactionJournal.shared
    ) {
        self.storageService = storageService
        self.audioFileManager = audioFileManager
        self.transactionJournal = transactionJournal
        print("FilePersistenceHelper initialized")
        
        // Subscribe to transaction status updates
        transactionJournal.transactionStatus
            .sink { [weak self] record in
                if record.operation == "uploadSong" && record.state == .failed {
                    // Notify listeners about failed uploads
                    self?.uploadStatusSubject.send(.failed(
                        songId: record.resourceId,
                        error: FileStorageError.failedToSaveFile(record.errorMessage ?? "Unknown error")
                    ))
                }
            }
            .store(in: &cancellables)
    }
    
    // Store cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - File Upload Operations
    
    /// Upload a file for a song from a temporary URL
    /// This copies the file from its temporary location to a permanent one in the app's storage
    /// Uses transaction journaling for recovery and atomicity
    func uploadSongFile(from sourceURL: URL, songId: String, format: AudioFormat) -> AnyPublisher<URL, Error> {
        // Create a future that wraps the file operation
        return Future<URL, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(FileStorageError.invalidFileURL))
                return
            }
            
            // Determine the destination path before starting transaction
            let destinationFileName = self.audioFileManager.createSongFileName(songId: songId, format: format)
            let destinationURL = self.storageService.createFileURL(for: destinationFileName)
            
            // Begin transaction with file paths
            let transactionId = self.transactionJournal.beginTransaction(
                operation: "uploadSong",
                resourceId: songId,
                sourcePath: sourceURL.path,
                destinationPath: destinationURL.path,
                metadata: format.rawValue
            )
            
            // Update status to uploading
            self.uploadStatusSubject.send(.uploading(songId: songId, progress: 0))
            
            // Perform the upload on a background queue
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Validate the file exists
                    guard self.fileManager.fileExists(atPath: sourceURL.path) else {
                        self.transactionJournal.failTransaction(id: transactionId, errorMessage: "Source file not found")
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
                    
                    // Update transaction state to indicate file operation is complete
                    self.transactionJournal.updateTransaction(id: transactionId, state: .fileOperationCompleted)
                    
                    // Extract audio metadata to return
                    let _ = try self.audioFileManager.extractAudioMetadata(from: destinationURL)
                    
                    // Update progress
                    self.uploadStatusSubject.send(.uploading(songId: songId, progress: 0.8))
                    
                    // Small delay to ensure file operations are complete
                    Thread.sleep(forTimeInterval: 0.1)
                    
                    // Mark transaction as complete
                    self.transactionJournal.completeTransaction(id: transactionId)
                    
                    // Final success
                    self.uploadStatusSubject.send(.completed(songId: songId, fileURL: destinationURL))
                    promise(.success(destinationURL))
                } catch {
                    // Convert to our custom error type if needed
                    let storageError = (error as? FileStorageError) ?? FileStorageError.failedToSaveFile(error.localizedDescription)
                    
                    // Roll back the transaction
                    self.rollbackUpload(transactionId: transactionId, songId: songId, errorMessage: storageError.localizedDescription)
                    
                    // Update status to failed
                    self.uploadStatusSubject.send(.failed(songId: songId, error: storageError))
                    promise(.failure(storageError))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// Rollback an upload transaction if an error occurs
    private func rollbackUpload(transactionId: String, songId: String, errorMessage: String) {
        // Get the transaction record
        let transactions = transactionJournal.getActiveTransactions()
        guard let transaction = transactions.first(where: { $0.id == transactionId }) else {
            return
        }
        
        // If file was saved, try to delete it
        if transaction.state == .fileOperationCompleted, 
           let destinationPath = transaction.destinationPath,
           fileManager.fileExists(atPath: destinationPath) {
            do {
                try fileManager.removeItem(atPath: destinationPath)
            } catch {
                print("Warning: Could not delete file during rollback: \(error.localizedDescription)")
            }
        }
        
        // Mark transaction as rolled back
        transactionJournal.updateTransaction(id: transactionId, state: .rolledBack, errorMessage: errorMessage)
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
    
    /// Delete a song file with transaction safety
    func deleteSongFile(songId: String, format: AudioFormat) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(FileStorageError.invalidFileURL))
                return
            }
            
            // Check if the file exists first
            guard self.audioFileManager.songAudioFileExists(songId: songId, format: format) else {
                promise(.success(()))
                return
            }
            
            do {
                // Get the file path
                let fileURL = try self.audioFileManager.getSongAudioFile(songId: songId, format: format)
                
                // Begin transaction
                let transactionId = self.transactionJournal.beginTransaction(
                    operation: "deleteSong",
                    resourceId: songId,
                    destinationPath: fileURL.path,
                    metadata: format.rawValue
                )
                
                // Delete the file
                try self.audioFileManager.deleteSongAudioFile(songId: songId, format: format)
                
                // Update transaction state
                self.transactionJournal.updateTransaction(id: transactionId, state: .fileOperationCompleted)
                
                // Complete transaction
                self.transactionJournal.completeTransaction(id: transactionId)
                
                promise(.success(()))
            } catch {
                // If a transaction is active, mark it as failed
                let transactions = self.transactionJournal.getActiveTransactions()
                if let transaction = transactions.first(where: { 
                    $0.operation == "deleteSong" && $0.resourceId == songId 
                }) {
                    self.transactionJournal.failTransaction(
                        id: transaction.id, 
                        errorMessage: error.localizedDescription
                    )
                }
                
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