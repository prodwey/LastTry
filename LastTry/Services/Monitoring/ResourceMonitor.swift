import Foundation
import Combine
import UIKit

/// Threshold levels for resource monitoring
enum ResourceThreshold {
    case normal
    case warning
    case critical
}

/// Resource type being monitored
enum ResourceType {
    case memory
    case disk
}

/// Notification sent when resource thresholds are crossed
struct ResourceNotification {
    let type: ResourceType
    let threshold: ResourceThreshold
    let usagePercentage: Double
    let timestamp: Date
}

/// Service for monitoring system resources and responding to low-resource situations
class ResourceMonitor {
    /// Singleton instance
    static let shared = ResourceMonitor()
    
    /// Publisher for resource notifications
    private let resourceSubject = PassthroughSubject<ResourceNotification, Never>()
    var resourcePublisher: AnyPublisher<ResourceNotification, Never> {
        return resourceSubject.eraseToAnyPublisher()
    }
    
    /// Warning threshold percentages
    private let memoryWarningThreshold: Double = 75.0  // 75% memory usage is a warning
    private let memoryErrorThreshold: Double = 85.0    // 85% memory usage is critical
    private let diskWarningThreshold: Double = 90.0    // 90% disk usage is a warning
    private let diskErrorThreshold: Double = 95.0      // 95% disk usage is critical
    
    /// Current resource status
    private var currentMemoryStatus: ResourceThreshold = .normal
    private var currentDiskStatus: ResourceThreshold = .normal
    
    /// Timer for periodic checks
    private var monitorTimer: Timer?
    
    /// Initialize the monitor
    private init() {
        // Start monitoring on init
        startMonitoring()
        
        // Register for memory warnings from the system
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Start periodic resource monitoring
    func startMonitoring(interval: TimeInterval = 30.0) {
        stopMonitoring()
        
        // Create a repeating timer to check resources
        monitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkResources()
        }
        
        // Run an initial check
        checkResources()
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
    
    /// Check system resources manually
    func checkResources() {
        checkMemoryUsage()
        checkDiskSpace()
    }
    
    /// Respond to memory pressure
    @objc private func didReceiveMemoryWarning() {
        // When we get a system memory warning, immediately clear caches
        clearCaches()
        
        // Notify listeners
        resourceSubject.send(ResourceNotification(
            type: .memory,
            threshold: .critical,
            usagePercentage: 90.0, // Assume high since we got a warning
            timestamp: Date()
        ))
    }
    
    /// Check available memory
    private func checkMemoryUsage() {
        let memoryUsage = getMemoryUsage()
        var newStatus: ResourceThreshold = .normal
        
        // Determine threshold
        if memoryUsage >= memoryErrorThreshold {
            newStatus = .critical
        } else if memoryUsage >= memoryWarningThreshold {
            newStatus = .warning
        }
        
        // Only notify on status changes
        if newStatus != currentMemoryStatus {
            currentMemoryStatus = newStatus
            
            resourceSubject.send(ResourceNotification(
                type: .memory,
                threshold: newStatus,
                usagePercentage: memoryUsage,
                timestamp: Date()
            ))
            
            // Take automatic action for critical situations
            if newStatus == .critical {
                clearCaches()
            }
        }
    }
    
    /// Check available disk space
    private func checkDiskSpace() {
        let diskUsage = getDiskUsage()
        var newStatus: ResourceThreshold = .normal
        
        // Determine threshold
        if diskUsage >= diskErrorThreshold {
            newStatus = .critical
        } else if diskUsage >= diskWarningThreshold {
            newStatus = .warning
        }
        
        // Only notify on status changes
        if newStatus != currentDiskStatus {
            currentDiskStatus = newStatus
            
            resourceSubject.send(ResourceNotification(
                type: .disk,
                threshold: newStatus,
                usagePercentage: diskUsage,
                timestamp: Date()
            ))
            
            // Take automatic action for critical situations
            if newStatus == .critical {
                clearCaches()
            }
        }
    }
    
    /// Get current memory usage as percentage
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size)
            let physicalMemory = Double(ProcessInfo.processInfo.physicalMemory)
            return (usedMemory / physicalMemory) * 100.0
        }
        
        return 0.0
    }
    
    /// Get current disk usage as percentage
    private func getDiskUsage() -> Double {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            
            if let freeSize = systemAttributes[.systemFreeSize] as? NSNumber,
               let totalSize = systemAttributes[.systemSize] as? NSNumber {
                
                let usedSpace = totalSize.doubleValue - freeSize.doubleValue
                return (usedSpace / totalSize.doubleValue) * 100.0
            }
        } catch {
            print("Error getting disk usage: \(error.localizedDescription)")
        }
        
        return 0.0
    }
    
    /// Clear caches in response to resource pressure
    private func clearCaches() {
        // Clear all audio data caches
        CacheManager.shared.audioDataCache.clearCache()
        
        // Keep song metadata cache since it's small but very useful
        
        // Clear image cache
        CacheManager.shared.imageCache.clearCache()
        
        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()
        
        // Suggest garbage collection
        #if DEBUG
        print("ResourceMonitor: Cleared caches due to resource pressure")
        #endif
    }
    
    /// Get current resource status
    var memoryStatus: ResourceThreshold {
        return currentMemoryStatus
    }
    
    var diskStatus: ResourceThreshold {
        return currentDiskStatus
    }
} 