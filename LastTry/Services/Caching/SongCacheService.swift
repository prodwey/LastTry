import Foundation
import Combine

/// Service for caching song metadata
class SongCacheService {
    /// Singleton instance
    static let shared = SongCacheService()
    
    /// Reference to the cache manager
    private let cacheManager = CacheManager.shared
    
    /// Reference to the audio cache service
    private let audioCacheService = AudioCacheService.shared
    
    /// Subscription cancellables
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Private initializer for singleton
    }
    
    /// Cache a song by ID
    func cacheSong(_ song: Song) {
        cacheManager.songCache.setValue(song, forKey: song.id)
    }
    
    /// Cache multiple songs at once
    func cacheSongs(_ songs: [Song]) {
        for song in songs {
            cacheSong(song)
        }
    }
    
    /// Get a cached song by ID
    func getCachedSong(id: String) -> Song? {
        return cacheManager.songCache.getValue(forKey: id)
    }
    
    /// Remove a song from cache
    func removeCachedSong(id: String) {
        cacheManager.songCache.removeValue(forKey: id)
    }
    
    /// Check if a song is cached by ID
    func isSongCached(id: String) -> Bool {
        return getCachedSong(id: id) != nil
    }
    
    /// Prefetch a list of songs to optimize future access
    /// This also optionally prefetches audio data for improved playback performance
    func prefetchSongs(_ songs: [Song], prefetchAudio: Bool = false, audioLimit: Int = 3) {
        // Cache song metadata
        cacheSongs(songs)
        
        // Optionally prefetch audio data for the first few songs
        if prefetchAudio && !songs.isEmpty {
            let songsToCache = songs.prefix(audioLimit)
            audioCacheService.prefetchAudio(for: Array(songsToCache))
        }
    }
    
    /// Get songs by IDs, trying cache first then falling back to provided loader
    /// - Parameters:
    ///   - ids: Array of song IDs to fetch
    ///   - loader: Function to load songs that aren't cached
    ///   - updateCache: Whether to update the cache with loaded songs
    /// - Returns: Publisher that emits the fetched songs
    func getSongsByIds(
        ids: [String],
        loader: @escaping ([String]) -> AnyPublisher<[Song], Error>,
        updateCache: Bool = true
    ) -> AnyPublisher<[Song], Error> {
        // Check which songs are cached
        var cachedSongs: [Song] = []
        var uncachedIds: [String] = []
        
        for id in ids {
            if let cachedSong = getCachedSong(id: id) {
                cachedSongs.append(cachedSong)
            } else {
                uncachedIds.append(id)
            }
        }
        
        // If all songs are cached, return immediately
        if uncachedIds.isEmpty {
            return Just(cachedSongs)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Load uncached songs
        return loader(uncachedIds)
            .map { loadedSongs -> [Song] in
                // Update cache if requested
                if updateCache {
                    self.cacheSongs(loadedSongs)
                }
                
                // Combine cached and loaded songs
                return cachedSongs + loadedSongs
            }
            .eraseToAnyPublisher()
    }
    
    /// Get songs for a session, using cache when possible
    func getSongsForSession(
        sessionId: String,
        loader: @escaping (String) -> AnyPublisher<[Song], Error>
    ) -> AnyPublisher<[Song], Error> {
        return loader(sessionId)
            .map { [weak self] songs in
                // Cache the loaded songs
                self?.cacheSongs(songs)
                return songs
            }
            .eraseToAnyPublisher()
    }
} 