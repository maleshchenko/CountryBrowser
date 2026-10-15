@testable import CountryData
import Testing

struct CountryMapperTests {
    @Test
    func mapsCountryResponseToDomainModel() {
        let response = CountryResponse(
            code: "JP",
            name: "Japan",
            flag: "🇯🇵",
            capital: "Tokyo",
            currencies: ["JPY"],
            continentCode: "AS",
            continentName: "Asia",
            languages: [CountryLanguageResponse(code: "ja", name: "Japanese")]
        )

        let country = CountryMapper.map(response)

        #expect(country.id == "JP")
        #expect(country.name == "Japan")
        #expect(country.flag == "🇯🇵")
        #expect(country.capital == "Tokyo")
        #expect(country.currencies == ["JPY"])
        #expect(country.continentName == "Asia")
        #expect(country.languages == [CountryLanguage(code: "ja", name: "Japanese")])
    }

    @Test
    func matchesCountryNamesCaseInsensitivelyAndBySubstring() {
        let country = Country(
            code: "JP",
            name: "Japan",
            flag: "🇯🇵",
            capital: "Tokyo",
            currencies: ["JPY"],
            continentCode: "AS",
            continentName: "Asia",
            languages: []
        )

        #expect(country.matches(search: "jap"))
        #expect(country.matches(search: "  JAPAN  "))
        #expect(country.matches(search: ""))
        #expect(!country.matches(search: "canada"))
    }
}
