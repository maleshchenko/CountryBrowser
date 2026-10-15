import CountryData
import SwiftUI

public struct CountriesRootView: View {
    private let repository: any CountryRepository
    @State private var viewModel: CountryListViewModel
    @State private var selectedCountryCode: String?

    public init(repository: any CountryRepository) {
        self.repository = repository
        _viewModel = State(initialValue: CountryListViewModel(repository: repository))
    }

    public var body: some View {
        NavigationSplitView {
            CountryListView(
                viewModel: viewModel,
                repository: repository,
                selection: $selectedCountryCode
            )
            .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 420)
        } detail: {
            if let selectedCountryCode {
                CountryDetailView(
                    viewModel: CountryDetailViewModel(
                        countryCode: selectedCountryCode,
                        repository: repository
                    )
                )
                .id(selectedCountryCode)
            } else {
                ContentUnavailableView(
                    "country.selection.prompt",
                    systemImage: "globe.americas",
                    description: Text("country.selection.description", bundle: .module)
                )
            }
        }
    }
}
