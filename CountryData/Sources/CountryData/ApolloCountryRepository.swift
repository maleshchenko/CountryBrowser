import Apollo
import CountriesAPI
import Foundation

public actor ApolloCountryRepository: CountryRepository {
    private let client: ApolloClient

    public init(endpoint: URL = URL(string: "https://countries.trevorblades.com/")!) {
        client = ApolloClient(url: endpoint)
    }

    public func countries(matching search: String) async throws -> [Country] {
        let search = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if search.isEmpty {
            return try await fetchCountries(query: CountriesQuery()) { data in
                data.countries.map {
                    CountryMapper.map(Self.response(from: $0.fragments.countryFields))
                }
            }
        }

        let pattern = "(?i).*\\(NSRegularExpression.escapedPattern(for: search)).*"
        return try await fetchCountries(query: CountriesSearchQuery(search: pattern)) { data in
            data.countries.map {
                CountryMapper.map(Self.response(from: $0.fragments.countryFields))
            }
        }
    }

    private func fetchCountries<Query: GraphQLQuery>(
        query: Query,
        map: @escaping (Query.Data) -> [Country]
    ) async throws -> [Country] {
        return try await withCheckedThrowingContinuation { continuation in
            client.fetch(query: query) { result in
                switch result {
                case .success(let graphQLResult):
                    do {
                        try Self.throwIfNeeded(graphQLResult.errors)
                        guard let data = graphQLResult.data else {
                            throw CountryRepositoryError.missingResponse
                        }
                        continuation.resume(returning: map(data))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func country(withCode code: String) async throws -> Country? {
        try await withCheckedThrowingContinuation { continuation in
            client.fetch(query: CountryQuery(code: code)) { result in
                switch result {
                case .success(let graphQLResult):
                    do {
                        try Self.throwIfNeeded(graphQLResult.errors)
                        guard let data = graphQLResult.data else {
                            throw CountryRepositoryError.missingResponse
                        }
                        guard let country = data.country else {
                            continuation.resume(returning: nil)
                            return
                        }
                        continuation.resume(
                            returning: CountryMapper.map(
                                Self.response(from: country.fragments.countryFields)
                            )
                        )
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    nonisolated private static func throwIfNeeded(_ errors: [GraphQLError]?) throws {
        guard let errors, !errors.isEmpty else { return }
        throw CountryRepositoryError.graphQLErrors(errors.map(\.localizedDescription))
    }

    nonisolated private static func response(from fields: CountryFields) -> CountryResponse {
        CountryResponse(
            code: fields.code,
            name: fields.name,
            flag: fields.emoji,
            capital: fields.capital,
            currencies: fields.currencies,
            continentCode: fields.continent.code,
            continentName: fields.continent.name,
            languages: fields.languages.map {
                CountryLanguageResponse(code: $0.code, name: $0.name)
            }
        )
    }
}
