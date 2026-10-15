import Foundation

public protocol CountryRepository: Sendable {
    func countries(matching search: String) async throws -> CountryListResult
    func refreshCountries() async throws -> CountryListResult
    func country(withCode code: String) async throws -> Country?
}

public enum CountryRepositoryError: Error, LocalizedError, Sendable {
    public enum Category: String, Sendable {
        case network
        case graphQL
        case missingData
        case request
    }

    case networkFailure(String)
    case missingResponse
    case graphQLErrors([String])
    case requestFailure(String)

    public var category: Category {
        switch self {
        case .networkFailure:
            .network
        case .graphQLErrors:
            .graphQL
        case .missingResponse:
            .missingData
        case .requestFailure:
            .request
        }
    }

    var diagnosticDescription: String {
        switch self {
        case let .networkFailure(details), let .requestFailure(details):
            "\(category.rawValue): \(details)"
        case let .graphQLErrors(messages):
            "GraphQL errors: \(messages.joined(separator: "; "))"
        case .missingResponse:
            "The GraphQL response did not include data."
        }
    }

    public var errorDescription: String? {
        switch self {
        case .networkFailure:
            String(localized: "country.error.network", bundle: .module)
        case .missingResponse:
            String(localized: "country.error.missingResponse", bundle: .module)
        case .graphQLErrors:
            String(localized: "country.error.graphQL", bundle: .module)
        case .requestFailure:
            String(localized: "country.error.request", bundle: .module)
        }
    }
}
