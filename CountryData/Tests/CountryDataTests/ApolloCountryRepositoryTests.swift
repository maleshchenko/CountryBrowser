import Apollo
import ApolloAPI
@testable import CountryData
import Foundation
import Testing

private final class MockNetworkTransport: NetworkTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [JSONObject]
    private var requestCount = 0

    init(responses: [JSONObject]) {
        self.responses = responses
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
        callbackQueue _: DispatchQueue,
        completionHandler: @escaping (Result<GraphQLResult<Operation.Data>, any Error>) -> Void
    ) -> any Cancellable {
        lock.lock()
        let responseIndex = min(requestCount, responses.count - 1)
        let body = responses[responseIndex]
        requestCount += 1
        lock.unlock()

        do {
            let response = GraphQLResponse<Operation.Data>(
                operation: operation,
                body: body
            )
            let (result, _) = try response.parseResult()
            completionHandler(.success(result))
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

private func countryListResponse() throws -> JSONObject {
    try makeJSONObject(
        from: [
            "data": [
                "countries": [
                    [
                        "__typename": "Country",
                        "code": "JP",
                        "name": "Japan",
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
        let transport = try MockNetworkTransport(responses: [countryListResponse()])
        let repository = ApolloCountryRepository(networkTransport: transport)

        let japan = try await repository.countries(matching: "jap")
        let canada = try await repository.countries(matching: "can")
        let allCountries = try await repository.countries(matching: "")

        #expect(japan.map(\.code) == ["JP"])
        #expect(canada.map(\.code) == ["CA"])
        #expect(allCountries.map(\.code) == ["JP", "CA"])
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
