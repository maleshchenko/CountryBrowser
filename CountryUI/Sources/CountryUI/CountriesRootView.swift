import CountryData
import SwiftUI

public struct CountriesRootView: View {
    @State private var selectedCountry: Country?

    private let repository: any CountryRepository

    public init(repository: any CountryRepository) {
        self.repository = repository
    }

    public var body: some View {
        NavigationSplitView {
            CountryListView(
                selection: Binding(
                    get: { selectedCountry?.code },
                    set: { selectedCode in
                        if selectedCode == nil {
                            selectedCountry = nil
                        }
                    }
                ),
                onSelectCountry: { selectedCountry = $0 }
            )
            .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 420)
        } detail: {
            if let selectedCountry {
                CountryDetailView(
                    country: selectedCountry
                )
                .id(selectedCountry.code)
            } else {
                ContentUnavailableView {
                    Label {
                        Text("country.selection.prompt", bundle: .module)
                    } icon: {
                        Image(systemName: "globe.americas")
                    }
                } description: {
                    Text("country.selection.description", bundle: .module)
                }
            }
        }
        .environment(\.countryRepository, repository)
    }
}
