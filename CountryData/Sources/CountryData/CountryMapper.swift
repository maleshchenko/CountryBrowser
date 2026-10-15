import Foundation

struct CountryResponse: Sendable {
    let code: String
    let name: String
    let flag: String
    let capital: String?
    let currencies: [String]
    let continentCode: String
    let continentName: String
    let languages: [CountryLanguageResponse]
}

struct CountryLanguageResponse: Sendable {
    let code: String
    let name: String
}

enum CountryMapper {
    static func map(_ response: CountryResponse) -> Country {
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
