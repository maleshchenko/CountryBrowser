import Foundation

public protocol CountryRepository: Sendable {
    func countries(matching search: String) async throws -> [Country]
    func country(withCode code: String) async throws -> Country?
}

public enum CountryRepositoryError: Error, LocalizedError, Sendable {
    case missingResponse
    case graphQLErrors([String])

    public var errorDescription: String? {
        switch self {
        case .missingResponse:
            "The server returned no country data."
        case .graphQLErrors(let messages):
            messages.joined(separator: "\n")
        }
    }
}
