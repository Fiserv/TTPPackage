//  FiservTTP
//
//  Copyright (c) 2022 - 2025 Fiserv, Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation

/// Observes the Commerce Hub requests sent by a `FiservTTPCardReader`, for example to log them.
///
/// Set an observer on `FiservTTPCardReader.requestObserver`. For each request, `fiservTTP(willSend:)` is called once
/// with the fully built request immediately before it is sent, and `fiservTTP(didComplete:response:data:error:)` is
/// called exactly once when it finishes, whether it succeeded, returned an HTTP error status, or failed in transport.
/// This includes the cancel requests sent by a timeout reversal.
///
/// - Important: Requests include the `Api-Key` and `Authorization` headers. Redact them before persisting or
/// transmitting any logs.
///
/// - Note: Callbacks are made synchronously on whatever thread or task the SDK sends the request from. They are not
/// dispatched to the main queue, so hop to it yourself before updating UI, and avoid blocking work in them.
///
/// Both methods have empty default implementations, so implement only the ones you need.
///
public protocol FiservTTPRequestObserver: AnyObject {

    /// Called immediately before `request` is sent.
    ///
    /// - Parameter request: The request as it will be sent, including its headers and body.
    ///
    func fiservTTP(willSend request: URLRequest)

    /// Called once after `request` has finished, on every outcome.
    ///
    /// - Parameters:
    ///   - request: The request that was sent.
    ///   - response: The response, or nil if none was received.
    ///   - data: The response body, or nil if none was received.
    ///   - error: The error if the request failed in transport (for example a timeout), otherwise nil.
    ///     An HTTP error status is reported through `response`, not `error`.
    ///
    func fiservTTP(didComplete request: URLRequest, response: URLResponse?, data: Data?, error: Error?)
}

extension FiservTTPRequestObserver {

    public func fiservTTP(willSend request: URLRequest) {}

    public func fiservTTP(didComplete request: URLRequest, response: URLResponse?, data: Data?, error: Error?) {}
}
