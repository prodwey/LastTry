import Foundation
import Combine

/// Transaction states for file operations
enum TransactionState: String, Codable {
    case started
    case fileOperationCompleted
    case databaseOperationCompleted
    case completed
    case rolledBack
    case failed
}

/// Transaction record for recovery purposes
struct TransactionRecord: Codable, Identifiable {
    /// Unique identifier for the transaction
    let id: String
    
    /// Type of operation being performed
    let operation: String
    
    /// Resource identifier (like songId)
    let resourceId: String
    
    /// Date when transaction started
    let timestamp: Date
    
    /// Current state of the transaction
    var state: TransactionState
    
    /// Source path (for file operations)
    var sourcePath: String?
    
    /// Destination path (for file operations)
    var destinationPath: String?
    
    /// Error message if transaction failed
    var errorMessage: String?
    
    /// Additional metadata as JSON string
    var metadata: String?
}

/// Manager for transaction journaling to support recovery from interrupted operations
class TransactionJournal {
    // Singleton instance
    static let shared = TransactionJournal()
    
    // Publisher for transaction status
    private let transactionStatusSubject = PassthroughSubject<TransactionRecord, Never>()
    var transactionStatus: AnyPublisher<TransactionRecord, Never> {
        return transactionStatusSubject.eraseToAnyPublisher()
    }
    
    // Active transactions
    private var activeTransactions: [String: TransactionRecord] = [:]
    
    // URL for the journal file
    private let journalURL: URL
    
    // File manager
    private let fileManager = FileManager.default
    
    // Private initializer for singleton
    private init() {
        // Get the documents directory
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Create journal directory
        let journalDirectory = documentsDirectory.appendingPathComponent("LastTry/Journal", isDirectory: true)
        
        // Ensure directory exists
        try? fileManager.createDirectory(at: journalDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Set journal file URL
        journalURL = journalDirectory.appendingPathComponent("transaction_journal.json")
        
        // Load any existing transactions
        loadJournal()
        
        // Check for and recover any incomplete transactions
        recoverIncompleteTransactions()
        
        // Set up notification observers for database operations
        setupNotificationObservers()
        
        print("TransactionJournal initialized at: \(journalURL.path)")
    }
    
    // Set up observers for database operation notifications
    private func setupNotificationObservers() {
        // Database operation started
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DatabaseOperationStarted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let resourceId = userInfo["resourceId"] as? String,
                  let operation = userInfo["operation"] as? String else {
                return
            }
            
            // Find any existing transaction for this resource
            if let existingTransaction = self.activeTransactions.values.first(where: { 
                $0.resourceId == resourceId && 
                ($0.state == .started || $0.state == .fileOperationCompleted)
            }) {
                // Update the existing transaction to show database operation has started
                self.updateTransaction(id: existingTransaction.id, state: .databaseOperationCompleted)
            } else if let transactionId = userInfo["transactionId"] as? String,
                     self.activeTransactions[transactionId] != nil {
                // Update the specific transaction if its ID was provided
                self.updateTransaction(id: transactionId, state: .databaseOperationCompleted)
            }
        }
        
        // Database operation completed
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DatabaseOperationCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let success = userInfo["success"] as? Bool,
                  success else {
                return
            }
            
            // Handle successful completion
            if let resourceId = userInfo["resourceId"] as? String,
               let operation = userInfo["operation"] as? String {
                // Find transaction for this resource
                if let existingTransaction = self.activeTransactions.values.first(where: { 
                    $0.resourceId == resourceId && $0.operation == operation
                }) {
                    // Complete the transaction
                    self.completeTransaction(id: existingTransaction.id)
                }
            } else if let transactionId = userInfo["transactionId"] as? String {
                // Complete the specific transaction if its ID was provided
                self.completeTransaction(id: transactionId)
            }
        }
        
