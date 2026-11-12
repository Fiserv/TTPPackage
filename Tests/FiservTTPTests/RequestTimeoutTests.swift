import XCTest
import Combine
import ObjectiveC
@testable import FiservTTP

/// FiservTTPConfig.requestTimeout must be applied to every Commerce Hub request, while the cancels sent by the
/// automatic timeout reversal keep their own 10 second timeout.
///
/// Network traffic is intercepted by swizzling +[NSURLSessionConfiguration defaultSessionConfiguration],
/// which FiservTTPServices.sendRequest uses to build its URLSession, so no production code needs a test seam.
/// URLSession does not copy the configuration's timeouts onto the URLRequest a URLProtocol sees (it stays at
/// 60 seconds), so the swizzle records each configuration it hands out; sendRequest sets the timeouts on that
/// same object before creating its session. The elapse tests confirm the recorded value is the one enforced.
final class RequestTimeoutTests: XCTestCase {

    private let chargesPath = "/ch/payments/v1/charges"
    private let cancelsPath = "/ch/payments/v1/cancels"

    private let cancelResponse = """
        {"gatewayResponse":{"transactionType":"CANCEL","transactionState":"VOIDED","transactionProcessingDetails":{"transactionId":"CANCEL-TXN-ID"}}}
        """

    override class func setUp() {
        super.setUp()
        URLSessionConfiguration.installTimeoutObservingStub()
    }

    override func setUp() {
        super.setUp()
        TimeoutObservingStubProtocol.reset()
    }

    func testDefaultRequestTimeoutIs30Seconds() {
        XCTAssertEqual(makeConfig().requestTimeout, 30)
    }

    func testNonPositiveRequestTimeoutFallsBackToDefault() {
        XCTAssertEqual(makeConfig(requestTimeout: 0).requestTimeout, 30)
        XCTAssertEqual(makeConfig(requestTimeout: -5).requestTimeout, 30)
        XCTAssertEqual(makeConfig(requestTimeout: .nan).requestTimeout, 30)
    }

    func testRequestsUseTheDefaultTimeoutWhenNoneIsConfigured() async {
        TimeoutObservingStubProtocol.responses[cancelsPath] = .success((200, cancelResponse))

        let result = await sendCancel(config: makeConfig())

        XCTAssertNoThrow(try result.get())
        XCTAssertEqual(TimeoutObservingStubProtocol.requestTimeouts, [30])
        XCTAssertEqual(TimeoutObservingStubProtocol.resourceTimeouts, [30])
    }

    func testRequestsUseTheConfiguredTimeout() async {
        TimeoutObservingStubProtocol.responses[cancelsPath] = .success((200, cancelResponse))

        let result = await sendCancel(config: makeConfig(requestTimeout: 45))

        XCTAssertNoThrow(try result.get())
        XCTAssertEqual(TimeoutObservingStubProtocol.requestTimeouts, [45])
        XCTAssertEqual(TimeoutObservingStubProtocol.resourceTimeouts, [45])
    }

    func testConfiguredTimeoutElapsesBeforeASlowResponse() async {
        TimeoutObservingStubProtocol.responses[cancelsPath] = .success((200, cancelResponse))
        TimeoutObservingStubProtocol.responseDelay = 1

        let result = await sendCancel(config: makeConfig(requestTimeout: 0.5))

        switch result {
        case .success:
            XCTFail("Expected the request to time out")
        case .failure(let error):
            XCTAssertEqual(error.code, URLError.timedOut.rawValue)
        }
    }

    func testSlowResponseSucceedsWithinALongerConfiguredTimeout() async {
        TimeoutObservingStubProtocol.responses[cancelsPath] = .success((200, cancelResponse))
        TimeoutObservingStubProtocol.responseDelay = 1

        let result = await sendCancel(config: makeConfig(requestTimeout: 3))

        XCTAssertNoThrow(try result.get())
    }

    func testReversalCancelsKeepTheirOwnTimeout() async throws {
        TimeoutObservingStubProtocol.responses[chargesPath] = .failure(URLError(.timedOut))
        TimeoutObservingStubProtocol.responses[cancelsPath] = .success((200, cancelResponse))

        let response = try await makeTimedOutCapture(config: makeConfig(requestTimeout: 45))

        // One URLSession per request, created in order: the capture, then the reversal's cancel.
        XCTAssertEqual(TimeoutObservingStubProtocol.requested, [chargesPath, cancelsPath])
        XCTAssertEqual(TimeoutObservingStubProtocol.requestTimeouts, [45, 10])
        XCTAssertEqual(TimeoutObservingStubProtocol.resourceTimeouts, [45, 10])
        XCTAssertEqual(response.gatewayResponse?.transactionState, "VOIDED")
    }

    // MARK: - Helpers

    private func makeConfig() -> FiservTTPConfig {
        return FiservTTPConfig(secretKey: "secret",
                               apiKey: "apikey",
                               environment: .Sandbox,
                               currencyCode: "USD",
                               merchantId: "MID",
                               merchantName: "Test",
                               merchantCategoryCode: "5999",
                               terminalId: "TID",
                               terminalProfileId: "PROFILE")
    }

