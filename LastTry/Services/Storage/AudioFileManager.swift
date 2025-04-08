import Foundation
import AVFoundation

// MARK: - Audio File Reference Manager

class AudioFileManager {
    
    // Singleton instance
    static let shared = AudioFileManager()
    
    // Reference to file storage service
    private let storageService: FileStorageServiceProtocol
    
    // Private initializer for singleton
    private init(storageService: FileStorageServiceProtocol = LocalFileStorageService.shared) {
        self.storageService = storageService
        print("AudioFileManager initialized")
    }
    
    // MARK: - File Reference Generation
    
    /// Generates a unique filename for a song
    func generateSongFileName(songId: String, format: AudioFormat) -> String {
        return "song_\(songId).\(format.fileExtension)"
    }
    
    /// Creates a consistent filename for a song based on ID and format
    func createSongFileName(songId: String, format: AudioFormat) -> String {
        return "song_\(songId).\(format.fileExtension)"
    }
    
    /// Gets the file URL for a song
    func getSongFileURL(songId: String, format: AudioFormat) -> URL {
        let fileName = createSongFileName(songId: songId, format: format)
        return storageService.createFileURL(for: fileName)
    }
    
    // MARK: - Audio Operations
    
    /// Save an audio file for a song
    func saveSongAudioFile(sourceURL: URL, songId: String, format: AudioFormat) throws -> URL {
        let fileName = createSongFileName(songId: songId, format: format)
        return try storageService.saveAudioFile(at: sourceURL, withName: fileName, format: format)
    }
    
    /// Get an audio file for a song
    func getSongAudioFile(songId: String, format: AudioFormat) throws -> URL {
        let fileName = createSongFileName(songId: songId, format: format)
        return try storageService.getFile(named: fileName)
    }
    
    /// Delete an audio file for a song
    func deleteSongAudioFile(songId: String, format: AudioFormat) throws {
        let fileName = createSongFileName(songId: songId, format: format)
        try storageService.deleteFile(named: fileName)
    }
    
    /// Check if a song audio file exists
    func songAudioFileExists(songId: String, format: AudioFormat) -> Bool {
        let fileName = createSongFileName(songId: songId, format: format)
        return storageService.fileExists(named: fileName)
    }
    
    // MARK: - Audio File Metadata
    
    /// Get metadata for a song audio file
    func getSongAudioMetadata(songId: String, format: AudioFormat) throws -> (FileMetadata, AVAudioFormat?) {
        let fileName = createSongFileName(songId: songId, format: format)
        
        guard storageService.fileExists(named: fileName) else {
            throw FileStorageError.fileNotFound
        }
        
        let fileURL = try storageService.getFile(named: fileName)
        let fileMetadata = try storageService.getMetadata(for: fileURL)
        
        // Try to get audio-specific metadata
        var audioFormat: AVAudioFormat? = nil
        do {
            if let file = try? AVAudioFile(forReading: fileURL) {
                audioFormat = file.processingFormat
            }
        }
        
        return (fileMetadata, audioFormat)
    }
    
    // MARK: - Audio Duration and Processing
    
    /// Get duration of a song audio file
    func getSongAudioDuration(songId: String, format: AudioFormat) throws -> TimeInterval {
        let fileName = createSongFileName(songId: songId, format: format)
        
        guard storageService.fileExists(named: fileName) else {
            throw FileStorageError.fileNotFound
        }
        
        let fileURL = try storageService.getFile(named: fileName)
        
        // Get the duration using AVAudioPlayer
        guard let audioPlayer = try? AVAudioPlayer(contentsOf: fileURL) else {
            throw FileStorageError.failedToLoadFile("Could not initialize audio player for file")
        }
        
        return audioPlayer.duration
    }
    
    /// Extract audio metadata like duration, size, etc.
    func extractAudioMetadata(from url: URL) throws -> (TimeInterval, Int64) {
        guard url.isFileURL else {
            throw FileStorageError.invalidFileURL
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileStorageError.fileNotFound
        }
        
        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        // Get audio duration
        guard let audioPlayer = try? AVAudioPlayer(contentsOf: url) else {
            throw FileStorageError.failedToLoadFile("Could not initialize audio player for file")
        }
        
        return (audioPlayer.duration, fileSize)
    }
    
    // MARK: - URL Persistence Helpers
    
    /// Convert a file URL to a bookmark for persistence
    func createBookmarkFromURL(_ url: URL) -> Data? {
        do {
            let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            return bookmark
        } catch {
            print("Error creating bookmark: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Resolve a bookmark back to a URL
    func resolveBookmark(_ bookmarkData: Data) -> URL? {
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("Warning: Bookmark is stale, URL might be invalid")
            }
            
            return url
        } catch {
            print("Error resolving bookmark: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Convert a URL to a string for persistence
    func persistableURLString(from url: URL) -> String? {
        // For file URLs in our app's storage, we can use a relative path for persistence
        if url.path.contains(LocalFileStorageService.shared.createFileURL(for: "").path) {
            // Only store the filename if it's in our storage
            return url.lastPathComponent
        } else {
            // For external URLs, store the complete URL
            return url.absoluteString
        }
    }
    
    /// Resolve a persisted URL string back to a URL
    func resolvePersistedURLString(_ urlString: String) -> URL? {
        // Check if this is just a filename (no scheme)
        if !urlString.contains("://") {
            // Assume it's a file in our storage
            return LocalFileStorageService.shared.createFileURL(for: urlString)
        } else {
            // It's a complete URL
            return URL(string: urlString)
        }
    }
} 