import Foundation
import AVFoundation
import Combine

enum AudioError: Error, LocalizedError {
    case fileNotFound
    case invalidFileFormat
    case failedToLoad(String)
    case playbackError(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Audio file not found"
        case .invalidFileFormat:
            return "Invalid audio file format"
        case .failedToLoad(let message):
            return "Failed to load audio: \(message)"
        case .playbackError(let message):
            return "Playback error: \(message)"
        }
    }
}

class AudioService: NSObject, ObservableObject, AudioServiceProtocol {
    // MARK: - Singleton
    
    /// Shared instance for global access
    static let shared = AudioService()
    
    // Public properties that the UI can observe
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentSong: Song? = nil
    
    // Publishers required by protocol
    var currentTimePublisher: AnyPublisher<TimeInterval, Never> {
        return $currentTime.eraseToAnyPublisher()
    }
    
    var isPlayingPublisher: AnyPublisher<Bool, Never> {
        return $isPlaying.eraseToAnyPublisher()
    }
    
    var currentSongPublisher: AnyPublisher<Song?, Never> {
        return $currentSong.eraseToAnyPublisher()
    }
    
    // Audio player and session
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var itemEndObserver: NSObjectProtocol?
    
    // Combine subscribers
    private var cancellables = Set<AnyCancellable>()
    
    // Error handling service
    private let errorHandlingService: ErrorHandlingServiceProtocol
    
    // MARK: - Initialization
    
    /// Private initializer for singleton pattern
    private override init() {
        self.errorHandlingService = ErrorHandlingService.shared
        super.init()
        setupAudioSession()
        setupNotifications()
        print("AudioService: Initialized shared instance")
    }
    
    /// Dependency injection initializer for testing or custom configurations
    init(errorHandlingService: ErrorHandlingServiceProtocol) {
        self.errorHandlingService = errorHandlingService
        super.init()
        setupAudioSession()
        setupNotifications()
        print("AudioService: Initialized with custom error handling service")
    }
    
    deinit {
        removePlayerObservers()
    }
    
    // MARK: - Public Methods
    
    /// Loads and starts playing a song
    func playSong(_ song: Song) throws {
        guard let fileURL = song.fileURL else {
            let error = AudioError.fileNotFound
            errorHandlingService.reportError(error)
            throw error
        }
        
        // First, stop any current playback
        stopPlayback()
        
        // Create a new player item
        let playerItem = AVPlayerItem(url: fileURL)
        
        // Create or reuse player
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        self.playerItem = playerItem
        
        // Set up observers
        setupPlayerObservers()
        
        // Start playback
        player?.play()
        isPlaying = true
        currentSong = song
        
        // Update duration when it becomes available
        // Get an initial value (might be inaccurate at first)
        #if os(iOS)
        if #available(iOS 16.0, *) {
            // Completely separated approach to avoid conflicts with decoders
            loadAssetDurationWithTask(playerItem.asset)
        } else {
            let initialDuration = playerItem.asset.duration.seconds
            if !initialDuration.isNaN && initialDuration > 0 {
                self.duration = initialDuration
            }
        }
        #else
        let initialDuration = playerItem.asset.duration.seconds
        if !initialDuration.isNaN && initialDuration > 0 {
            self.duration = initialDuration
        }
        #endif
        
