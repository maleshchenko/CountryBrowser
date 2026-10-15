import CountryData
import Foundation
import Observation

@MainActor
@Observable
public final class CountryDetailViewModel {
    public enum State: Equatable {
        case loading
        case loaded(Country)
        case failed(String)
    }

    public private(set) var state: State = .loading

    @ObservationIgnored private let country: Country
    @ObservationIgnored private let repository: any CountryRepository

    public init(country: Country, repository: any CountryRepository) {
        self.country = country
        self.repository = repository
        state = .loaded(country)
    }

    public func refresh() async {
        state = .loading
        do {
            guard let country = try await repository.country(withCode: country.code) else {
                state = .failed(String(localized: "country.error.notFound", bundle: .module))
                return
            }
            state = .loaded(country)
        } catch {
            state = .failed(String(localized: "country.error.load", bundle: .module))
        }
    }
}
