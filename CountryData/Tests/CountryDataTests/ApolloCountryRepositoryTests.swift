import Apollo
import ApolloAPI
@testable import CountryData
import Foundation
import Testing

private final class DelayedResponse: @unchecked Sendable {
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

private final class MockNetworkTransport: NetworkTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [JSONObject]
    private let responseDelays: [TimeInterval]
    private let failure: (any Error)?
    private var requestCount = 0

    init(
        responses: [JSONObject],
        responseDelays: [TimeInterval] = [],
        failure: (any Error)? = nil
    ) {
        self.responses = responses
        self.responseDelays = responseDelays
        self.failure = failure
    }

    var numberOfRequests: Int {
        lock.lock()
        defer { lock.unlock() }
        return requestCount
    }

    func send<Operation: GraphQLOperation>(
        operation: Operation,
        cachePolicy _: CachePolicy,
        contextIdentifier _: UUID?,
        context _: (any RequestContext)?,
        callbackQueue: DispatchQueue,
        completionHandler: @escaping (Result<GraphQLResult<Operation.Data>, any Error>) -> Void
    ) -> any Cancellable {
        lock.lock()
        requestCount += 1
        if let failure {
            lock.unlock()
            completionHandler(.failure(failure))
            return EmptyCancellable()
        }
        let responseIndex = min(requestCount - 1, responses.count - 1)
        let body = responses[responseIndex]
        let responseDelay = responseIndex < responseDelays.count ? responseDelays[responseIndex] : 0
        lock.unlock()

        do {
            let response = GraphQLResponse<Operation.Data>(
                operation: operation,
                body: body
            )
            let (result, _) = try response.parseResult()
            if responseDelay > 0 {
                let delayedResponse = DelayedResponse(
                    result: result,
                    completionHandler: completionHandler
                )
                callbackQueue.asyncAfter(deadline: .now() + responseDelay) {
                    delayedResponse.send()
                }
            } else {
                completionHandler(.success(result))
            }
        } catch {
            completionHandler(.failure(error))
        }

        return EmptyCancellable()
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

private func waitForRequestCount(
    _ expectedCount: Int,
    transport: MockNetworkTransport
) async throws -> Bool {
    for _ in 0 ..< 100 {
        if transport.numberOfRequests >= expectedCount {
            return true
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    return transport.numberOfRequests >= expectedCount
}

struct ApolloCountryRepositoryTests {
    @Test
    func loadsAndMapsCountriesThroughApolloTransport() async throws {
        let transport = try MockNetworkTransport(responses: [countryListResponse()])
        let repository = ApolloCountryRepository(networkTransport: transport)

        let countries = try await repository.countries(matching: "")

        #expect(countries.map(\.code) == ["JP", "CA"])
        #expect(countries[0].capital == "Tokyo")
        #expect(countries[0].languages == [CountryLanguage(code: "ja", name: "Japanese")])
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

        #expect(japan.map(\.code) == ["JP"])
        #expect(canada.map(\.code) == ["CA"])
        #expect(allCountries.map(\.code) == ["JP", "CA"])
        #expect(refreshed.first?.name == "Nippon")
        #expect(nippon.map(\.code) == ["JP"])
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

        #expect(firstFetch.first?.name == "Japan")
        #expect(secondFetch.first?.name == "Nippon")
        #expect(transport.numberOfRequests == 2)
    }

    @Test
    func coalescesConcurrentCountryRequests() async throws {
        let transport = try MockNetworkTransport(
            responses: [countryListResponse()],
            responseDelays: [0.1]
        )
        let repository = ApolloCountryRepository(networkTransport: transport)

        let results = try await withThrowingTaskGroup(of: [Country].self) { group in
            for _ in 0 ..< 5 {
                group.addTask {
                    try await repository.countries(matching: "")
                }
            }

            var results: [[Country]] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        #expect(results.count == 5)
        #expect(results.allSatisfy { $0.map(\.code) == ["JP", "CA"] })
        #expect(transport.numberOfRequests == 1)
    }

    @Test
    func refreshSupersedesInflightCountryRequestWithoutCachingItsResult() async throws {
        let transport = try MockNetworkTransport(
            responses: [
                countryListResponse(),
                countryListResponse(japanName: "Nippon")
            ],
            responseDelays: [0.2, 0.05]
        )
        let repository = ApolloCountryRepository(networkTransport: transport)
        let initialRequest = Task {
            try await repository.countries(matching: "")
        }

        #expect(try await waitForRequestCount(1, transport: transport))
        let refreshRequest = Task {
            try await repository.refreshCountries()
        }
        #expect(try await waitForRequestCount(2, transport: transport))

        let refreshedCountries = try await refreshRequest.value
        let initialCountries = try await initialRequest.value
        let cachedCountries = try await repository.countries(matching: "")

        #expect(refreshedCountries.first?.name == "Nippon")
        #expect(initialCountries.first?.name == "Japan")
        #expect(cachedCountries.first?.name == "Nippon")
        #expect(transport.numberOfRequests == 2)
    }

    @Test
    func coalescesConcurrentRefreshRequests() async throws {
        let transport = try MockNetworkTransport(
            responses: [countryListResponse(japanName: "Nippon")],
            responseDelays: [0.1]
        )
        let repository = ApolloCountryRepository(networkTransport: transport)

        let results = try await withThrowingTaskGroup(of: [Country].self) { group in
            for _ in 0 ..< 3 {
                group.addTask {
                    try await repository.refreshCountries()
                }
            }

            var results: [[Country]] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        #expect(results.count == 3)
        #expect(results.allSatisfy { $0.first?.name == "Nippon" })
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

        #expect(countries.map(\.code) == ["JP", "CA"])
        #expect(transport.numberOfRequests == 2)
    }
}
