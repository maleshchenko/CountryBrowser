import CountryData
import SwiftUI

public struct CountriesRootView: View {
    private let repository: any CountryRepository
    @State private var viewModel: CountryListViewModel
    @State private var selectedCountry: Country?

    public init(repository: any CountryRepository) {
        self.repository = repository
        _viewModel = State(initialValue: CountryListViewModel(repository: repository))
    }

    public var body: some View {
        NavigationSplitView {
            CountryListView(
                viewModel: viewModel,
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
                    viewModel: CountryDetailViewModel(
                        country: selectedCountry,
                        repository: repository
                    )
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
    }
}
