import XCTest
import Combine
import ObjectiveC
@testable import FiservTTP

/// The package can be linked by apps targeting iOS 15. Operations that do not read a card must keep working on any
/// supported OS, while card-present operations must fail cleanly below iOS 18 without touching the network.
///
/// Network traffic is intercepted by swizzling +[NSURLSessionConfiguration defaultSessionConfiguration],
/// which FiservTTPServices.sendRequest uses to build its URLSession, so no production code needs a test seam.
final class OlderOSAvailabilityTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        URLSessionConfiguration.installOlderOSStub()
    }

    override class func tearDown() {
        URLSessionConfiguration.uninstallOlderOSStub()
        super.tearDown()
    }

    override func setUp() {
        super.setUp()
        OlderOSStubProtocol.reset()
    }

    // MARK: - Operations without a card read

    func testMatchedRefundWorksWithoutCardReader() async throws {
        OlderOSStubProtocol.responses["/ch/payments/v1/refunds"] = (200, """
            {"gatewayResponse":{"transactionType":"REFUND","transactionState":"CAPTURED","transactionProcessingDetails":{"transactionId":"REFUND-TXN-ID"}}}
            """)

        let reader = try await makeReader()
        let response = try await reader.refunds(clientRequestId: "refund-client-request-id",
                                                amount: 4.00,
                                                refundTransactionType: .matched,
                                                referenceTransactionDetails: .init(referenceTransactionId: "SALE"))

        XCTAssertEqual(response.gatewayResponse?.transactionType, "REFUND")
        XCTAssertEqual(OlderOSStubProtocol.recordedPaths, ["/ch/payments/v1/refunds"])
    }

    func testTransactionInquiryWorksWithoutCardReader() async throws {
        OlderOSStubProtocol.responses["/ch/payments/v1/transaction-inquiry"] = (200, """
            [{"gatewayResponse":{"transactionType":"SALE","transactionState":"CAPTURED","transactionProcessingDetails":{"transactionId":"SALE-TXN-ID"}}}]
            """)

        let reader = try await makeReader()
        let results = try await reader.transactionInquiry(clientRequestId: "inquiry-client-request-id",
                                                          referenceTransactionDetailsRequest: .init(referenceTransactionId: "SALE"))

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(OlderOSStubProtocol.recordedPaths, ["/ch/payments/v1/transaction-inquiry"])
    }

    func testCancelWorksWithoutCardReader() async throws {
        OlderOSStubProtocol.responses["/ch/payments/v1/cancels"] = (200, """
            {"gatewayResponse":{"transactionType":"CANCEL","transactionState":"VOIDED","transactionProcessingDetails":{"transactionId":"CANCEL-TXN-ID"}}}
            """)

        let reader = try await makeReader()
        let response = try await reader.cancels(clientRequestId: "cancel-client-request-id",
                                                amount: 4.00,
                                                referenceTransactionDetailsRequest: .init(referenceTransactionId: "SALE"))

        XCTAssertEqual(response.gatewayResponse?.transactionType, "CANCEL")
        XCTAssertEqual(OlderOSStubProtocol.recordedPaths, ["/ch/payments/v1/cancels"])
    }

    // MARK: - Card-present operations below iOS 18

    func testSaleThrowsBelowiOS18() async throws {
        if #available(iOS 18, *) {
            throw XCTSkip("Tap to Pay is available on iOS 18 and later")
        }

        let reader = try await makeReader()
        do {
            _ = try await reader.charges(clientRequestId: "sale-client-request-id",
                                         amount: 4.00,
                                         transactionType: .sale,
                                         transactionDetailsRequest: .init(merchantTransactionId: "MTID", captureFlag: true))
            XCTFail("Expected charges() to throw")
        } catch let error as FiservTTPCardReaderError {
            XCTAssertTrue(error.localizedDescription.contains("iOS 18"), error.localizedDescription)
        }

        XCTAssertEqual(OlderOSStubProtocol.recordedPaths, [])
    }

    func testCardPresentRefundThrowsBelowiOS18() async throws {
        if #available(iOS 18, *) {
            throw XCTSkip("Tap to Pay is available on iOS 18 and later")
        }

        let reader = try await makeReader()
        do {
            _ = try await reader.refunds(clientRequestId: "refund-client-request-id",
                                         amount: 4.00,
                                         refundTransactionType: .open,
                                         transactionDetails: .init(merchantTransactionId: "MTID", captureFlag: true))
            XCTFail("Expected refunds() to throw")
        } catch let error as FiservTTPCardReaderError {
            XCTAssertTrue(error.localizedDescription.contains("iOS 18"), error.localizedDescription)
        }

        XCTAssertEqual(OlderOSStubProtocol.recordedPaths, [])
    }

    func testReaderIsNotSupportedBelowiOS18() async throws {
        if #available(iOS 18, *) {
            throw XCTSkip("Tap to Pay is available on iOS 18 and later")
        }

        let reader = try await makeReader()
        XCTAssertFalse(reader.readerIsSupported())
        reader.finalize()
    }

    // MARK: - Helpers

    /// Runs on the main actor so the networkReadySubject subscription is in place before NWPathMonitor's
    /// update (delivered via DispatchQueue.main.async) can be published.
    @MainActor
    private func makeReader() async throws -> FiservTTPCardReader {
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

        let ready = expectation(description: "network ready")
        var bag = Set<AnyCancellable>()
        reader.networkReadySubject.filter { $0 }.first().sink { _ in ready.fulfill() }.store(in: &bag)
        await fulfillment(of: [ready], timeout: 5)

        return reader
    }
}

// MARK: - Stub

final class OlderOSStubProtocol: URLProtocol {

    private static let lock = NSLock()
    private static var _recordedPaths: [String] = []
    static var responses: [String: (Int, String)] = [:]

    static var recordedPaths: [String] {
        lock.lock(); defer { lock.unlock() }
        return _recordedPaths
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        _recordedPaths = []
        responses = [:]
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let path = request.url?.path ?? ""
        Self.lock.lock()
        Self._recordedPaths.append(path)
        let response = Self.responses[path]
        Self.lock.unlock()

        guard let (statusCode, json) = response else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let http = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil,
                                   headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

extension URLSessionConfiguration {

    private static var olderOSStubInstalled = false

    /// Exchanging the same pair again restores the previous implementation. The stub is installed only while this
    /// class runs, so it neither shadows nor is shadowed by another test class that swizzles the same method.
    private static func exchangeOlderOSStub() {
        let original = class_getClassMethod(URLSessionConfiguration.self, NSSelectorFromString("defaultSessionConfiguration"))!
        let replacement = class_getClassMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration.olderOSStub_defaultSessionConfiguration))!
        method_exchangeImplementations(original, replacement)
    }

    static func installOlderOSStub() {
        guard !olderOSStubInstalled else { return }
        olderOSStubInstalled = true
        exchangeOlderOSStub()
    }

    static func uninstallOlderOSStub() {
        guard olderOSStubInstalled else { return }
        olderOSStubInstalled = false
        exchangeOlderOSStub()
    }

    @objc class func olderOSStub_defaultSessionConfiguration() -> URLSessionConfiguration {
        let configuration = olderOSStub_defaultSessionConfiguration() // swapped: calls the original
        configuration.protocolClasses = [OlderOSStubProtocol.self] + (configuration.protocolClasses ?? [])
        return configuration
    }
}
