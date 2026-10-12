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

    @ObservationIgnored private let countryCode: String
    @ObservationIgnored private let repository: any CountryRepository

    public init(countryCode: String, repository: any CountryRepository) {
        self.countryCode = countryCode
        self.repository = repository
    }

    public func load() async {
        state = .loading
        do {
            guard let country = try await repository.country(withCode: countryCode) else {
                state = .failed("Country details could not be found.")
                return
            }
            state = .loaded(country)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
