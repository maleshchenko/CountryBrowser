import Apollo
import CountriesAPI
import Foundation

public actor ApolloCountryRepository: CountryRepository {
    private struct CountriesFetch {
        let id: UUID
        let isRefresh: Bool
        let task: Task<[Country], Error>
    }

    private let client: ApolloClient
    private let cacheLifetime: TimeInterval
    private var cachedCountries: [Country]?
    private var cachedCountriesAt: Date?
    private var inFlightCountriesFetch: CountriesFetch?

    public init(
        endpoint: URL = URL(string: "https://countries.trevorblades.com/")!,
        cacheLifetime: TimeInterval = 15 * 60
    ) {
        client = ApolloClient(url: endpoint)
        self.cacheLifetime = max(0, cacheLifetime)
    }

    public init(
        networkTransport: any NetworkTransport,
        cacheLifetime: TimeInterval = 15 * 60
    ) {
        let store = ApolloStore(cache: InMemoryNormalizedCache())
        client = ApolloClient(networkTransport: networkTransport, store: store)
        self.cacheLifetime = max(0, cacheLifetime)
    }

    public func countries(matching search: String) async throws -> [Country] {
        let search = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let countries: [Country] = if let cachedCountries, isCacheFresh {
            cachedCountries
        } else {
            try await coalescedCountries()
        }

        return countries.filter { $0.matches(search: search) }
    }

    public func refreshCountries() async throws -> [Country] {
        try await coalescedCountries(isRefresh: true)
    }

    private var isCacheFresh: Bool {
        guard let cachedCountriesAt else {
            return false
        }
        return Date() < cachedCountriesAt.addingTimeInterval(cacheLifetime)
    }

    private func coalescedCountries(isRefresh: Bool = false) async throws -> [Country] {
        let fetch: CountriesFetch = if let inFlightCountriesFetch {
            if !isRefresh || inFlightCountriesFetch.isRefresh {
                inFlightCountriesFetch
            } else {
                startCountriesFetch(isRefresh: true)
            }
        } else {
            startCountriesFetch(isRefresh: isRefresh)
        }

        do {
            let countries = try await fetch.task.value
            if inFlightCountriesFetch?.id == fetch.id {
                cachedCountries = countries
                cachedCountriesAt = Date()
                inFlightCountriesFetch = nil
            }
            return countries
        } catch {
            if inFlightCountriesFetch?.id == fetch.id {
                inFlightCountriesFetch = nil
            }
            throw error
        }
    }

    private func startCountriesFetch(isRefresh: Bool) -> CountriesFetch {
        let fetch = CountriesFetch(
            id: UUID(),
            isRefresh: isRefresh,
            task: Task {
                try await self.fetchCountries(query: CountriesQuery()) { data in
                    data.countries.map {
                        CountryMapper.map(Self.response(from: $0.fragments.countryFields))
                    }
                }
            }
        )
        inFlightCountriesFetch = fetch
        return fetch
    }

    private func fetchCountries<Query: GraphQLQuery>(
        query: Query,
        map: @escaping (Query.Data) -> [Country]
    ) async throws -> [Country] {
        try await withCheckedThrowingContinuation { continuation in
            client.fetch(query: query) { result in
                switch result {
                case let .success(graphQLResult):
                    do {
                        try Self.throwIfNeeded(graphQLResult.errors)
                        guard let data = graphQLResult.data else {
                            throw CountryRepositoryError.missingResponse
                        }
                        continuation.resume(returning: map(data))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case let .failure(error):
                    continuation.resume(throwing: Self.mapRequestError(error))
                }
            }
        }
    }

    public func country(withCode code: String) async throws -> Country? {
        try await withCheckedThrowingContinuation { continuation in
            client.fetch(query: CountryQuery(code: code)) { result in
                switch result {
                case let .success(graphQLResult):
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
                case let .failure(error):
                    continuation.resume(throwing: Self.mapRequestError(error))
                }
            }
        }
    }

    nonisolated private static func throwIfNeeded(_ errors: [GraphQLError]?) throws {
        guard let errors, !errors.isEmpty else {
            return
        }
        throw CountryRepositoryError.graphQLErrors(errors.map(\.localizedDescription))
    }

    nonisolated private static func mapRequestError(_ error: any Error) -> CountryRepositoryError {
        if let error = error as? CountryRepositoryError {
            return error
        }
        if let error = error as? URLError {
            return .networkFailure(String(reflecting: error))
        }
        if let sessionError = error as? URLSessionClient.URLSessionClientError {
            if case let .networkError(_, _, underlying) = sessionError {
                return .networkFailure(String(reflecting: underlying))
            }
        }
        return .requestFailure(String(reflecting: error))
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
