import CountryData
@testable import CountryUI
import Foundation

actor MockCountryRepository: CountryRepository {
    private let countries: [Country]
    private let detailCountry: Country?
    private var shouldFail: Bool
    private let repositoryError: CountryRepositoryError?
    private let suspendedSearch: String?
    private let freshness: CountryListResult.Freshness
    private var searchRequests: [String] = []
    private var searchRequestWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var suspendedSearchContinuation: CheckedContinuation<Void, Never>?
    private var refreshRequestCount = 0
    private var detailRequests: [String] = []

    init(
        countries: [Country] = [],
        detailCountry: Country? = nil,
        shouldFail: Bool = false,
        repositoryError: CountryRepositoryError? = nil,
        suspendedSearch: String? = nil,
        freshness: CountryListResult.Freshness = .fresh
    ) {
        self.countries = countries
        self.detailCountry = detailCountry
        self.shouldFail = shouldFail
        self.repositoryError = repositoryError
        self.suspendedSearch = suspendedSearch
        self.freshness = freshness
    }

    func countries(matching search: String) async throws -> CountryListResult {
        searchRequests.append(search)
        let readyWaiters = searchRequestWaiters.filter { $0.0 <= searchRequests.count }
        searchRequestWaiters.removeAll { $0.0 <= searchRequests.count }
        readyWaiters.forEach { $0.1.resume() }

        if search == suspendedSearch {
            await withCheckedContinuation { suspendedSearchContinuation = $0 }
        }
        if let repositoryError {
            throw repositoryError
        }
        if shouldFail {
            throw URLError(.notConnectedToInternet)
        }
        return CountryListResult(
            countries: countries.filter { $0.matches(search: search) },
            freshness: freshness
        )
    }

    func refreshCountries() async throws -> CountryListResult {
        refreshRequestCount += 1
        if let repositoryError {
            throw repositoryError
        }
        if shouldFail {
            throw URLError(.notConnectedToInternet)
        }
        return CountryListResult(countries: countries, freshness: freshness)
    }

    func country(withCode code: String) async throws -> Country? {
        detailRequests.append(code)
        if let repositoryError {
            throw repositoryError
        }
        if shouldFail {
            throw URLError(.notConnectedToInternet)
        }
        return detailCountry?.code == code ? detailCountry : nil
    }

    func recordedSearchRequests() -> [String] {
        searchRequests
    }

    func waitForSearchRequestCount(_ count: Int) async {
        guard searchRequests.count < count else {
            return
        }
        await withCheckedContinuation { continuation in
            searchRequestWaiters.append((count, continuation))
        }
    }

    func resumeSuspendedSearch() {
        suspendedSearchContinuation?.resume()
        suspendedSearchContinuation = nil
    }

    func recordedDetailRequests() -> [String] {
        detailRequests
    }

    func numberOfRefreshRequests() -> Int {
        refreshRequestCount
    }

    func setShouldFail(_ shouldFail: Bool) {
        self.shouldFail = shouldFail
    }
}
