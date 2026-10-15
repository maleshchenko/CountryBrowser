import Combine
import CountryData
import Foundation
import Observation

@MainActor
@Observable
public final class CountryListViewModel {
    public enum State: Equatable {
        case idle
        case loading
        case loaded([Country])
        case empty
        case failed(String)
    }

    public private(set) var state: State = .idle
    public private(set) var searchText = ""
    public private(set) var isShowingStaleData = false

    @ObservationIgnored private let repository: any CountryRepository
    @ObservationIgnored private let searchInput = PassthroughSubject<String, Never>()
    @ObservationIgnored private var searchSubscription: AnyCancellable?
    @ObservationIgnored private var activeRequest = UUID()

    public init(repository: any CountryRepository) {
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

    public func updateSearch(_ text: String) {
        searchText = text
        searchInput.send(text)
    }

    public func load() async {
        await load(matching: searchText)
    }

    public func load(matching search: String) async {
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
            state = .failed(CountryErrorPresentation.message(for: error, context: .countries))
        }
    }

    public func refresh() async {
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
            state = .failed(CountryErrorPresentation.message(for: error, context: .countries))
        }
    }
}
