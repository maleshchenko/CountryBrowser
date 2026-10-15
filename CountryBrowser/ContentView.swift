import CountryData
import CountryUI
import SwiftUI

struct ContentView: View {
    private let repository = ApolloCountryRepository()

    var body: some View {
        CountriesRootView(repository: repository)
    }
}
