import CountryData
import Foundation
import Testing
@testable import CountryUI

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
        case .countries(let countries):
            countries.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
        case .failure:
            throw URLError(.notConnectedToInternet)
        }
    }

    func country(withCode code: String) async throws -> Country? {
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

    @Test func loadsCountriesSuccessfully() async {
        let viewModel = CountryListViewModel(
            repository: MockCountryRepository(result: .countries([japan]))
        )

        await viewModel.load()

        #expect(viewModel.state == .loaded([japan]))
    }

    @Test func reportsEmptyResults() async {
        let viewModel = CountryListViewModel(
            repository: MockCountryRepository(result: .countries([]))
        )

        await viewModel.load()

        #expect(viewModel.state == .empty)
    }

    @Test func reportsNetworkFailure() async {
        let viewModel = CountryListViewModel(
            repository: MockCountryRepository(result: .failure)
        )

        await viewModel.load()

        if case .failed(let message) = viewModel.state {
            #expect(!message.isEmpty)
        } else {
            Issue.record("Expected the network error state.")
        }
    }
}
