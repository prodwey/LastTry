import Foundation

extension Artist: Equatable {
    static func == (lhs: Artist, rhs: Artist) -> Bool {
        return lhs.id == rhs.id
    }
} 