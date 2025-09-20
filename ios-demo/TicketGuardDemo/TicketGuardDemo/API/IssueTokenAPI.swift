import Foundation

protocol IssueTokenAPIProtocol {
    func issueToken(ticketId: String, deviceId: String, ttl: Int?) async throws -> IssueTokenResponse
}

final class IssueTokenAPI: IssueTokenAPIProtocol {
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func issueToken(ticketId: String, deviceId: String, ttl: Int?) async throws -> IssueTokenResponse {
        var components = URLComponents(url: AppConfig.baseURL.appendingPathComponent(AppConfig.issueTokenPath), resolvingAgainstBaseURL: false)
        if let key = AppConfig.functionKey, !key.isEmpty {
            components?.queryItems = [URLQueryItem(name: "code", value: key)]
        }
        guard let url = components?.url else { throw APIError.badURL }

        let payload = IssueTokenRequest(ticketId: ticketId, deviceId: deviceId, ttl: ttl)
        let body = try encoder.encode(payload)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 10

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.other("Non-HTTP response")
            }
            guard (200..<300).contains(http.statusCode) else {
                let bodyText = String(data: data, encoding: .utf8) ?? ""
                throw APIError.invalidStatus(code: http.statusCode, body: bodyText)
            }
            do {
                return try decoder.decode(IssueTokenResponse.self, from: data)
            } catch {
                throw APIError.decoding(error)
            }
        } catch {
            throw APIError.network(error)
        }
    }
}
