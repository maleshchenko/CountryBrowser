import CountryData
import SwiftUI

public struct CountriesRootView: View {
    private let repository: any CountryRepository
    @State private var viewModel: CountryListViewModel

    public init(repository: any CountryRepository) {
        self.repository = repository
        _viewModel = State(initialValue: CountryListViewModel(repository: repository))
    }

    public var body: some View {
        NavigationStack {
            CountryListView(viewModel: viewModel, repository: repository)
        }
    }
}
