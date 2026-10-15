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

        #expect(country == CountryFixtures.japan)
    }

    @Test
    func matchesCountryNamesCaseInsensitivelyAndBySubstring() {
        let country = CountryFixtures.japan

        #expect(country.matches(search: "jap"))
        #expect(country.matches(search: "  JAPAN  "))
        #expect(country.matches(search: ""))
        #expect(!country.matches(search: "canada"))
    }
}
