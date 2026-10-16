import Apollo
import CountriesAPI
import Foundation

/// The generated list query has no mutable state, Apollo iOS 1.x omits Sendable annotations.
extension CountriesQuery: @retroactive @unchecked Sendable {}

public actor ApolloCountryRepository: CountryRepository {
    public static let defaultCacheLifetime: TimeInterval = 15 * 60
    
    private struct CountriesFetch {
        let id: UUID
        let isRefresh: Bool
        let task: Task<[Country], Error>
    }

    private let client: ApolloClient
    private let cacheLifetime: TimeInterval
    private let countryCache: CountrySnapshotCache
    private var cachedCountries: [Country]?
    private var cachedCountriesAt: Date?
    private var inFlightCountriesFetch: CountriesFetch?

    public init(cacheLifetime: TimeInterval = ApolloCountryRepository.defaultCacheLifetime) {
        client = ApolloClient(url: CountryAPIConfiguration.endpoint)
        self.cacheLifetime = max(0, cacheLifetime)
        countryCache = CountrySnapshotCache(store: SwiftDataCountryCacheStore())
    }

    public init(endpoint: URL, cacheLifetime: TimeInterval = ApolloCountryRepository.defaultCacheLifetime) {
        client = ApolloClient(url: endpoint)
        self.cacheLifetime = max(0, cacheLifetime)
        countryCache = CountrySnapshotCache(store: SwiftDataCountryCacheStore())
    }

    public init(
        networkTransport: any NetworkTransport,
        cacheLifetime: TimeInterval = ApolloCountryRepository.defaultCacheLifetime
    ) {
        let store = ApolloStore(cache: InMemoryNormalizedCache())
        client = ApolloClient(networkTransport: networkTransport, store: store)
        self.cacheLifetime = max(0, cacheLifetime)
        countryCache = CountrySnapshotCache(store: SwiftDataCountryCacheStore(inMemory: true))
    }

    init(
        networkTransport: any NetworkTransport,
        cacheStore: any CountryCacheStore,
        cacheLifetime: TimeInterval = ApolloCountryRepository.defaultCacheLifetime
    ) {
        let store = ApolloStore(cache: InMemoryNormalizedCache())
        client = ApolloClient(networkTransport: networkTransport, store: store)
        self.cacheLifetime = max(0, cacheLifetime)
        countryCache = CountrySnapshotCache(store: cacheStore)
    }

    public func countries(matching search: String) async throws -> CountryListResult {
        await loadPersistedCacheIfNeeded()
        let search = search.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let result: CountryListResult = if let cachedCountries, isCacheFresh {
                CountryListResult(countries: cachedCountries, freshness: .fresh)
            } else {
                try await coalescedCountries()
            }
            return filtered(result, matching: search)
        } catch {
            guard let cachedCountries else {
                throw error
            }
            await countryCache.logFallback(error, isRefresh: false)
            return filtered(
                CountryListResult(countries: cachedCountries, freshness: .stale),
                matching: search
            )
        }
    }

    public func refreshCountries() async throws -> CountryListResult {
        await loadPersistedCacheIfNeeded()
        do {
            return try await coalescedCountries(isRefresh: true)
        } catch {
            guard let cachedCountries else {
                throw error
            }
            await countryCache.logFallback(error, isRefresh: true)
            return CountryListResult(countries: cachedCountries, freshness: .stale)
        }
    }

    private func filtered(
        _ result: CountryListResult,
        matching search: String
    ) -> CountryListResult {
        CountryListResult(
            countries: result.countries.filter { $0.matches(search: search) },
            freshness: result.freshness
        )
    }

    private func loadPersistedCacheIfNeeded() async {
        if let snapshot = await countryCache.load(), cachedCountries == nil {
            cachedCountries = snapshot.countries
            cachedCountriesAt = snapshot.savedAt
        }
    }

    private var isCacheFresh: Bool {
        guard let cachedCountriesAt else {
            return false
        }
        return Date() < cachedCountriesAt.addingTimeInterval(cacheLifetime)
    }

    private func coalescedCountries(isRefresh: Bool = false) async throws -> CountryListResult {
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
                let savedAt = Date()
                cachedCountriesAt = savedAt
                inFlightCountriesFetch = nil
                await countryCache.save(
                    PersistedCountrySnapshot(countries: countries, savedAt: savedAt)
                )
            }
            return CountryListResult(countries: countries, freshness: .fresh)
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

    private func fetchCountries<Query: GraphQLQuery & Sendable>(
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
