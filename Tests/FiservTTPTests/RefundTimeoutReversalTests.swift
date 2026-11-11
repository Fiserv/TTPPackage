import XCTest
import Combine
import ObjectiveC
@testable import FiservTTP

/// A refund that times out must be reversed by cancelling the REFUND, located by the Client-Request-Id it
/// was sent with, and never by cancelling the original charge its referenceTransactionDetails point to.
///
/// Network traffic is intercepted by swizzling +[NSURLSessionConfiguration defaultSessionConfiguration],
/// which FiservTTPServices.sendRequest uses to build its URLSession, so no production code needs a test seam.
final class RefundTimeoutReversalTests: XCTestCase {

    private let saleTransactionId = "ORIGINAL-SALE-TXN-ID"
    private let refundClientRequestId = "refund-client-request-id"

    override class func setUp() {
        super.setUp()
        URLSessionConfiguration.installRecordingStub()
    }

    override func setUp() {
        super.setUp()
        RecordingStubProtocol.reset()
        RecordingStubProtocol.responses["/ch/payments/v1/refunds"] = .failure(URLError(.timedOut))
    }

    func testRefundTimeoutCancelsTheRefundNotTheOriginalCharge() async throws {
        RecordingStubProtocol.responses["/ch/payments/v1/transaction-inquiry"] = .success((200, """
            [{"gatewayResponse":{"transactionType":"REFUND","transactionState":"CAPTURED","transactionProcessingDetails":{"transactionId":"REFUND-TXN-ID"}}}]
            """))
        RecordingStubProtocol.responses["/ch/payments/v1/cancels"] = .success((200, """
            {"gatewayResponse":{"transactionType":"CANCEL","transactionState":"VOIDED","transactionProcessingDetails":{"transactionId":"CANCEL-TXN-ID"}}}
            """))

        let response = try await makeMatchedRefund()

        let requests = RecordingStubProtocol.recorded
        XCTAssertEqual(requests.map(\.path), ["/ch/payments/v1/refunds",
                                              "/ch/payments/v1/transaction-inquiry",
                                              "/ch/payments/v1/cancels"])
        guard requests.count == 3 else { return }

        let inquiryReference = try referenceTransactionDetails(of: requests[1])
        XCTAssertEqual(inquiryReference["referenceClientRequestId"] as? String, refundClientRequestId)

        let cancelReference = try referenceTransactionDetails(of: requests[2])
        XCTAssertEqual(cancelReference["referenceTransactionId"] as? String, "REFUND-TXN-ID")
        XCTAssertNotEqual(cancelReference["referenceTransactionId"] as? String, saleTransactionId)

        XCTAssertEqual(response.gatewayResponse?.transactionState, "VOIDED")
    }

    func testRefundTimeoutWhenRefundWasNotProcessedDoesNotCancelAnything() async throws {
        // Commerce Hub returns an empty list when no transaction matches the Client-Request-Id.
        RecordingStubProtocol.responses["/ch/payments/v1/transaction-inquiry"] = .success((201, "[]"))

        do {
            _ = try await makeMatchedRefund()
            XCTFail("Expected refunds() to throw")
        } catch let error as FiservTTPCardReaderError {
            XCTAssertEqual(error.title, "Timeout Reversal")
        }

        XCTAssertEqual(RecordingStubProtocol.recorded.map(\.path), ["/ch/payments/v1/refunds",
                                                                    "/ch/payments/v1/transaction-inquiry"])
    }

    func testRefundTimeoutWhenRefundWasDeclinedDoesNotCancelAnything() async throws {
        RecordingStubProtocol.responses["/ch/payments/v1/transaction-inquiry"] = .success((200, """
            [{"gatewayResponse":{"transactionType":"REFUND","transactionState":"DECLINED","transactionProcessingDetails":{"transactionId":"REFUND-TXN-ID"}}}]
            """))

        do {
            _ = try await makeMatchedRefund()
            XCTFail("Expected refunds() to throw")
        } catch let error as FiservTTPCardReaderError {
            XCTAssertEqual(error.title, "Timeout Reversal")
        }

        XCTAssertFalse(RecordingStubProtocol.recorded.map(\.path).contains("/ch/payments/v1/cancels"))
    }

    // MARK: - Helpers

    /// Runs on the main actor so the networkReadySubject subscription is in place before NWPathMonitor's
    /// update (delivered via DispatchQueue.main.async) can be published.
    @MainActor
    private func makeMatchedRefund() async throws -> Models.CommerceHubResponse {
        let config = FiservTTPConfig(secretKey: "secret",
                                     apiKey: "apikey",
                                     environment: .Sandbox,
                                     currencyCode: "USD",
                                     merchantId: "MID",
                                     merchantName: "Test",
                                     merchantCategoryCode: "5999",
                                     terminalId: "TID",
                                     terminalProfileId: "PROFILE")
        let reader = FiservTTPCardReader(configuration: config)

        // timeoutReversal only sends requests once NWPathMonitor reports the network as ready.
        let ready = expectation(description: "network ready")
        var bag = Set<AnyCancellable>()
        reader.networkReadySubject.filter { $0 }.first().sink { _ in ready.fulfill() }.store(in: &bag)
        await fulfillment(of: [ready], timeout: 5)

        return try await reader.refunds(clientRequestId: refundClientRequestId,
                                        amount: 4.00,
                                        refundTransactionType: .matched,
                                        referenceTransactionDetails: .init(referenceTransactionId: saleTransactionId))
    }

    private func referenceTransactionDetails(of request: RecordingStubProtocol.Recorded) throws -> [String: Any] {
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        return try XCTUnwrap(body["referenceTransactionDetails"] as? [String: Any])
    }
}

// MARK: - Stub

final class RecordingStubProtocol: URLProtocol {

    struct Recorded {
        let path: String
        let body: Data
    }

    private static let lock = NSLock()
    private static var _recorded: [Recorded] = []
    static var responses: [String: Result<(Int, String), Error>] = [:]

    static var recorded: [Recorded] {
        lock.lock(); defer { lock.unlock() }
        return _recorded
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        _recorded = []
        responses = [:]
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let path = request.url?.path ?? ""
        Self.lock.lock()
        Self._recorded.append(Recorded(path: path, body: Self.body(of: request)))
        let response = Self.responses[path]
        Self.lock.unlock()

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

    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

extension URLSessionConfiguration {

    private static var recordingStubInstalled = false

    static func installRecordingStub() {
        guard !recordingStubInstalled else { return }
        recordingStubInstalled = true
        let original = class_getClassMethod(URLSessionConfiguration.self, NSSelectorFromString("defaultSessionConfiguration"))!
        let replacement = class_getClassMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration.recordingStub_defaultSessionConfiguration))!
        method_exchangeImplementations(original, replacement)
    }

    @objc class func recordingStub_defaultSessionConfiguration() -> URLSessionConfiguration {
        let configuration = recordingStub_defaultSessionConfiguration() // swapped: calls the original
        configuration.protocolClasses = [RecordingStubProtocol.self] + (configuration.protocolClasses ?? [])
        return configuration
    }
}
