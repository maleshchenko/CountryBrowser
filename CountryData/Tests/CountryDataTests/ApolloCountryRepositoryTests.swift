import Apollo
import ApolloAPI
@testable import CountryData
import Foundation
import Testing

final class DelayedResponse: @unchecked Sendable {
    private let deliver: () -> Void

    init<Data: RootSelectionSet>(
        result: GraphQLResult<Data>,
        completionHandler: @escaping (Result<GraphQLResult<Data>, any Error>) -> Void
    ) {
        deliver = {
            completionHandler(.success(result))
        }
    }

    func send() {
        deliver()
    }
}

actor RequestMonitor {
    private var requestCount = 0
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func recordRequest() {
        requestCount += 1
        let readyWaiters = waiters.filter { $0.0 <= requestCount }
        waiters.removeAll { $0.0 <= requestCount }
        readyWaiters.forEach { $0.1.resume() }
    }

    func waitForRequestCount(_ expectedCount: Int) async {
        guard requestCount < expectedCount else {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append((expectedCount, continuation))
        }
    }
}

private enum ResponseFixtureError: Error {
    case invalidJSON
}

private func makeJSONObject(from value: [String: Any]) throws -> JSONObject {
    let data = try JSONSerialization.data(withJSONObject: value)
    guard let object = try JSONSerializationFormat.deserialize(data: data) as? JSONObject else {
        throw ResponseFixtureError.invalidJSON
    }
    return object
}

private func countryListResponse(japanName: String = "Japan") throws -> JSONObject {
    try makeJSONObject(
        from: [
            "data": [
                "countries": [
                    [
                        "__typename": "Country",
                        "code": "JP",
                        "name": japanName,
                        "emoji": "🇯🇵",
                        "capital": "Tokyo",
                        "currencies": ["JPY"],
                        "continent": [
                            "__typename": "Continent",
                            "code": "AS",
                            "name": "Asia"
                        ],
                        "languages": [
                            [
                                "__typename": "Language",
                                "code": "ja",
                                "name": "Japanese"
                            ]
                        ]
                    ],
                    [
                        "__typename": "Country",
                        "code": "CA",
                        "name": "Canada",
                        "emoji": "🇨🇦",
                        "capital": "Ottawa",
                        "currencies": ["CAD"],
                        "continent": [
                            "__typename": "Continent",
                            "code": "NA",
                            "name": "North America"
                        ],
                        "languages": [
                            [
                                "__typename": "Language",
                                "code": "en",
                                "name": "English"
                            ]
                        ]
                    ]
                ]
            ]
        ]
    )
}

struct ApolloCountryRepositoryTests {
    @Test
    func loadsAndMapsCountriesThroughApolloTransport() async throws {
        let transport = try MockNetworkTransport(responses: [countryListResponse()])
        let repository = ApolloCountryRepository(networkTransport: transport)

        let countries = try await repository.countries(matching: "")

        #expect(countries.countries.map(\.code) == ["JP", "CA"])
        #expect(countries.countries[0].capital == "Tokyo")
        #expect(countries.countries[0].languages == [CountryLanguage(code: "ja", name: "Japanese")])
        #expect(countries.freshness == .fresh)
        #expect(transport.numberOfRequests == 1)
    }

    @Test
    func surfacesGraphQLErrors() async throws {
        let errorResponse = try makeJSONObject(
            from: [
                "errors": [
                    ["message": "Country service is unavailable"]
                ]
            ]
        )
        let repository = ApolloCountryRepository(
            networkTransport: MockNetworkTransport(responses: [errorResponse])
        )

        do {
            _ = try await repository.countries(matching: "")
            Issue.record("Expected a GraphQL error.")
        } catch let error as CountryRepositoryError {
            guard case let .graphQLErrors(messages) = error else {
                Issue.record("Expected GraphQL error details, got \(error).")
                return
            }
            #expect(messages == ["Country service is unavailable"])
        }
    }

    @Test
    func classifiesAndPreservesTransportFailureDiagnostics() async throws {
        let repository = ApolloCountryRepository(
            networkTransport: MockNetworkTransport(
                responses: [],
                failure: URLError(.notConnectedToInternet)
            )
        )

        do {
            _ = try await repository.countries(matching: "")
            Issue.record("Expected a network error.")
        } catch let error as CountryRepositoryError {
            guard case let .networkFailure(details) = error else {
                Issue.record("Expected a network failure, got \(error).")
                return
            }
            #expect(error.category == .network)
            #expect(details.contains("NSURLErrorDomain"))
            #expect(error.errorDescription?.contains(details) == false)
        }
    }

    @Test
    func reportsMissingData() async throws {
        let missingDataResponse = try makeJSONObject(from: ["data": NSNull()])
        let repository = ApolloCountryRepository(
            networkTransport: MockNetworkTransport(responses: [missingDataResponse])
        )

        do {
            _ = try await repository.countries(matching: "")
            Issue.record("Expected a missing-response error.")
        } catch let error as CountryRepositoryError {
            guard case .missingResponse = error else {
                Issue.record("Expected missing response, got \(error).")
                return
            }
        }
    }

