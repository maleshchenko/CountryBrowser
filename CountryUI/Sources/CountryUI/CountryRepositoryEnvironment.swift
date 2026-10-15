import CountryData
import SwiftUI

private struct UnconfiguredCountryRepository: CountryRepository {
    func countries(matching _: String) async throws -> CountryListResult {
        throw missingRepositoryError
    }

    func refreshCountries() async throws -> CountryListResult {
        throw missingRepositoryError
    }

    func country(withCode _: String) async throws -> Country? {
        throw missingRepositoryError
    }

    private var missingRepositoryError: CountryRepositoryError {
        .requestFailure("CountryRepository was not injected into the SwiftUI environment.")
    }
}

extension EnvironmentValues {
    @Entry var countryRepository: any CountryRepository = UnconfiguredCountryRepository()
}
