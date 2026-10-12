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
                ProgressView("Loading country…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Country unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") {
                        Task { await viewModel.load() }
                    }
                }
            case .loaded(let country):
                CountryDetails(country: country)
            }
        }
        .navigationTitle("Country")
        .task {
            if case .loading = viewModel.state {
                await viewModel.load()
            }
        }
    }
}

private struct CountryDetails: View {
    let country: Country

    private var currencies: String {
        country.currencies.isEmpty ? "Not available" : country.currencies.joined(separator: ", ")
    }

    private var languages: String {
        country.languages.isEmpty
            ? "Not available"
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

            Section("Country information") {
                LabeledContent("Capital", value: country.capital ?? "Not available")
                LabeledContent("Currency", value: currencies)
                LabeledContent("Languages", value: languages)
                LabeledContent("Continent", value: country.continentName)
            }
        }
        .listStyle(.automatic)
    }
}
