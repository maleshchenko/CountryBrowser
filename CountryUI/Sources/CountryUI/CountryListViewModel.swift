import Combine
import CountryData
import Foundation
import Observation

@MainActor
@Observable
final class CountryListViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded([Country])
        case empty
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var searchText = ""
    private(set) var isShowingStaleData = false

    @ObservationIgnored private let repository: any CountryRepository
    @ObservationIgnored private let searchInput = PassthroughSubject<String, Never>()
    @ObservationIgnored private var searchSubscription: AnyCancellable?
    @ObservationIgnored private var activeRequest = UUID()

    init(repository: any CountryRepository) {
        self.repository = repository
        searchSubscription = searchInput
            .removeDuplicates()
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .sink { [weak self] search in
                Task { @MainActor [weak self] in
                    await self?.load(matching: search)
                }
            }
    }

    func updateSearch(_ text: String) {
        searchText = text
        searchInput.send(text)
    }

    func load() async {
        await load(matching: searchText)
    }

    func load(matching search: String) async {
        let request = UUID()
        activeRequest = request
        switch state {
        case .loaded:
            break
        default:
            state = .loading
        }
        do {
            let result = try await repository.countries(matching: search)
            guard activeRequest == request else {
                return
            }
            isShowingStaleData = result.freshness == .stale
            state = result.countries.isEmpty ? .empty : .loaded(result.countries)
        } catch is CancellationError {
            return
        } catch {
            guard activeRequest == request else {
                return
            }
            isShowingStaleData = false
            state = .failed(CountryErrorPresentation.message(for: error, context: .countries))
        }
    }

    func refresh() async {
        let request = UUID()
        activeRequest = request
        do {
            let result = try await repository.refreshCountries()
            guard activeRequest == request else {
                return
            }
            let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let filteredCountries = result.countries.filter { $0.matches(search: search) }
            isShowingStaleData = result.freshness == .stale
            state = filteredCountries.isEmpty ? .empty : .loaded(filteredCountries)
        } catch is CancellationError {
            return
        } catch {
            guard activeRequest == request else {
                return
            }
            isShowingStaleData = false
            state = .failed(CountryErrorPresentation.message(for: error, context: .countries))
        }
    }
}
