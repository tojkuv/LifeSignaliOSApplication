import Foundation

/// Extensions for Array to provide additional functionality
extension Array {
    /// Partitions an array into two arrays based on a predicate
    /// - Parameter belongsInFirstPartition: A closure that takes an element of the array and returns a Boolean value indicating whether the element should be in the first partition
    /// - Returns: A tuple of two arrays, the first containing elements for which the predicate returns true, and the second containing elements for which the predicate returns false
    func partitioned(by belongsInFirstPartition: (Element) throws -> Bool) rethrows -> ([Element], [Element]) {
        var first: [Element] = []
        var second: [Element] = []
        for element in self {
            if try belongsInFirstPartition(element) {
                first.append(element)
            } else {
                second.append(element)
            }
        }
        return (first, second)
    }

    /// Safe subscript for arrays that returns nil if the index is out of bounds
    /// - Parameter index: The index to access
    /// - Returns: The element at the index, or nil if the index is out of bounds
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
