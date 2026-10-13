import Testing
@testable import CountryData

struct CountryMapperTests {
    @Test func mapsCountryResponseToDomainModel() {
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
}
