import XCTest
@testable import FiservTTP

final class ErrorDescriptionTests: XCTestCase {

    func testCommerceHubErrorBodyIsIncluded() {
        let body = """
            {"gatewayResponse":{"transactionType":"CANCEL","transactionState":"DECLINED"},
             "error":[{"type":"GATEWAY","code":"887","message":"Voiding of Returned Transactions is Not Supported"}]}
            """
        let error = FiservTTPRequestError(message: "Bad Request.", code: 400, failureReason: body)
        XCTAssertEqual(error.errorDescription, "Bad Request. Voiding of Returned Transactions is Not Supported (887)")
        XCTAssertEqual(error.localizedDescription, error.errorDescription)
    }

    func testErrorWithoutCodeShowsMessageOnly() {
        let body = #"{"gatewayResponse":{},"error":[{"message":"Invalid request"}]}"#
        let error = FiservTTPRequestError(message: "Bad Request.", code: 400, failureReason: body)
        XCTAssertEqual(error.errorDescription, "Bad Request. Invalid request")
    }

    func testUnrecognizedBodyFallsBackToMessage() {
        let error = FiservTTPRequestError(message: "Server Error", code: 502, failureReason: "<html>Bad Gateway</html>")
        XCTAssertEqual(error.errorDescription, "Server Error")
    }

    func testTransportErrorIsUnchanged() {
        let error = FiservTTPRequestError(message: "Request timed out",
                                          code: URLError.timedOut.rawValue,
                                          failureReason: "The request timed out.")
        XCTAssertEqual(error.errorDescription, "Request timed out")
    }
}
