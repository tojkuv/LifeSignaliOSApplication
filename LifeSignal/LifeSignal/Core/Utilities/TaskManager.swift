import Foundation

/// Task manager for handling async tasks
/// This utility class helps prevent memory leaks by properly tracking and cancelling tasks
final class TaskManager {
    private var tasks = Set<AnyHashable>()
    private let lock = NSLock()
    
    /// Add a task to the manager
    /// - Parameter task: The task to add
    func addTask<T>(_ task: Task<T, Error>) {
        lock.lock()
        defer { lock.unlock() }
        tasks.insert(task)
    }
    
    /// Add a task to the manager
    /// - Parameter task: The task to add
    func addTask<T>(_ task: Task<T, Never>) {
        lock.lock()
        defer { lock.unlock() }
        tasks.insert(task)
    }
    
    /// Remove a task from the manager
    /// - Parameter task: The task to remove
    func removeTask<T>(_ task: Task<T, Error>) {
        lock.lock()
        defer { lock.unlock() }
        tasks.remove(task)
    }
    
    /// Remove a task from the manager
    /// - Parameter task: The task to remove
    func removeTask<T>(_ task: Task<T, Never>) {
        lock.lock()
        defer { lock.unlock() }
        tasks.remove(task)
    }
    
    /// Cancel all tasks
    func cancelAllTasks() {
        lock.lock()
        defer { lock.unlock() }
        for task in tasks {
            if let task = task as? any Cancellable {
                task.cancel()
            }
        }
        tasks.removeAll()
    }
    
    /// Clean up completed tasks
    func cleanupTasks() {
        lock.lock()
        defer { lock.unlock() }
        tasks = tasks.filter { task in
            if let task = task as? Task<Any, Error>, task.isCancelled {
                return false
            }
            if let task = task as? Task<Any, Never>, task.isCancelled {
                return false
            }
            return true
        }
    }
    
    deinit {
        cancelAllTasks()
    }
}

// Make Task conform to Cancellable
private protocol Cancellable {
    func cancel()
}

extension Task: Cancellable {}
