import Foundation
import OSLog
import SwiftData

struct PersistedCountrySnapshot: Sendable {
    let countries: [Country]
    let savedAt: Date
}

protocol CountryCacheStore: Sendable {
    func load() async throws -> PersistedCountrySnapshot?
    func save(_ snapshot: PersistedCountrySnapshot) async throws
}

@Model
final class CountrySnapshotRecord {
    @Attribute(.unique)
    var id: String
    var payload: Data
    var savedAt: Date

    init(id: String, payload: Data, savedAt: Date) {
        self.id = id
        self.payload = payload
        self.savedAt = savedAt
    }
}

enum CountryCacheStoreError: Error, Sendable {
    case initialization(String)
    case invalidSnapshot(String)
}

actor SwiftDataCountryCacheStore: CountryCacheStore {
    private let containerResult: Result<ModelContainer, CountryCacheStoreError>

    init(inMemory: Bool = false, fileURL: URL? = nil) {
        do {
            let fileURL = fileURL ?? Self.defaultFileURL
            let schema = Schema([CountrySnapshotRecord.self])
            let configuration: ModelConfiguration
            if inMemory {
                configuration = ModelConfiguration(
                    "CountrySnapshot",
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
            } else {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                configuration = ModelConfiguration(
                    "CountrySnapshot",
                    schema: schema,
                    url: fileURL,
                    cloudKitDatabase: .none
                )
            }
            containerResult = try .success(
                ModelContainer(for: schema, configurations: [configuration])
            )
        } catch {
            containerResult = .failure(.initialization(String(reflecting: error)))
        }
    }

    func load() async throws -> PersistedCountrySnapshot? {
        let context = try ModelContext(containerResult.get())
        guard let record = try context.fetch(FetchDescriptor<CountrySnapshotRecord>()).first else {
            return nil
        }
        do {
            let countries = try JSONDecoder().decode([Country].self, from: record.payload)
            return PersistedCountrySnapshot(countries: countries, savedAt: record.savedAt)
        } catch {
            throw CountryCacheStoreError.invalidSnapshot(String(reflecting: error))
        }
    }

    func save(_ snapshot: PersistedCountrySnapshot) async throws {
        let context = try ModelContext(containerResult.get())
        let records = try context.fetch(FetchDescriptor<CountrySnapshotRecord>())
        for record in records {
            context.delete(record)
        }
        let payload = try JSONEncoder().encode(snapshot.countries)
        context.insert(
            CountrySnapshotRecord(id: "countries", payload: payload, savedAt: snapshot.savedAt)
        )
        try context.save()
    }

    private static var defaultFileURL: URL {
        URL.applicationSupportDirectory
            .appending(
                path: Bundle.main.bundleIdentifier ?? "CountryBrowser",
                directoryHint: .isDirectory
            )
            .appending(path: "CountryCache.store")
    }
}

actor CountrySnapshotCache {
    private let store: any CountryCacheStore
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CountryBrowser",
        category: "CountryCache"
    )
    private var hasLoaded = false
    private var cachedSnapshot: PersistedCountrySnapshot?
    private var loadTask: Task<PersistedCountrySnapshot?, Error>?

    init(store: any CountryCacheStore) {
        self.store = store
    }

    func load() async -> PersistedCountrySnapshot? {
        guard !hasLoaded else {
            return cachedSnapshot
        }
        let task: Task<PersistedCountrySnapshot?, Error>
        if let loadTask {
            task = loadTask
        } else {
            task = Task {
                try await store.load()
            }
            loadTask = task
        }
        do {
            cachedSnapshot = try await task.value
        } catch {
            logger.error(
                "Could not load saved country data: \(String(reflecting: error), privacy: .private)"
            )
        }
        hasLoaded = true
        loadTask = nil
        return cachedSnapshot
    }

    func save(_ snapshot: PersistedCountrySnapshot) async {
        do {
            try await store.save(snapshot)
            cachedSnapshot = snapshot
            hasLoaded = true
        } catch {
            logger.error(
                "Could not persist country data: \(String(reflecting: error), privacy: .private)"
            )
        }
    }

    func logFallback(_ error: any Error, isRefresh: Bool) {
        let action = isRefresh ? "refresh" : "request"
        logger.error(
            "Country list \(action) failed; serving saved data: \(String(reflecting: error), privacy: .private)"
        )
    }
}