    private func makeConfig(requestTimeout: TimeInterval) -> FiservTTPConfig {
        return FiservTTPConfig(secretKey: "secret",
                               apiKey: "apikey",
                               environment: .Sandbox,
                               currencyCode: "USD",
                               merchantId: "MID",
                               merchantName: "Test",
                               merchantCategoryCode: "5999",
                               terminalId: "TID",
                               terminalProfileId: "PROFILE",
                               requestTimeout: requestTimeout)
    }

    private func sendCancel(config: FiservTTPConfig) async -> Result<Models.CommerceHubResponse, FiservTTPRequestError> {
        let services = FiservTTPServices(config: config)
        return await services.cancels(clientRequestId: UUID().uuidString,
                                      amountRequest: Models.AmountRequest(total: 1.00, currency: "USD"),
                                      referenceTransactionDetailsRequest: .init(referenceTransactionId: "TXN-ID"))
    }

    /// Runs on the main actor so the networkReadySubject subscription is in place before NWPathMonitor's
    /// update (delivered via DispatchQueue.main.async) can be published. A capture needs no card read, so it
    /// reaches the timeout reversal path on a simulator.
    @MainActor
    private func makeTimedOutCapture(config: FiservTTPConfig) async throws -> Models.CommerceHubResponse {
        let reader = FiservTTPCardReader(configuration: config)

        // timeoutReversal only sends requests once NWPathMonitor reports the network as ready.
        let ready = expectation(description: "network ready")
        var bag = Set<AnyCancellable>()
        reader.networkReadySubject.filter { $0 }.first().sink { _ in ready.fulfill() }.store(in: &bag)
        await fulfillment(of: [ready], timeout: 5)

        return try await reader.charges(clientRequestId: UUID().uuidString,
                                        amount: 4.00,
                                        transactionType: .capture,
                                        transactionDetailsRequest: .init(merchantTransactionId: "CAPTURE-1", captureFlag: true),
                                        referenceTransactionDetailsRequest: .init(referenceTransactionId: "AUTH-TXN-ID"))
    }
}

// MARK: - Stub

final class TimeoutObservingStubProtocol: URLProtocol {

    private static let lock = NSLock()
    private static var _requested: [String] = []
    private static var _configurations: [URLSessionConfiguration] = []
    static var responses: [String: Result<(Int, String), Error>] = [:]
    static var responseDelay: TimeInterval = 0

    /// Paths of the requests started, in order.
    static var requested: [String] {
        lock.lock(); defer { lock.unlock() }
        return _requested
    }

    /// timeoutIntervalForRequest of each default configuration handed out, in order.
    static var requestTimeouts: [TimeInterval] {
        lock.lock(); defer { lock.unlock() }
        return _configurations.map(\.timeoutIntervalForRequest)
    }

    /// timeoutIntervalForResource of each default configuration handed out, in order.
    static var resourceTimeouts: [TimeInterval] {
        lock.lock(); defer { lock.unlock() }
        return _configurations.map(\.timeoutIntervalForResource)
    }

    static func record(_ configuration: URLSessionConfiguration) {
        lock.lock(); defer { lock.unlock() }
        _configurations.append(configuration)
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        _requested = []
        _configurations = []
        responses = [:]
        responseDelay = 0
    }

    private var stopped = false

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func stopLoading() {
        Self.lock.lock(); defer { Self.lock.unlock() }
        stopped = true
    }

    override func startLoading() {
        let path = request.url?.path ?? ""
        Self.lock.lock()
        Self._requested.append(path)
        let response = Self.responses[path]
        let delay = Self.responseDelay
        Self.lock.unlock()

        let respond = { [self] in
            Self.lock.lock()
            let stopped = self.stopped
            Self.lock.unlock()
            guard !stopped else { return }

            switch response {
            case .success(let (statusCode, json)):
                let http = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
                client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data(json.utf8))
                client?.urlProtocolDidFinishLoading(self)
            case .failure(let error):
                client?.urlProtocol(self, didFailWithError: error)
            case nil:
                client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            }
        }

        if delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: respond)
        } else {
            respond()
        }
    }
}

extension URLSessionConfiguration {

    private static var timeoutObservingStubInstalled = false

    static func installTimeoutObservingStub() {
        guard !timeoutObservingStubInstalled else { return }
        timeoutObservingStubInstalled = true
        let original = class_getClassMethod(URLSessionConfiguration.self, NSSelectorFromString("defaultSessionConfiguration"))!
        let replacement = class_getClassMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration.timeoutObservingStub_defaultSessionConfiguration))!
        method_exchangeImplementations(original, replacement)
    }

    @objc class func timeoutObservingStub_defaultSessionConfiguration() -> URLSessionConfiguration {
        let configuration = timeoutObservingStub_defaultSessionConfiguration() // swapped: calls the original
        configuration.protocolClasses = [TimeoutObservingStubProtocol.self] + (configuration.protocolClasses ?? [])
        TimeoutObservingStubProtocol.record(configuration)
        return configuration
    }
}