    @Test
    func cachesSuccessfulCountryListAcrossSearches() async throws {
        let transport = try MockNetworkTransport(
            responses: [countryListResponse(), countryListResponse(japanName: "Nippon")]
        )
        let repository = ApolloCountryRepository(networkTransport: transport)

        let japan = try await repository.countries(matching: "jap")
        let canada = try await repository.countries(matching: "can")
        let allCountries = try await repository.countries(matching: "")
        let refreshed = try await repository.refreshCountries()
        let nippon = try await repository.countries(matching: "nip")

        #expect(japan.countries.map(\.code) == ["JP"])
        #expect(canada.countries.map(\.code) == ["CA"])
        #expect(allCountries.countries.map(\.code) == ["JP", "CA"])
        #expect(refreshed.countries.first?.name == "Nippon")
        #expect(nippon.countries.map(\.code) == ["JP"])
        #expect(transport.numberOfRequests == 2)
    }

    @Test
    func refetchesWhenCacheLifetimeIsZero() async throws {
        let transport = try MockNetworkTransport(
            responses: [countryListResponse(), countryListResponse(japanName: "Nippon")]
        )
        let repository = ApolloCountryRepository(networkTransport: transport, cacheLifetime: 0)

        let firstFetch = try await repository.countries(matching: "")
        let secondFetch = try await repository.countries(matching: "")

        #expect(firstFetch.countries.first?.name == "Japan")
        #expect(secondFetch.countries.first?.name == "Nippon")
        #expect(transport.numberOfRequests == 2)
    }

    @Test
    func coalescesConcurrentCountryRequests() async throws {
        let transport = try MockNetworkTransport(
            responses: [countryListResponse()],
            blockedResponseIndexes: [0]
        )
        let repository = ApolloCountryRepository(networkTransport: transport)

        let resultsTask = Task {
            try await withThrowingTaskGroup(of: CountryListResult.self) { group in
                for _ in 0 ..< 5 {
                    group.addTask {
                        try await repository.countries(matching: "")
                    }
                }

                var results: [CountryListResult] = []
                for try await result in group {
                    results.append(result)
                }
                return results
            }
        }
        await transport.waitForRequestCount(1)
        #expect(transport.releaseResponse(at: 0))
        let results = try await resultsTask.value

        #expect(results.count == 5)
        #expect(results.allSatisfy { $0.countries.map(\.code) == ["JP", "CA"] })
        #expect(transport.numberOfRequests == 1)
    }

    @Test
    func refreshSupersedesInflightCountryRequestWithoutCachingItsResult() async throws {
        let transport = try MockNetworkTransport(
            responses: [
                countryListResponse(),
                countryListResponse(japanName: "Nippon")
            ],
            blockedResponseIndexes: [0, 1]
        )
        let repository = ApolloCountryRepository(networkTransport: transport)
        let initialRequest = Task {
            try await repository.countries(matching: "")
        }

        await transport.waitForRequestCount(1)
        let refreshRequest = Task {
            try await repository.refreshCountries()
        }
        await transport.waitForRequestCount(2)

        #expect(transport.releaseResponse(at: 1))
        let refreshedCountries = try await refreshRequest.value
        #expect(transport.releaseResponse(at: 0))
        let initialCountries = try await initialRequest.value
        let cachedCountries = try await repository.countries(matching: "")

        #expect(refreshedCountries.countries.first?.name == "Nippon")
        #expect(initialCountries.countries.first?.name == "Japan")
        #expect(cachedCountries.countries.first?.name == "Nippon")
        #expect(transport.numberOfRequests == 2)
    }

    @Test
    func coalescesConcurrentRefreshRequests() async throws {
        let transport = try MockNetworkTransport(
            responses: [countryListResponse(japanName: "Nippon")],
            blockedResponseIndexes: [0]
        )
        let repository = ApolloCountryRepository(networkTransport: transport)

        let resultsTask = Task {
            try await withThrowingTaskGroup(of: CountryListResult.self) { group in
                for _ in 0 ..< 3 {
                    group.addTask {
                        try await repository.refreshCountries()
                    }
                }

                var results: [CountryListResult] = []
                for try await result in group {
                    results.append(result)
                }
                return results
            }
        }
        await transport.waitForRequestCount(1)
        #expect(transport.releaseResponse(at: 0))
        let results = try await resultsTask.value

        #expect(results.count == 3)
        #expect(results.allSatisfy { $0.countries.first?.name == "Nippon" })
        #expect(transport.numberOfRequests == 1)
    }

    @Test
    func doesNotCacheFailedCountryListRequest() async throws {
        let errorResponse = try makeJSONObject(
            from: ["errors": [["message": "Temporary failure"]]]
        )
        let transport = try MockNetworkTransport(
            responses: [errorResponse, countryListResponse()]
        )
        let repository = ApolloCountryRepository(networkTransport: transport)

        do {
            _ = try await repository.countries(matching: "")
            Issue.record("Expected the first request to fail.")
        } catch is CountryRepositoryError {
            // The following request verifies the failure wasn't cached.
        }

        let countries = try await repository.countries(matching: "")

        #expect(countries.countries.map(\.code) == ["JP", "CA"])
        #expect(transport.numberOfRequests == 2)
    }
}
