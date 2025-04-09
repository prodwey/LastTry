import Foundation
import AVFoundation
import Combine

/// Service for caching and retrieving audio data
class AudioCacheService {
    /// Singleton instance
    static let shared = AudioCacheService()
    
    /// Reference to the cache manager
    private let cacheManager = CacheManager.shared
    
    /// Reference to the file manager
    private let fileManager = FileManager.default
    
    /// A dictionary to track ongoing cache operations to prevent duplicate work
    private var ongoingCacheOperations: [String: AnyCancellable] = [:]
    
    /// Lock for thread-safe access to ongoingCacheOperations
    private let lock = NSLock()
    
    /// Maximum number of bytes to read at once when caching large files
    private let maxChunkSize = 1 * 1024 * 1024 // 1MB
    
    private init() {
        // Private initializer for singleton
    }
    
    /// Check if audio data is cached for a specific song
    func isAudioCached(for song: Song) -> Bool {
        guard let fileURL = song.fileURL else { return false }
        return isAudioCached(for: fileURL)
    }
    
    /// Check if audio data is cached for a specific URL
    func isAudioCached(for url: URL) -> Bool {
        let cacheKey = cacheKeyForURL(url)
        return cacheManager.audioDataCache.getValue(forKey: cacheKey) != nil
    }
    
    /// Get cached audio data for a song
    func getCachedAudioData(for song: Song) -> Data? {
        guard let fileURL = song.fileURL else { return nil }
        return getCachedAudioData(for: fileURL)
    }
    
    /// Get cached audio data for a URL
    func getCachedAudioData(for url: URL) -> Data? {
        let cacheKey = cacheKeyForURL(url)
        return cacheManager.audioDataCache.getValue(forKey: cacheKey)
    }
    
    /// Cache audio data for a song
    /// Returns a publisher that emits the cached data when complete
    @discardableResult
    func cacheAudioData(for song: Song) -> AnyPublisher<Data, Error>? {
        guard let fileURL = song.fileURL else {
            return Fail(error: NSError(domain: "AudioCacheService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Song has no URL"]))
                .eraseToAnyPublisher()
        }
        
