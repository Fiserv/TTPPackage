import XCTest
import ObjectiveC
@testable import FiservTTP

/// A `FiservTTPRequestObserver` set on `FiservTTPCardReader` sees every Commerce Hub request just before it is
/// sent, and exactly one completion for it, whatever the outcome.
///
/// Network traffic is intercepted by swizzling +[NSURLSessionConfiguration defaultSessionConfiguration],
/// which FiservTTPServices.sendRequest uses to build its URLSession, so no production code needs a test seam.
/// The swizzle is installed for this class only and removed again in `tearDown()`.
final class RequestObserverTests: XCTestCase {

    private let inquiryPath = "/ch/payments/v1/transaction-inquiry"
    private let clientRequestId = "observer-client-request-id"

    override class func setUp() {
        super.setUp()
        URLSessionConfiguration.toggleObserverStub()
    }

    override class func tearDown() {
        URLSessionConfiguration.toggleObserverStub()
        super.tearDown()
    }

    override func setUp() {
        super.setUp()
        ObserverStubProtocol.responses = [:]
    }

    func testObserverReceivesRequestAndSuccessfulResponse() async throws {
        ObserverStubProtocol.responses[inquiryPath] = .success((200, "[]"))
        let reader = makeReader()
        let observer = RecordingObserver()
        reader.requestObserver = observer

        let response = try await inquire(reader)

        XCTAssertTrue(response.isEmpty)

        XCTAssertEqual(observer.willSend.count, 1)
        let sent = try XCTUnwrap(observer.willSend.first)
        XCTAssertEqual(sent.url?.path, inquiryPath)
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Client-Request-Id"), clientRequestId)

        XCTAssertEqual(observer.completed.count, 1)
        let completed = try XCTUnwrap(observer.completed.first)
        XCTAssertEqual(completed.request.url?.path, inquiryPath)
        XCTAssertEqual((completed.response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(completed.data, Data("[]".utf8))
        XCTAssertNil(completed.error)
    }

    func testObserverReceivesHTTPErrorResponse() async throws {
        let body = #"{"error":[{"type":"GATEWAY","code":"104","message":"Invalid transaction"}]}"#
        ObserverStubProtocol.responses[inquiryPath] = .success((400, body))
        let reader = makeReader()
        let observer = RecordingObserver()
        reader.requestObserver = observer

        do {
            _ = try await inquire(reader)
            XCTFail("Expected transactionInquiry() to throw")
        } catch let error as FiservTTPCardReaderError {
            XCTAssertEqual(error.title, "Transaction Inquiry")
        }

        XCTAssertEqual(observer.willSend.count, 1)
        XCTAssertEqual(observer.completed.count, 1)
        let completed = try XCTUnwrap(observer.completed.first)
        XCTAssertEqual((completed.response as? HTTPURLResponse)?.statusCode, 400)
        XCTAssertEqual(completed.data, Data(body.utf8))
        XCTAssertNil(completed.error)
    }

    func testObserverReceivesTransportError() async throws {
        ObserverStubProtocol.responses[inquiryPath] = .failure(URLError(.notConnectedToInternet))
        let reader = makeReader()
        let observer = RecordingObserver()
        reader.requestObserver = observer

        do {
            _ = try await inquire(reader)
            XCTFail("Expected transactionInquiry() to throw")
        } catch is FiservTTPCardReaderError {
        }

        XCTAssertEqual(observer.willSend.count, 1)
        XCTAssertEqual(observer.completed.count, 1)
        let completed = try XCTUnwrap(observer.completed.first)
        XCTAssertNil(completed.response)
        XCTAssertEqual((completed.error as? URLError)?.code, .notConnectedToInternet)
    }

    func testObserverIsWeak() async throws {
        ObserverStubProtocol.responses[inquiryPath] = .success((200, "[]"))
        let reader = makeReader()
        weak var weakObserver: RecordingObserver?
        do {
            let observer = RecordingObserver()
            weakObserver = observer
            reader.requestObserver = observer
        }

        XCTAssertNil(weakObserver)
        XCTAssertNil(reader.requestObserver)

        _ = try await inquire(reader)

        XCTAssertNil(weakObserver)
    }

    func testNoObserverIsFine() async throws {
        ObserverStubProtocol.responses[inquiryPath] = .success((200, "[]"))
        let reader = makeReader()

        let response = try await inquire(reader)

        XCTAssertTrue(response.isEmpty)
    }

    // MARK: - Helpers

    private func makeReader() -> FiservTTPCardReader {
        let config = FiservTTPConfig(secretKey: "secret",
                                     apiKey: "apikey",
                                     environment: .Sandbox,
                                     currencyCode: "USD",
                                     merchantId: "MID",
                                     merchantName: "Test",
                                     merchantCategoryCode: "5999",
                                     terminalId: "TID",
                                     terminalProfileId: "PROFILE")
        return FiservTTPCardReader(configuration: config)
    }

    private func inquire(_ reader: FiservTTPCardReader) async throws -> [Models.InquireResponse] {
        try await reader.transactionInquiry(clientRequestId: clientRequestId,
                                            referenceTransactionDetailsRequest: .init(referenceTransactionId: "TXN-ID"))
    }
}

// MARK: - Observer

private final class RecordingObserver: FiservTTPRequestObserver {

    struct Completion {
        let request: URLRequest
        let response: URLResponse?
        let data: Data?
        let error: Error?
    }

    private let lock = NSLock()
    private var _willSend: [URLRequest] = []
    private var _completed: [Completion] = []

    var willSend: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return _willSend
    }

    var completed: [Completion] {
        lock.lock(); defer { lock.unlock() }
        return _completed
    }

    func fiservTTP(willSend request: URLRequest) {
        lock.lock(); defer { lock.unlock() }
        _willSend.append(request)
    }

    func fiservTTP(didComplete request: URLRequest, response: URLResponse?, data: Data?, error: Error?) {
        lock.lock(); defer { lock.unlock() }
        _completed.append(Completion(request: request, response: response, data: data, error: error))
    }
}

// MARK: - Stub

final class ObserverStubProtocol: URLProtocol {

    private static let lock = NSLock()
    private static var _responses: [String: Result<(Int, String), Error>] = [:]

    static var responses: [String: Result<(Int, String), Error>] {
        get { lock.lock(); defer { lock.unlock() }; return _responses }
        set { lock.lock(); defer { lock.unlock() }; _responses = newValue }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        switch Self.responses[request.url?.path ?? ""] {
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
}

extension URLSessionConfiguration {

    /// Exchanges `defaultSessionConfiguration` with `observerStub_defaultSessionConfiguration`.
    /// Calling it a second time restores the previous implementation.
    static func toggleObserverStub() {
        let original = class_getClassMethod(URLSessionConfiguration.self, NSSelectorFromString("defaultSessionConfiguration"))!
        let replacement = class_getClassMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration.observerStub_defaultSessionConfiguration))!
        method_exchangeImplementations(original, replacement)
    }

    @objc class func observerStub_defaultSessionConfiguration() -> URLSessionConfiguration {
        let configuration = observerStub_defaultSessionConfiguration() // swapped: calls the original
        configuration.protocolClasses = [ObserverStubProtocol.self] + (configuration.protocolClasses ?? [])
        return configuration
    }
}
