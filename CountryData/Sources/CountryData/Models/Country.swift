import Foundation

public struct Country: Identifiable, Hashable, Sendable {
    public let code: String
    public let name: String
    public let flag: String
    public let capital: String?
    public let currencies: [String]
    public let continentCode: String
    public let continentName: String
    public let languages: [CountryLanguage]

    public var id: String {
        code
    }

    public init(
        code: String,
        name: String,
        flag: String,
        capital: String?,
        currencies: [String],
        continentCode: String,
        continentName: String,
        languages: [CountryLanguage]
    ) {
        self.code = code
        self.name = name
        self.flag = flag
        self.capital = capital
        self.currencies = currencies
        self.continentCode = continentCode
        self.continentName = continentName
        self.languages = languages
    }
}

public struct CountryLanguage: Hashable, Sendable {
    public let code: String
    public let name: String

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}
