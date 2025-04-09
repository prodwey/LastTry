import Foundation

/// Cache entry with expiration time and value
final class CacheEntry<T> {
    let value: T
    let expirationDate: Date?
    
    init(value: T, expirationDate: Date? = nil) {
        self.value = value
        self.expirationDate = expirationDate
    }
    
    /// Check if the cache entry has expired
    var isExpired: Bool {
        guard let expirationDate = expirationDate else {
            return false // No expiration date means never expires
        }
        return Date() > expirationDate
    }
}

/// Cache policy for determining expiration of items
enum CachePolicy {
    /// Never expires
    case never
    /// Expires after a specific time interval
    case expireAfter(TimeInterval)
    /// Expires at a specific date
    case expireAt(Date)
    
    /// Generate expiration date based on policy
    func expirationDate() -> Date? {
        switch self {
        case .never:
            return nil
        case .expireAfter(let timeInterval):
            return Date().addingTimeInterval(timeInterval)
        case .expireAt(let date):
            return date
        }
    }
}

/// Protocol for cache elements to enable size calculation for cache limit enforcement
protocol CacheSizable {
    /// Size in bytes of the cached item
    var sizeInBytes: Int { get }
}

/// Default implementation for common types
extension String: CacheSizable {
    var sizeInBytes: Int {
        return self.utf8.count
    }
}

extension Data: CacheSizable {
    var sizeInBytes: Int {
        return self.count
    }
}

/// Generic cache service for in-memory caching with expiration, thread safety, and size management
class CacheService<Key: Hashable, Value> {
    /// Shared lock for thread safety
    private let lock = NSLock()
    
    /// Internal storage for cache entries
    private var cache: [Key: CacheEntry<Value>] = [:]
    
    /// Default cache policy
    private let defaultPolicy: CachePolicy
    
    /// Maximum size limit for the cache in bytes (optional)
    private let sizeLimit: Int?
    
    /// Current size of the cache in bytes (only tracked if sizeLimit is set)
    private var currentSize: Int = 0
    
    /// Initialize with optional default policy and size limit
    init(defaultPolicy: CachePolicy = .never, sizeLimit: Int? = nil) {
        self.defaultPolicy = defaultPolicy
        self.sizeLimit = sizeLimit
    }
    
    /// Set a value in the cache with optional custom policy
    func setValue(_ value: Value, forKey key: Key, policy: CachePolicy? = nil) {
        // Use custom policy or default
        let expirationDate = (policy ?? defaultPolicy).expirationDate()
        
        // Update cache safely
        lock.lock()
        defer { lock.unlock() }
        
        let entry = CacheEntry(value: value, expirationDate: expirationDate)
        
        // Track size if needed
        if let sizeLimit = sizeLimit, let value = value as? CacheSizable {
            // If replacing an existing entry, adjust size
            if let oldEntry = cache[key], let oldValue = oldEntry.value as? CacheSizable {
                currentSize -= oldValue.sizeInBytes
            }
            
            // Check if adding this value would exceed the limit
            let newSize = currentSize + value.sizeInBytes
            if newSize > sizeLimit {
                // Need to make space
                makeSpace(neededBytes: value.sizeInBytes)
            }
            
            // Update current size
            currentSize += value.sizeInBytes
        }
        
        cache[key] = entry
    }
    
    /// Retrieve a value from the cache
    func getValue(forKey key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let entry = cache[key] else {
            return nil
        }
        
        // Check if entry has expired
        if entry.isExpired {
            removeValue(forKey: key)
            return nil
        }
        
        return entry.value
    }
    
    /// Remove a value from the cache
    @discardableResult
    func removeValue(forKey key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let entry = cache.removeValue(forKey: key) else {
            return nil
        }
        
        // Update size if tracking
        if let _ = sizeLimit, let value = entry.value as? CacheSizable {
            currentSize -= value.sizeInBytes
        }
        
        return entry.value
    }
    
    /// Clear all values from the cache
    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        
        cache.removeAll()
        currentSize = 0
    }
    
    /// Remove all expired items from the cache
    func removeExpiredItems() {
        lock.lock()
        defer { lock.unlock() }
        
        let expiredKeys = cache.filter { $0.value.isExpired }.map { $0.key }
        
        for key in expiredKeys {
            removeValue(forKey: key)
        }
    }
    
    /// Get the current number of items in the cache
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }
    
    /// Make space in the cache by removing least recently used items
    private func makeSpace(neededBytes: Int) {
        // Only if we have a size limit
        guard sizeLimit != nil else { return }
        
        // First remove expired items
        removeExpiredItems()
        
        // If still need space, remove items until we have enough
        if currentSize + neededBytes > sizeLimit! {
            // Sort keys by age (we don't track usage time, so this is simplified)
            let sortedKeys = Array(cache.keys)
            
            for key in sortedKeys {
                guard currentSize + neededBytes > sizeLimit! else {
                    break
                }
                
                removeValue(forKey: key)
            }
        }
    }
}

/// Manager to provide centralized access to various caches
class CacheManager {
    /// Singleton instance
    static let shared = CacheManager()
    
    /// Cache for song metadata (id -> Song)
    let songCache: CacheService<String, Song>
    
    /// Cache for audio data (URL string -> Data)
    let audioDataCache: CacheService<String, Data>
    
    /// Cache for images (URL string -> Data)
    let imageCache: CacheService<String, Data>
    
    private init() {
        // Size limit of ~50MB for audio files
        let audioSizeLimit = 50 * 1024 * 1024
        
        // Size limit of ~10MB for images
        let imageSizeLimit = 10 * 1024 * 1024
        
        // Configure caches with appropriate policies and limits
        songCache = CacheService<String, Song>(
            defaultPolicy: .expireAfter(30 * 60), // 30 minutes
            sizeLimit: nil
        )
        
        audioDataCache = CacheService<String, Data>(
            defaultPolicy: .expireAfter(5 * 60), // 5 minutes
            sizeLimit: audioSizeLimit
        )
        
        imageCache = CacheService<String, Data>(
            defaultPolicy: .expireAfter(10 * 60), // 10 minutes
            sizeLimit: imageSizeLimit
        )
        
        // Setup periodic cleanup
        setupPeriodicCleanup()
    }
    
    /// Set up a timer to regularly clean up expired cache entries
    private func setupPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Run cleanup on a background queue
            DispatchQueue.global(qos: .utility).async {
                self.songCache.removeExpiredItems()
                self.audioDataCache.removeExpiredItems()
                self.imageCache.removeExpiredItems()
            }
        }
    }
    
    /// Clear all caches
    func clearAllCaches() {
        songCache.clearCache()
        audioDataCache.clearCache()
        imageCache.clearCache()
    }
} 