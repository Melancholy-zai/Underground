import Foundation

/// Keeps delayed completion/cancellation events scoped to the request that created them.
public struct RequestGate {
    private var active: UUID?
    public init() {}
    @discardableResult public mutating func begin() -> UUID {
        let token = UUID(); active = token; return token
    }
    public func accepts(_ token: UUID) -> Bool { active == token }
    @discardableResult public mutating func finish(_ token: UUID) -> Bool {
        guard accepts(token) else { return false }
        active = nil; return true
    }
    public mutating func cancel() { active = nil }
}
