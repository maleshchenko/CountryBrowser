import CountryData
@testable import CountryUI
import Foundation
import Testing

private actor MockCountryRepository: CountryRepository {
    private let countries: [Country]
    private let detailCountry: Country?
    private var shouldFail: Bool
    private let repositoryError: CountryRepositoryError?
    private let searchDelay: Duration
    private let freshness: CountryListResult.Freshness
    private var searchRequests: [String] = []
    private var refreshRequestCount = 0
    private var detailRequests: [String] = []

    init(
        countries: [Country] = [],
        detailCountry: Country? = nil,
        shouldFail: Bool = false,
        repositoryError: CountryRepositoryError? = nil,
        searchDelay: Duration = .zero,
        freshness: CountryListResult.Freshness = .fresh
    ) {
        self.countries = countries
        self.detailCountry = detailCountry
        self.shouldFail = shouldFail
        self.repositoryError = repositoryError
        self.searchDelay = searchDelay
        self.freshness = freshness
    }

    func countries(matching search: String) async throws -> CountryListResult {
        searchRequests.append(search)
        if searchDelay > .zero {
            try await Task.sleep(for: searchDelay)
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

@MainActor
struct CountryListViewModelTests {
    private let japan = Country(
        code: "JP",
        name: "Japan",
        flag: "🇯🇵",
        capital: "Tokyo",
        currencies: ["JPY"],
        continentCode: "AS",
        continentName: "Asia",
        languages: []
    )

    private let canada = Country(
        code: "CA",
        name: "Canada",
        flag: "🇨🇦",
        capital: "Ottawa",
        currencies: ["CAD"],
        continentCode: "NA",
        continentName: "North America",
        languages: []
    )

    @Test
    func loadsCountriesSuccessfully() async {
        let viewModel = CountryListViewModel(
            repository: MockCountryRepository(countries: [japan])
        )

        await viewModel.load()

        #expect(viewModel.state == .loaded([japan]))
        #expect(!viewModel.isShowingStaleData)
    }

    @Test
    func exposesStaleListData() async {
        let viewModel = CountryListViewModel(
            repository: MockCountryRepository(countries: [japan], freshness: .stale)
        )

        await viewModel.load()

        #expect(viewModel.state == .loaded([japan]))
        #expect(viewModel.isShowingStaleData)
    }

    @Test
    func clearsStaleIndicatorAfterLoadFailure() async {
        let repository = MockCountryRepository(countries: [japan], freshness: .stale)
        let viewModel = CountryListViewModel(repository: repository)
        await viewModel.load()

        await repository.setShouldFail(true)
        await viewModel.load(matching: "unavailable")

        #expect(!viewModel.isShowingStaleData)
    }

    @Test
    func reportsEmptyResults() async {
        let viewModel = CountryListViewModel(repository: MockCountryRepository())

        await viewModel.load()

        #expect(viewModel.state == .empty)
    }

    @Test
    func reportsNetworkFailure() async {
        let viewModel = CountryListViewModel(
            repository: MockCountryRepository(shouldFail: true)
        )

        await viewModel.load()

        if case let .failed(message) = viewModel.state {
            #expect(!message.isEmpty)
        } else {
            Issue.record("Expected the network error state.")
        }
    }

    @Test
    func presentsGraphQLErrorWithoutExposingServerDetails() async {
        let viewModel = CountryListViewModel(
            repository: MockCountryRepository(
                repositoryError: .graphQLErrors(["sensitive server diagnostic"])
            )
        )

        await viewModel.load()

        if case let .failed(message) = viewModel.state {
            #expect(message == "The country service returned an error.")
            #expect(!message.contains("sensitive server diagnostic"))
        } else {
            Issue.record("Expected the GraphQL error state.")
        }
    }

    @Test
    func presentsMissingDataError() async {
        let viewModel = CountryListViewModel(
            repository: MockCountryRepository(repositoryError: .missingResponse)
        )

        await viewModel.load()

        if case let .failed(message) = viewModel.state {
            #expect(message == "The country service returned no data.")
        } else {
            Issue.record("Expected the missing-data error state.")
        }
    }

    @Test
    func debouncesSearchBeforeRequestingResults() async throws {
        let repository = MockCountryRepository(countries: [japan, canada])
        let viewModel = CountryListViewModel(repository: repository)

        viewModel.updateSearch("jap")
        try await Task.sleep(for: .milliseconds(150))

        #expect(await repository.recordedSearchRequests().isEmpty)

        try await Task.sleep(for: .milliseconds(400))

        #expect(await repository.recordedSearchRequests() == ["jap"])
        #expect(viewModel.state == .loaded([japan]))
    }

    @Test
    func rapidSearchUpdatesOnlyRequestTheLatestTerm() async throws {
        let repository = MockCountryRepository(countries: [japan, canada])
        let viewModel = CountryListViewModel(repository: repository)

        viewModel.updateSearch("j")
        try await Task.sleep(for: .milliseconds(50))
        viewModel.updateSearch("ja")
        try await Task.sleep(for: .milliseconds(50))
        viewModel.updateSearch("jap")
        try await Task.sleep(for: .milliseconds(450))

        #expect(await repository.recordedSearchRequests() == ["jap"])
        #expect(viewModel.state == .loaded([japan]))
    }

    @Test
    func keepsCurrentCountriesVisibleWhileSearchLoads() async throws {
        let repository = MockCountryRepository(
            countries: [japan, canada],
            searchDelay: .milliseconds(200)
        )
        let viewModel = CountryListViewModel(repository: repository)
        await viewModel.load()

        let searchTask = Task {
            await viewModel.load(matching: "can")
        }
        for _ in 0 ..< 50 {
            if await repository.recordedSearchRequests().count == 2 {
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(await repository.recordedSearchRequests() == ["", "can"])
        #expect(viewModel.state == .loaded([japan, canada]))

        await searchTask.value

        #expect(viewModel.state == .loaded([canada]))
    }

    @Test
    func refreshesCountriesUsingCurrentSearch() async throws {
        let repository = MockCountryRepository(countries: [japan, canada])
        let viewModel = CountryListViewModel(repository: repository)
        viewModel.updateSearch("can")
        try await Task.sleep(for: .milliseconds(400))

        await viewModel.refresh()

        #expect(await repository.numberOfRefreshRequests() == 1)
        #expect(await repository.recordedSearchRequests() == ["can"])
        #expect(viewModel.state == .loaded([canada]))
    }

    @Test
    func reportsRefreshFailure() async {
        let viewModel = CountryListViewModel(
            repository: MockCountryRepository(shouldFail: true)
        )

        await viewModel.refresh()

        if case let .failed(message) = viewModel.state {
            #expect(!message.isEmpty)
        } else {
            Issue.record("Expected the refresh error state.")
        }
    }
}

@MainActor
struct CountryDetailViewModelTests {
    private let japan = Country(
        code: "JP",
        name: "Japan",
        flag: "🇯🇵",
        capital: "Tokyo",
        currencies: ["JPY"],
        continentCode: "AS",
        continentName: "Asia",
        languages: []
    )

    @Test
    func loadsCountryDetails() async {
        let repository = MockCountryRepository()
        let viewModel = CountryDetailViewModel(country: japan, repository: repository)

        #expect(viewModel.state == .loaded(japan))
        #expect(await repository.recordedDetailRequests().isEmpty)
    }

    @Test
    func refreshesCountryDetails() async {
        let refreshedJapan = Country(
            code: "JP",
            name: "Japan",
            flag: "🇯🇵",
            capital: "Kyoto",
            currencies: ["JPY"],
            continentCode: "AS",
            continentName: "Asia",
            languages: []
        )
        let repository = MockCountryRepository(detailCountry: refreshedJapan)
        let viewModel = CountryDetailViewModel(country: japan, repository: repository)

        await viewModel.refresh()

        #expect(viewModel.state == .loaded(refreshedJapan))
        #expect(await repository.recordedDetailRequests() == ["JP"])
    }

    @Test
    func reportsDetailNetworkFailure() async {
        let repository = MockCountryRepository(shouldFail: true)
        let viewModel = CountryDetailViewModel(country: japan, repository: repository)

        await viewModel.refresh()

        if case let .failed(message) = viewModel.state {
            #expect(!message.isEmpty)
        } else {
            Issue.record("Expected the detail network error state.")
        }
        #expect(await repository.recordedDetailRequests() == ["JP"])
    }

    @Test
    func presentsDetailGraphQLErrorWithoutExposingServerDetails() async {
        let repository = MockCountryRepository(
            repositoryError: .graphQLErrors(["sensitive server diagnostic"])
        )
        let viewModel = CountryDetailViewModel(country: japan, repository: repository)

        await viewModel.refresh()

        if case let .failed(message) = viewModel.state {
            #expect(message == "The country service returned an error for these details.")
            #expect(!message.contains("sensitive server diagnostic"))
        } else {
            Issue.record("Expected the GraphQL error state.")
        }
    }

    @Test
    func presentsDetailMissingDataError() async {
        let repository = MockCountryRepository(repositoryError: .missingResponse)
        let viewModel = CountryDetailViewModel(country: japan, repository: repository)

        await viewModel.refresh()

        if case let .failed(message) = viewModel.state {
            #expect(message == "The country service returned no details.")
        } else {
            Issue.record("Expected the missing-data error state.")
        }
    }

    @Test
    func reportsMissingCountryDetails() async {
        let repository = MockCountryRepository()
        let viewModel = CountryDetailViewModel(country: japan, repository: repository)

        await viewModel.refresh()

        if case let .failed(message) = viewModel.state {
            #expect(!message.isEmpty)
        } else {
            Issue.record("Expected the missing country error state.")
        }
    }
}
