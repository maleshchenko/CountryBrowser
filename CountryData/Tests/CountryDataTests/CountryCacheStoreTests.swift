@testable import CountryData
import Foundation
import Testing

struct CountryCacheStoreTests {
    @Test
    func persistsCountrySnapshotUsingSwiftData() async throws {
        let country = CountryFixtures.japan
        let savedAt = Date()
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "CountryCache.store")
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        var firstStore: SwiftDataCountryCacheStore? = SwiftDataCountryCacheStore(fileURL: fileURL)
        try await firstStore?.save(PersistedCountrySnapshot(countries: [country], savedAt: savedAt))
        firstStore = nil

        let reopenedStore = SwiftDataCountryCacheStore(fileURL: fileURL)
        let snapshot = try await reopenedStore.load()

        #expect(snapshot?.countries == [country])
        #expect(snapshot?.savedAt == savedAt)
    }

    @Test
    func servesPersistedCountriesAsStaleWhenRefreshFails() async throws {
        let cacheStore = SwiftDataCountryCacheStore(inMemory: true)
        try await cacheStore.save(
            PersistedCountrySnapshot(
                countries: [CountryFixtures.japan],
                savedAt: Date().addingTimeInterval(-3600)
            )
        )
        let repository = ApolloCountryRepository(
            networkTransport: MockNetworkTransport(
                responses: [],
                failure: URLError(.notConnectedToInternet)
            ),
            cacheStore: cacheStore,
            cacheLifetime: 0
        )

        let result = try await repository.countries(matching: "")

        #expect(result.countries == [CountryFixtures.japan])
        #expect(result.freshness == .stale)
    }
}
