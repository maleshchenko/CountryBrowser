import CountryData
import SwiftUI

struct CountryListView: View {
    @State private var viewModel: CountryListViewModel
    @Binding private var selection: String?
    private let onSelectCountry: (Country?) -> Void

    init(
        viewModel: CountryListViewModel,
        selection: Binding<String?>,
        onSelectCountry: @escaping (Country?) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        _selection = selection
        self.onSelectCountry = onSelectCountry
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView {
                    Text("countries.loading", bundle: .module)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                ContentUnavailableView {
                    Label {
                        Text("countries.empty.title", bundle: .module)
                    } icon: {
                        Image(systemName: "magnifyingglass")
                    }
                } description: {
                    Text("countries.empty.description", bundle: .module)
                }
            case let .failed(message):
                ContentUnavailableView {
                    Label {
                        Text("countries.unavailable.title", bundle: .module)
                    } icon: {
                        Image(systemName: "wifi.exclamationmark")
                    }
                } description: {
                    Text(message)
                } actions: {
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Text("action.retry", bundle: .module)
                    }
                }
            case let .loaded(countries):
                List(selection: Binding(
                    get: { selection },
                    set: { newSelection in
                        selection = newSelection
                        onSelectCountry(countries.first { $0.code == newSelection })
                    }
                )) {
                    ForEach(countries) { country in
                        NavigationLink(value: country.code) {
                            CountryRow(country: country)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
        .navigationTitle(Text("countries.title", bundle: .module))
        .searchable(
            text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.updateSearch($0) }
            ),
            prompt: Text("countries.search.prompt", bundle: .module)
        )
        .task {
            if case .idle = viewModel.state {
                await viewModel.load()
            }
        }
    }
}

private struct CountryRow: View {
    let country: Country

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(country.flag)
                .font(.title2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(country.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(country.continentName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}
