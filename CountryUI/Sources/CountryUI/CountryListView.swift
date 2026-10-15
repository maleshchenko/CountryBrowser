import CountryData
import SwiftUI

struct CountryListView: View {
    @Environment(\.countryRepository)
    private var repository
    @State private var viewModel: CountryListViewModel?
    @Binding private var selection: String?
    private let onSelectCountry: (Country?) -> Void

    init(
        selection: Binding<String?>,
        onSelectCountry: @escaping (Country?) -> Void
    ) {
        _selection = selection
        self.onSelectCountry = onSelectCountry
    }

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView {
                    Text("countries.loading", bundle: .module)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel?.isShowingStaleData == true {
                Text("countries.stale.notice", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
        }
        .navigationTitle(Text("countries.title", bundle: .module))
        .searchable(
            text: Binding(
                get: { viewModel?.searchText ?? "" },
                set: { viewModel?.updateSearch($0) }
            ),
            prompt: Text("countries.search.prompt", bundle: .module)
        )
        .task {
            guard viewModel == nil else {
                return
            }
            let model = CountryListViewModel(repository: repository)
            viewModel = model
            await model.load()
        }
    }

    @ViewBuilder
    private func content(for viewModel: CountryListViewModel) -> some View {
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
            .countryUnavailableStyle()
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