        // We'll update the duration again when the item is ready to play
        // This happens through our status observer in setupPlayerObservers()
        // When the item status becomes .readyToPlay, we can get a more accurate duration
    }
    
    /// Pauses playback
    func pausePlayback() {
        player?.pause()
        isPlaying = false
    }
    
    /// Resumes playback
    func resumePlayback() {
        player?.play()
        isPlaying = true
    }
    
    /// Stops playback completely and resets
    func stopPlayback() {
        player?.pause()
        player?.seek(to: CMTime.zero)
        isPlaying = false
        currentTime = 0
        currentSong = nil
    }
    
    /// Seeks to a specific position
    func seek(to timeInSeconds: TimeInterval) {
        let time = CMTime(seconds: timeInSeconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: time) { [weak self] completed in
            if completed {
                self?.currentTime = timeInSeconds
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func setupAudioSession() {
        do {
            // Configure audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
            errorHandlingService.reportError(error)
        }
    }
    
    private func setupPlayerObservers() {
        // Remove any existing observers
        removePlayerObservers()
        
        guard let player = player else { return }
        
        // Add periodic time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
        
        // Add item status observer
        statusObserver = playerItem?.observe(\.status, options: [.new, .old]) { [weak self] item, _ in
            if item.status == .readyToPlay {
                // Get more accurate duration when item is ready to play
                #if os(iOS)
                if #available(iOS 16.0, *) {
                    // Completely separated approach to avoid conflicts with decoders
                    self?.loadAssetDurationWithTask(item.asset)
                } else {
                    let duration = item.asset.duration.seconds
                    if !duration.isNaN && duration > 0 {
                        self?.duration = duration
                    }
                }
                #else
                let duration = item.asset.duration.seconds
                if !duration.isNaN && duration > 0 {
                    self?.duration = duration
                }
                #endif
            } else if item.status == .failed {
                self?.handlePlayerError(item.error)
            }
        }
        
        // Listen for playback ended notification
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
            self?.player?.seek(to: CMTime.zero)
            self?.currentTime = 0
            
            // Notify that playback has completed
            NotificationCenter.default.post(name: .audioPlaybackDidEnd, object: nil)
        }
    }
    
    private func removePlayerObservers() {
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        statusObserver?.invalidate()
        statusObserver = nil
        
        if let itemEndObserver = itemEndObserver {
            NotificationCenter.default.removeObserver(itemEndObserver)
            self.itemEndObserver = nil
        }
    }
    
    private func setupNotifications() {
        // Handle interruptions (phone calls, Siri, etc.)
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                guard let info = notification.userInfo,
                      let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                    return
                }
                
                switch type {
                case .began:
                    self?.pausePlayback()
                    // Notify about interruption
                    NotificationCenter.default.post(name: .audioPlaybackInterrupted, object: nil)
                case .ended:
                    guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self?.resumePlayback()
                        // Notify about resumption
                        NotificationCenter.default.post(name: .audioPlaybackResumed, object: nil)
                    }
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Handle route changes (headphones connected/disconnected)
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                guard let info = notification.userInfo,
                      let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                    return
                }
                
                // Pause playback if headphones were disconnected
                if reason == .oldDeviceUnavailable {
                    self?.pausePlayback()
                    // Notify about route change
                    NotificationCenter.default.post(name: .audioRouteChanged, object: nil)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handlePlayerError(_ error: Error?) {
        isPlaying = false
        if let error = error {
            print("Playback error: \(error.localizedDescription)")
            let audioError = AudioError.playbackError(error.localizedDescription)
            errorHandlingService.reportError(audioError)
            
            // Notify about playback error
            NotificationCenter.default.post(name: .audioPlaybackError, object: audioError)
        }
    }
    
    // Safe wrapper method for handling duration loading
    private func loadAssetDurationWithTask(_ asset: AVAsset) {
        // Create a new function to contain all the processing
        func processDuration() {
            if #available(iOS 16.0, *) {
                // Use the modern, non-deprecated API on iOS 16+
                // Using detached task to avoid any syntax issues
                let handler = { [weak self] in
                    guard let self = self else { return }
                    
                    do {
                        // Load the duration using the new async API
                        let duration = try await asset.load(.duration)
                        let seconds = duration.seconds
                        
                        if seconds > 0 {
                            await MainActor.run {
                                self.duration = seconds
                            }
                        }
                    } catch {
                        print("Error loading duration with modern API: \(error.localizedDescription)")
                        errorHandlingService.reportError(AudioError.failedToLoad(error.localizedDescription))
                    }
                }
                
                // Explicitly create the task with no trailing closure
                @Sendable func asyncLoad() async {
                    await handler()
                }
                
                // Use a standard Task constructor instead of detached
                DispatchQueue.main.async {
                    // Create a task variable without using trailing closure syntax
                    @MainActor func startAsyncTask() {
                        _ = _Concurrency.Task { @MainActor in
                            await asyncLoad()
                        }
                    }
                    
                    // Call the function directly
                    startAsyncTask()
                }
            } else {
                // For iOS 15 and earlier, use the legacy API
                let semaphore = DispatchSemaphore(value: 0)
                var durationValue: CMTime = .zero
                var loadError: Error? = nil
                
                // Swift doesn't have a good way to silence deprecated warnings for
                // specific lines, so we'll need to accept the warnings here
                asset.loadValuesAsynchronously(forKeys: ["duration"]) {
                    var error: NSError? = nil
                    let status = asset.statusOfValue(forKey: "duration", error: &error)
                    
                    if status == .loaded {
                        durationValue = asset.duration
                    } else {
                        loadError = error
                    }
                    
                    semaphore.signal()
                }
                
                // Wait for operation to complete (with timeout)
                let waitResult = semaphore.wait(timeout: .now() + 5.0)
                if waitResult == .timedOut {
                    print("Warning: Timed out waiting for audio metadata")
                }
                
                // Process the results on main thread
                if let error = loadError {
                    print("Error loading duration with legacy API: \(error.localizedDescription)")
                    self.errorHandlingService.reportError(AudioError.failedToLoad(error.localizedDescription))
                } else {
                    let seconds = CMTimeGetSeconds(durationValue)
                    if seconds > 0 {
                        DispatchQueue.main.async { [weak self] in
                            self?.duration = seconds
                        }
                    }
                }
            }
        }
        
        // Call the function on a background queue
        DispatchQueue.global(qos: .userInitiated).async {
            processDuration()
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// Notification sent when audio playback has ended
    static let audioPlaybackDidEnd = Notification.Name("audioPlaybackDidEnd")
    
    /// Notification sent when audio playback was interrupted
    static let audioPlaybackInterrupted = Notification.Name("audioPlaybackInterrupted")
    
    /// Notification sent when audio playback resumed after interruption
    static let audioPlaybackResumed = Notification.Name("audioPlaybackResumed")
    
    /// Notification sent when audio route changed (e.g., headphones disconnected)
    static let audioRouteChanged = Notification.Name("audioRouteChanged")
    
    /// Notification sent when audio playback encountered an error
    static let audioPlaybackError = Notification.Name("audioPlaybackError")
}

// MARK: - Audio Manager

/// Global access to audio functionality
enum AudioManager {
    /// Access the shared audio service instance
    static var service: AudioServiceProtocol {
        return AudioService.shared
    }
    
    /// Whether audio is currently playing
    static var isPlaying: Bool {
        return service.isPlaying
    }
    
    /// Current playback time
    static var currentTime: TimeInterval {
        return service.currentTime
    }
    
    /// Total duration of the current audio
    static var duration: TimeInterval {
        return service.duration
    }
    
    /// The currently playing song, if any
    static var currentSong: Song? {
        return service.currentSong
    }
    
    /// Publisher for observing current time changes
    static var currentTimePublisher: AnyPublisher<TimeInterval, Never> {
        return service.currentTimePublisher
    }
    
    /// Publisher for observing playback state changes
    static var isPlayingPublisher: AnyPublisher<Bool, Never> {
        return service.isPlayingPublisher
    }
    
    /// Publisher for observing current song changes
    static var currentSongPublisher: AnyPublisher<Song?, Never> {
        return service.currentSongPublisher
    }
    
    /// Play a specific song
    static func playSong(_ song: Song) -> Bool {
        do {
            try service.playSong(song)
            return true
        } catch {
            // Error is already reported by the service
            return false
        }
    }
    
    /// Pause playback
    static func pausePlayback() {
        service.pausePlayback()
    }
    
    /// Resume playback
    static func resumePlayback() {
        service.resumePlayback()
    }
    
    /// Stop playback completely
    static func stopPlayback() {
        service.stopPlayback()
    }
    
    /// Seek to a specific position
    static func seek(to position: TimeInterval) {
        service.seek(to: position)
    }
} 