import XCTest
import ObjectiveC
@testable import FiservTTP

/// When a Tap to Pay step that uses the session token fails, the next isAccountLinked(), linkAccount() or
/// initializeSession() must request a new token instead of retrying with the same one.
///
/// The reader is finalized so each Tap to Pay step fails immediately and the same way on any simulator.
/// Token requests are counted with a stub URLProtocol, installed by swizzling
/// +[NSURLSessionConfiguration defaultSessionConfiguration], so no production code needs a test seam.
@available(iOS 18, *)
final class TokenRefreshAfterFailureTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        URLSessionConfiguration.swapTokenStub()
    }

    override class func tearDown() {
        URLSessionConfiguration.swapTokenStub()
        super.tearDown()
    }

    override func setUp() {
        super.setUp()
        TokenStubProtocol.reset()
    }

    func testFailedInitializeSessionRequestsNewTokenOnRetry() async throws {
        let reader = try await makeReaderWithToken()

        await XCTAssertThrowsAsync(try await reader.initializeSession())
        XCTAssertEqual(TokenStubProtocol.tokenRequestCount, 1, "a fresh token must not be requested again")

        await XCTAssertThrowsAsync(try await reader.initializeSession())
        XCTAssertEqual(TokenStubProtocol.tokenRequestCount, 2)
    }

    func testFailedLinkAccountRequestsNewTokenOnRetry() async throws {
        let reader = try await makeReaderWithToken()

        await XCTAssertThrowsAsync(try await reader.linkAccount())
        XCTAssertEqual(TokenStubProtocol.tokenRequestCount, 1, "a fresh token must not be requested again")

        await XCTAssertThrowsAsync(try await reader.linkAccount())
        XCTAssertEqual(TokenStubProtocol.tokenRequestCount, 2)
    }

    func testFailedIsAccountLinkedRequestsNewTokenOnRetry() async throws {
        let reader = try await makeReaderWithToken()

        await XCTAssertThrowsAsync(try await reader.isAccountLinked())
        XCTAssertEqual(TokenStubProtocol.tokenRequestCount, 1, "a fresh token must not be requested again")

        await XCTAssertThrowsAsync(try await reader.isAccountLinked())
        XCTAssertEqual(TokenStubProtocol.tokenRequestCount, 2)
    }

    func testFailedLinkAccountRequestsNewTokenOnNextInitializeSession() async throws {
        let reader = try await makeReaderWithToken()

        await XCTAssertThrowsAsync(try await reader.linkAccount())
        await XCTAssertThrowsAsync(try await reader.initializeSession())

        XCTAssertEqual(TokenStubProtocol.tokenRequestCount, 2)
    }

    // MARK: - Helpers

    private func makeReaderWithToken() async throws -> FiservTTPCardReader {
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
        reader.finalize()
        try await reader.requestSessionToken(clientRequestId: UUID().uuidString)
        XCTAssertEqual(TokenStubProtocol.tokenRequestCount, 1)
        return reader
    }

    private func XCTAssertThrowsAsync(_ expression: @autoclosure () async throws -> some Any,
                                      file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await expression()
            XCTFail("Expected an error", file: file, line: line)
        } catch {}
    }
}

// MARK: - Stub

/// Answers the token request with a token that expires in 48 hours, and counts how many were made.
final class TokenStubProtocol: URLProtocol {

    private static let lock = NSLock()
    private static var _tokenRequestCount = 0

    static var tokenRequestCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _tokenRequestCount
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        _tokenRequestCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard request.url?.path == "/ch/security/v1/ttpcredentials" else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        Self.lock.lock()
        Self._tokenRequestCount += 1
        Self.lock.unlock()

        let json = """
            {"gatewayResponse":{},"accessToken":"\(Self.jwt(expiresIn: 172800))","accessTokenTimeToLive":172800,"accessTokenType":"JWT"}
            """
        let http = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil,
                                   headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func jwt(expiresIn seconds: TimeInterval) -> String {
        func base64URL(_ json: String) -> String {
            Data(json.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let exp = Int(Date().timeIntervalSince1970 + seconds)
        return "\(base64URL(#"{"alg":"none"}"#)).\(base64URL("{\"exp\":\(exp)}")).signature"
    }
}

extension URLSessionConfiguration {

    /// Swaps defaultSessionConfiguration with a version that installs TokenStubProtocol. Calling it again restores it.
    static func swapTokenStub() {
        let original = class_getClassMethod(URLSessionConfiguration.self, NSSelectorFromString("defaultSessionConfiguration"))!
        let replacement = class_getClassMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration.tokenStub_defaultSessionConfiguration))!
        method_exchangeImplementations(original, replacement)
    }

    @objc class func tokenStub_defaultSessionConfiguration() -> URLSessionConfiguration {
        let configuration = tokenStub_defaultSessionConfiguration() // swapped: calls the original
        configuration.protocolClasses = [TokenStubProtocol.self] + (configuration.protocolClasses ?? [])
        return configuration
    }
}
