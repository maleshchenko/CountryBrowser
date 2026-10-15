import CountryData
@testable import CountryUI
import Foundation
import Testing

private actor MockCountryRepository: CountryRepository {
    enum Result {
        case countries([Country])
        case failure
    }

    private let result: Result

    init(result: Result) {
        self.result = result
    }

    func countries(matching search: String) async throws -> [Country] {
        switch result {
        case let .countries(countries):
            countries.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
        case .failure:
            throw URLError(.notConnectedToInternet)
        }
    }

    func country(withCode _: String) async throws -> Country? {
        nil
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

    @Test
    func loadsCountriesSuccessfully() async {
        let viewModel = CountryListViewModel(
            repository: MockCountryRepository(result: .countries([japan]))
        )

        await viewModel.load()

        #expect(viewModel.state == .loaded([japan]))
    }

    @Test
    func reportsEmptyResults() async {
        let viewModel = CountryListViewModel(
            repository: MockCountryRepository(result: .countries([]))
        )

        await viewModel.load()

        #expect(viewModel.state == .empty)
    }

    @Test
    func reportsNetworkFailure() async {
        let viewModel = CountryListViewModel(
            repository: MockCountryRepository(result: .failure)
        )

        await viewModel.load()

        if case let .failed(message) = viewModel.state {
            #expect(!message.isEmpty)
        } else {
            Issue.record("Expected the network error state.")
        }
    }
}
