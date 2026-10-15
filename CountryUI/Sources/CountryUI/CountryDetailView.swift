import CountryData
import SwiftUI

struct CountryDetailView: View {
    @State private var viewModel: CountryDetailViewModel

    init(viewModel: CountryDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView {
                    Text("country.loading", bundle: .module)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(message):
                ContentUnavailableView {
                    Label {
                        Text("country.unavailable.title", bundle: .module)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                } description: {
                    Text(message)
                } actions: {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Text("action.retry", bundle: .module)
                    }
                }
            case let .loaded(country):
                CountryDetails(country: country)
                    .refreshable {
                        await viewModel.refresh()
                    }
            }
        }
        .navigationTitle(Text("country.title", bundle: .module))
    }
}

private struct CountryDetails: View {
    let country: Country

    private var currencies: String {
        country.currencies.isEmpty
            ? String(localized: "value.notAvailable", bundle: .module)
            : country.currencies.joined(separator: ", ")
    }

    private var languages: String {
        country.languages.isEmpty
            ? String(localized: "value.notAvailable", bundle: .module)
            : country.languages.map(\.name).joined(separator: ", ")
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Text(country.flag)
                        .font(.system(size: 64))
                        .accessibilityHidden(true)
                    Text(country.name)
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .listRowBackground(Color.clear)
            }

            Section {
                LabeledContent {
                    Text(country.capital ?? String(
                        localized: "value.notAvailable",
                        bundle: .module
                    ))
                } label: {
                    Text("country.capital", bundle: .module)
                }
                LabeledContent {
                    Text(currencies)
                } label: {
                    Text("country.currency", bundle: .module)
                }
                LabeledContent {
                    Text(languages)
                } label: {
                    Text("country.languages", bundle: .module)
                }
                LabeledContent {
                    Text(country.continentName)
                } label: {
                    Text("country.continent", bundle: .module)
                }
            } header: {
                Text("country.information", bundle: .module)
            }
        }
        .listStyle(.automatic)
    }
}