        // Database operation failed
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DatabaseOperationFailed"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let errorMessage = userInfo["error"] as? String else {
                return
            }
            
            // Handle failure
            if let resourceId = userInfo["resourceId"] as? String,
               let operation = userInfo["operation"] as? String {
                // Find transaction for this resource
                if let existingTransaction = self.activeTransactions.values.first(where: { 
                    $0.resourceId == resourceId && $0.operation == operation
                }) {
                    // Mark the transaction as failed
                    self.failTransaction(id: existingTransaction.id, errorMessage: errorMessage)
                }
            } else if let transactionId = userInfo["transactionId"] as? String {
                // Mark the specific transaction as failed if its ID was provided
                self.failTransaction(id: transactionId, errorMessage: errorMessage)
            }
        }
    }
    
    deinit {
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Transaction Management
    
    /// Start a new transaction
    func beginTransaction(operation: String, resourceId: String, sourcePath: String? = nil, destinationPath: String? = nil, metadata: String? = nil) -> String {
        let transactionId = UUID().uuidString
        
        let transaction = TransactionRecord(
            id: transactionId,
            operation: operation,
            resourceId: resourceId,
            timestamp: Date(),
            state: .started,
            sourcePath: sourcePath,
            destinationPath: destinationPath,
            errorMessage: nil,
            metadata: metadata
        )
        
        // Add to active transactions
        activeTransactions[transactionId] = transaction
        
        // Save to journal
        saveJournal()
        
        // Publish update
        transactionStatusSubject.send(transaction)
        
        return transactionId
    }
    
    /// Update transaction state
    func updateTransaction(id: String, state: TransactionState, errorMessage: String? = nil) {
        guard var transaction = activeTransactions[id] else {
            print("Warning: Attempted to update non-existent transaction \(id)")
            return
        }
        
        // Update state
        transaction.state = state
        
        // Update error message if provided
        if let errorMessage = errorMessage {
            transaction.errorMessage = errorMessage
        }
        
        // Update in dictionary
        activeTransactions[id] = transaction
        
        // Save to journal
        saveJournal()
        
        // Publish update
        transactionStatusSubject.send(transaction)
        
        // Remove completed or failed transactions
        if state == .completed || state == .rolledBack {
            activeTransactions.removeValue(forKey: id)
            saveJournal()
        }
    }
    
    /// Complete a transaction successfully
    func completeTransaction(id: String) {
        updateTransaction(id: id, state: .completed)
    }
    
    /// Mark a transaction as failed
    func failTransaction(id: String, errorMessage: String) {
        updateTransaction(id: id, state: .failed, errorMessage: errorMessage)
    }
    
    // MARK: - Journal Persistence
    
    /// Save the transaction journal to disk
    private func saveJournal() {
        do {
            let data = try JSONEncoder().encode(Array(activeTransactions.values))
            try data.write(to: journalURL, options: .atomicWrite)
        } catch {
            print("Error saving transaction journal: \(error.localizedDescription)")
        }
    }
    
    /// Load the transaction journal from disk
    private func loadJournal() {
        guard fileManager.fileExists(atPath: journalURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: journalURL)
            let transactions = try JSONDecoder().decode([TransactionRecord].self, from: data)
            
            // Convert to dictionary
            activeTransactions = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })
        } catch {
            print("Error loading transaction journal: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Recovery
    
    /// Recover any incomplete transactions
    private func recoverIncompleteTransactions() {
        // Filter for incomplete transactions
        let incompleteTransactions = activeTransactions.values.filter { 
            $0.state != .completed && $0.state != .rolledBack 
        }
        
        for transaction in incompleteTransactions {
            // Process based on the transaction type and state
            if transaction.operation == "uploadSong" {
                recoverSongUpload(transaction)
            } else if transaction.operation == "deleteSong" {
                recoverSongDeletion(transaction)
            }
            // Add other operation types as needed
        }
    }
    
    /// Recover an interrupted song upload
    private func recoverSongUpload(_ transaction: TransactionRecord) {
        print("Recovering interrupted song upload: \(transaction.id)")
        
        if transaction.state == .fileOperationCompleted {
            // If file was saved but database update failed, we need to retry the database operation
            
            // For now, we'll mark it as failed so user can retry
            // In a real implementation, we might try to complete the database operation
            updateTransaction(id: transaction.id, state: .failed, errorMessage: "Upload was interrupted. Please try again.")
        } else if transaction.state == .started {
            // If we only started the transaction but didn't complete file operation
            // we should clean up any partial files and mark as failed
            
            if let destPath = transaction.destinationPath, FileManager.default.fileExists(atPath: destPath) {
                try? FileManager.default.removeItem(atPath: destPath)
            }
            
            updateTransaction(id: transaction.id, state: .rolledBack, errorMessage: "Upload was interrupted and has been rolled back.")
        }
    }
    
    /// Recover an interrupted song deletion
    private func recoverSongDeletion(_ transaction: TransactionRecord) {
        print("Recovering interrupted song deletion: \(transaction.id)")
        
        if transaction.state == .fileOperationCompleted {
            // If file was deleted but database update failed, we need to retry the database operation
            
            // For now, we'll mark it as failed so user can retry
            // In a real implementation, we might try to complete the database operation
            updateTransaction(id: transaction.id, state: .failed, errorMessage: "Deletion was interrupted. Please try again.")
        } else if transaction.state == .databaseOperationCompleted {
            // If database entry was removed but file deletion failed, try to complete file deletion
            
            if let destPath = transaction.destinationPath, FileManager.default.fileExists(atPath: destPath) {
                try? FileManager.default.removeItem(atPath: destPath)
                updateTransaction(id: transaction.id, state: .completed)
            } else {
                // File is already gone, mark as completed
                updateTransaction(id: transaction.id, state: .completed)
            }
        }
    }
    
    /// Get all active transactions
    func getActiveTransactions() -> [TransactionRecord] {
        return Array(activeTransactions.values)
    }
    
    /// Clear all transactions (use with caution)
    func clearAllTransactions() {
        activeTransactions.removeAll()
        saveJournal()
    }
} 