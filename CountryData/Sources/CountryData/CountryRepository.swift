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
            String(localized: "country.error.missingResponse", bundle: .module)
        case .graphQLErrors:
            String(localized: "country.error.graphQL", bundle: .module)
        }
    }
}
