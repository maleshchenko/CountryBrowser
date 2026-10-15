import CountryData
import Foundation
import Observation

@MainActor
@Observable
final class CountryDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded(Country)
        case failed(String)
    }

    private(set) var state: State = .loading

    @ObservationIgnored private let country: Country
    @ObservationIgnored private let repository: any CountryRepository

    init(country: Country, repository: any CountryRepository) {
        self.country = country
        self.repository = repository
        state = .loaded(country)
    }

    func refresh() async {
        state = .loading
        do {
            guard let country = try await repository.country(withCode: country.code) else {
                state = .failed(String(localized: "country.error.notFound", bundle: .module))
                return
            }
            state = .loaded(country)
        } catch is CancellationError {
            return
        } catch {
            state = .failed(CountryErrorPresentation.message(for: error, context: .country))
        }
    }
}
