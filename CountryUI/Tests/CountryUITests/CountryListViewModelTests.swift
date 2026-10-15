import CountryData
@testable import CountryUI
import Foundation
import Testing

private actor MockCountryRepository: CountryRepository {
    private let countries: [Country]
    private let detailCountry: Country?
    private let shouldFail: Bool
    private var searchRequests: [String] = []
    private var detailRequests: [String] = []

    init(
        countries: [Country] = [],
        detailCountry: Country? = nil,
        shouldFail: Bool = false
    ) {
        self.countries = countries
        self.detailCountry = detailCountry
        self.shouldFail = shouldFail
    }

    func countries(matching search: String) async throws -> [Country] {
        searchRequests.append(search)
        if shouldFail {
            throw URLError(.notConnectedToInternet)
        }
        return countries.filter { $0.matches(search: search) }
    }

    func country(withCode code: String) async throws -> Country? {
        detailRequests.append(code)
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
        let repository = MockCountryRepository(detailCountry: japan)
        let viewModel = CountryDetailViewModel(countryCode: "JP", repository: repository)

        #expect(viewModel.state == .loading)
        await viewModel.load()

        #expect(viewModel.state == .loaded(japan))
        #expect(await repository.recordedDetailRequests() == ["JP"])
    }

    @Test
    func reportsDetailNetworkFailure() async {
        let repository = MockCountryRepository(shouldFail: true)
        let viewModel = CountryDetailViewModel(countryCode: "JP", repository: repository)

        await viewModel.load()

        if case let .failed(message) = viewModel.state {
            #expect(!message.isEmpty)
        } else {
            Issue.record("Expected the detail network error state.")
        }
        #expect(await repository.recordedDetailRequests() == ["JP"])
    }

    @Test
    func reportsMissingCountryDetails() async {
        let repository = MockCountryRepository()
        let viewModel = CountryDetailViewModel(countryCode: "XX", repository: repository)

        await viewModel.load()

        if case let .failed(message) = viewModel.state {
            #expect(!message.isEmpty)
        } else {
            Issue.record("Expected the missing country error state.")
        }
    }
}