        return cacheAudioData(for: fileURL)
    }
    
    /// Cache audio data for a URL
    /// Returns a publisher that emits the cached data when complete
    @discardableResult
    func cacheAudioData(for url: URL) -> AnyPublisher<Data, Error>? {
        let cacheKey = cacheKeyForURL(url)
        
        // Check if already cached
        if let cachedData = cacheManager.audioDataCache.getValue(forKey: cacheKey) {
            return Just(cachedData)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Check if caching operation is already in progress
        lock.lock()
        if ongoingCacheOperations[cacheKey] != nil {
            lock.unlock()
            // Return nil to indicate we're already caching this item
            return nil
        }
        lock.unlock()
        
        // Create publisher for async caching operation
        let publisher = Future<Data, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "AudioCacheService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"])))
                return
            }
            
            // For local files, read from disk
            if url.isFileURL {
                self.cacheLocalFile(url: url, cacheKey: cacheKey, promise: promise)
            } else {
                // For remote URLs, download the file
                self.cacheRemoteFile(url: url, cacheKey: cacheKey, promise: promise)
            }
        }
        .eraseToAnyPublisher()
        
        // Store the operation
        lock.lock()
        let cancellable = publisher.sink(
            receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                // Remove from ongoing operations when complete
                self.lock.lock()
                self.ongoingCacheOperations.removeValue(forKey: cacheKey)
                self.lock.unlock()
            },
            receiveValue: { _ in }
        )
        ongoingCacheOperations[cacheKey] = cancellable
        lock.unlock()
        
        return publisher
    }
    
    /// Remove cached audio data for a song
    func removeCachedAudio(for song: Song) {
        guard let fileURL = song.fileURL else { return }
        removeCachedAudio(for: fileURL)
    }
    
    /// Remove cached audio data for a URL
    func removeCachedAudio(for url: URL) {
        let cacheKey = cacheKeyForURL(url)
        cacheManager.audioDataCache.removeValue(forKey: cacheKey)
    }
    
    /// Generate AVAudioPlayer for a song, preferring cached data if available
    func audioPlayer(for song: Song) throws -> AVAudioPlayer {
        guard let fileURL = song.fileURL else {
            throw NSError(domain: "AudioCacheService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Song has no URL"])
        }
        
        // Check cache first
        if let cachedData = getCachedAudioData(for: song) {
            return try AVAudioPlayer(data: cachedData)
        }
        
        // Fallback to direct file access
        if fileURL.isFileURL {
            // Start caching in the background
            _ = cacheAudioData(for: song)
            
            // Return player directly from file
            return try AVAudioPlayer(contentsOf: fileURL)
        } else {
            throw NSError(domain: "AudioCacheService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot play uncached remote URL"])
        }
    }
    
    /// Prefetch audio for songs that might be played soon
    func prefetchAudio(for songs: [Song], priority: DispatchQoS.QoSClass = .utility) {
        DispatchQueue.global(qos: priority).async {
            for song in songs {
                guard let fileURL = song.fileURL, fileURL.isFileURL else { continue }
                
                // Skip if already cached or being cached
                let cacheKey = self.cacheKeyForURL(fileURL)
                
                self.lock.lock()
                let isBeingCached = self.ongoingCacheOperations[cacheKey] != nil
                self.lock.unlock()
                
                if self.isAudioCached(for: fileURL) || isBeingCached {
                    continue
                }
                
                // Start caching
                _ = self.cacheAudioData(for: song)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Generate a cache key for a URL
    private func cacheKeyForURL(_ url: URL) -> String {
        return url.absoluteString
    }
    
    /// Cache a local file
    private func cacheLocalFile(url: URL, cacheKey: String, promise: @escaping (Result<Data, Error>) -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else {
                promise(.failure(NSError(domain: "AudioCacheService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"])))
                return
            }
            
            do {
                // Check if this is a small file or a large file
                let attributes = try self.fileManager.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int ?? 0
                
                // For small files, read all at once
                if fileSize <= self.maxChunkSize {
                    let data = try Data(contentsOf: url)
                    self.cacheManager.audioDataCache.setValue(data, forKey: cacheKey)
                    promise(.success(data))
                    return
                }
                
                // For large files, read in chunks
                let fileHandle = try FileHandle(forReadingFrom: url)
                var audioData = Data()
                
                // Reserve capacity if possible to avoid frequent reallocations
                audioData.reserveCapacity(fileSize)
                
                while true {
                    // Read a chunk of data
                    let chunk = fileHandle.readData(ofLength: self.maxChunkSize)
                    
                    // Break if no more data
                    if chunk.isEmpty {
                        break
                    }
                    
                    // Append to our data
                    audioData.append(chunk)
                }
                
                // Close file
                try fileHandle.close()
                
                // Store in cache
                self.cacheManager.audioDataCache.setValue(audioData, forKey: cacheKey)
                promise(.success(audioData))
            } catch {
                promise(.failure(error))
            }
        }
    }
    
    /// Cache a remote file
    private func cacheRemoteFile(url: URL, cacheKey: String, promise: @escaping (Result<Data, Error>) -> Void) {
        // Create a URLSession data task to download the file
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else {
                promise(.failure(NSError(domain: "AudioCacheService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"])))
                return
            }
            
            if let error = error {
                promise(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                promise(.failure(NSError(domain: "AudioCacheService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                return
            }
            
            guard let data = data else {
                promise(.failure(NSError(domain: "AudioCacheService", code: 5, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Store in cache
            self.cacheManager.audioDataCache.setValue(data, forKey: cacheKey)
            promise(.success(data))
        }
        
        // Start the download
        task.resume()
    }
} 