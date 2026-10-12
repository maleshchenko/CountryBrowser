import Foundation

public struct CountryResponse: Sendable {
    public let code: String
    public let name: String
    public let flag: String
    public let capital: String?
    public let currencies: [String]
    public let continentCode: String
    public let continentName: String
    public let languages: [CountryLanguageResponse]

    public init(
        code: String,
        name: String,
        flag: String,
        capital: String?,
        currencies: [String],
        continentCode: String,
        continentName: String,
        languages: [CountryLanguageResponse]
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

public struct CountryLanguageResponse: Sendable {
    public let code: String
    public let name: String

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

public enum CountryMapper {
    public static func map(_ response: CountryResponse) -> Country {
        Country(
            code: response.code,
            name: response.name,
            flag: response.flag,
            capital: response.capital,
            currencies: response.currencies,
            continentCode: response.continentCode,
            continentName: response.continentName,
            languages: response.languages.map {
                CountryLanguage(code: $0.code, name: $0.name)
            }
        )
    }
}
