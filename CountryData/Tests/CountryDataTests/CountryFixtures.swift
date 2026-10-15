@testable import CountryData

enum CountryFixtures {
    static let japan = Country(
        code: "JP",
        name: "Japan",
        flag: "🇯🇵",
        capital: "Tokyo",
        currencies: ["JPY"],
        continentCode: "AS",
        continentName: "Asia",
        languages: [CountryLanguage(code: "ja", name: "Japanese")]
    )
}
