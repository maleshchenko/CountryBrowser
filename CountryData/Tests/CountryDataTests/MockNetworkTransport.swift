import Apollo
import ApolloAPI
@testable import CountryData
import Foundation
import Testing

final class MockNetworkTransport: NetworkTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [JSONObject]
    private let blockedResponseIndexes: Set<Int>
    private var pendingResponses: [Int: DelayedResponse] = [:]
    private let failure: (any Error)?
    private var requestCount = 0
    private let requestMonitor = RequestMonitor()

    init(
        responses: [JSONObject],
        blockedResponseIndexes: Set<Int> = [],
        failure: (any Error)? = nil
    ) {
        self.responses = responses
        self.blockedResponseIndexes = blockedResponseIndexes
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
        let responseIndex = requestCount - 1
        if let failure {
            lock.unlock()
            Task {
                await requestMonitor.recordRequest()
            }
            completionHandler(.failure(failure))
            return EmptyCancellable()
        }
        let body = responses[min(responseIndex, responses.count - 1)]
        lock.unlock()

        do {
            let response = GraphQLResponse<Operation.Data>(
                operation: operation,
                body: body
            )
            let (result, _) = try response.parseResult()
            let delayedResponse = DelayedResponse(
                result: result,
                completionHandler: completionHandler
            )
            if blockedResponseIndexes.contains(responseIndex) {
                lock.lock()
                pendingResponses[responseIndex] = delayedResponse
                lock.unlock()
            } else {
                callbackQueue.async {
                    delayedResponse.send()
                }
            }
            Task {
                await requestMonitor.recordRequest()
            }
        } catch {
            Task {
                await requestMonitor.recordRequest()
            }
            completionHandler(.failure(error))
        }

        return EmptyCancellable()
    }

    func waitForRequestCount(_ expectedCount: Int) async {
        await requestMonitor.waitForRequestCount(expectedCount)
    }

    func releaseResponse(at index: Int) -> Bool {
        lock.lock()
        let response = pendingResponses.removeValue(forKey: index)
        lock.unlock()
        guard let response else {
            return false
        }
        response.send()
        return true
    }
}
