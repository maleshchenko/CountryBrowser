import Foundation

public struct CountryListResult: Equatable, Sendable {
    public enum Freshness: Equatable, Sendable {
        case fresh
        case stale
    }

    public let countries: [Country]
    public let freshness: Freshness

    public init(countries: [Country], freshness: Freshness) {
        self.countries = countries
        self.freshness = freshness
    }
}
