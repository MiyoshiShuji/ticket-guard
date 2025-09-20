import Foundation

struct IssueTokenRequest: Encodable {
    let ticketId: String
    let deviceId: String
    let ttl: Int?
}

struct IssueTokenResponse: Decodable {
    let ticketId: String
    let deviceId: String
    let startAtEpochSec: Int
    let ttlSec: Int
    let nonce: String
    let sig: String
}

enum APIError: Error, LocalizedError {
    case badURL
    case invalidStatus(code: Int, body: String)
    case decoding(Error)
    case network(Error)
    case other(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid URL"
        case .invalidStatus(let code, let body): return "HTTP \(code) – \(body)"
        case .decoding(let e): return "Decoding error: \(e)"
        case .network(let e): return "Network error: \(e.localizedDescription)"
        case .other(let msg): return msg
        }
    }
}
