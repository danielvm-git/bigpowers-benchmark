import Foundation

public enum PingResult: Sendable, Equatable {
    case success
    case failure(message: String)
}
