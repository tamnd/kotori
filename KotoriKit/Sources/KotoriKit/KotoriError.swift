import Foundation

/// Which data plane a request went through.
public enum Plane: String, Sendable, Codable {
    /// No account: guest token GraphQL or syndication CDN.
    case anonymous
    /// The user's own cookie session.
    case session
}

/// Every failure the wire layer can surface. Views switch on this, never on URLError.
public enum KotoriError: Error, Sendable {
    case transport(underlying: String)
    case decode(operation: String, detail: String)
    case walled(plane: Plane)
    case rateLimited(reset: Date?)
    case notFound
    case suspended
    case protected
    case challenge

    public var isRetryableLater: Bool {
        switch self {
        case .rateLimited, .transport: true
        default: false
        }
    }
}
