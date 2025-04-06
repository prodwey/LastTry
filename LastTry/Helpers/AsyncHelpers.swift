import Foundation

/**
 * Helper functions for working with Swift concurrency.
 * These functions help to avoid naming conflicts with the app's Task model.
 */

/**
 * Runs an asynchronous operation.
 * This is a wrapper around _Concurrency.Task to avoid naming conflicts with the app's Task model.
 *
 * Usage:
 * ```
 * runAsync {
 *     let result = await someAsyncOperation()
 *     // Process result
 * }
 * ```
 *
 * @param work The asynchronous operation to run
 * @return The created task (usually can be ignored)
 */
@discardableResult
func runAsync(_ work: @escaping () async -> Void) -> _Concurrency.Task<Void, Never> {
    _Concurrency.Task { await work() }
}

/**
 * Runs an asynchronous operation on the main actor (UI thread).
 * This is a convenience function for updating UI after async operations.
 *
 * Usage:
 * ```
 * await runOnMainActor {
 *     // Update UI here
 * }
 * ```
 *
 * @param work The operation to run on the main actor
 */
@MainActor
func runOnMainActor(_ work: @escaping () -> Void) async {
    work()
} 