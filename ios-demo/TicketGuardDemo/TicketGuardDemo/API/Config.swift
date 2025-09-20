import Foundation

// Placeholder configuration; do NOT commit real secrets.
// Later: move function key to an xcconfig excluded from git.
enum AppConfig {
    static let baseURL = URL(string: "https://example-func-app.azurewebsites.net")! // Replace with real
    static let functionKey: String? = nil // e.g. "<FUNCTION_KEY>" (avoid committing real key)
    static let issueTokenPath = "/api/issue-token"
}
