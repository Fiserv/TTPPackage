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
import Combine
import ProximityReader
import Network

public enum PaymentTransactionEventType: Codable {
    case none
    case cancelPendngNetworkAvailability
    case cancelRequested
}

extension PaymentTransactionEventType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .none:
            return "none"
        case .cancelPendngNetworkAvailability:
            return "cancelPendngNetworkAvailability"
        case .cancelRequested:
            return "cancelRequested"
        }}
}

public struct PaymentTransactionStatus: Codable {
    
    public let eventType: PaymentTransactionEventType
    public let transactionType: PaymentTransactionType
    public let refundTransactionType: RefundTransactionType
    public let attempt: Int
    public let description: String
    
    public init(eventType: PaymentTransactionEventType, transactionType: PaymentTransactionType, refundTransactionType: RefundTransactionType, attempt: Int, description: String) {
        self.eventType = eventType
        self.transactionType = transactionType
        self.refundTransactionType = refundTransactionType
        self.attempt = attempt
        self.description = description
    }
}

public enum PaymentTransactionType: Codable {
    case none
    case sale
    case auth
    case capture
    case paymentToken
}

extension PaymentTransactionType: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .none:
            return "none"
        case .sale:
            return "sale"
        case .auth:
            return "auth"
        case .capture:
            return "capture"
        case .paymentToken:
            return "paymentToken"
        }
    }
}

public enum RefundTransactionType: Codable {
    case none
    case matched
    case unmatched
    case open
}

extension RefundTransactionType: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .none:
            return "none"
        case .open:
            return "open"
        case .matched:
            return "tagged"
        case .unmatched:
            return "unmatched"
        }
    }
}

public struct FiservTTPCardReaderError: Error {
    
    public let title: String
    public let localizedDescription: String
    public let failureReason: String?
    
    public init(title: String, localizedDescription: String, failureReason: String? = nil) {
        self.title = title
        self.localizedDescription = localizedDescription
        self.failureReason = failureReason
    }
}

public class FiservTTPCardReader {
    
    private let configuration: FiservTTPConfig
    
    private let services: FiservTTPServices
    
    private var fiservTTPReader: FiservTTPReader
    
    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "NWPathMonitor")
    
    private var token: String?
    
    private var tokenExp: Double = 0.0
    
    private var networkReady: Bool = false
    
    public var sessionReadySubject: PassthroughSubject<Bool, Never> = .init()
    
    public var networkReadySubject: PassthroughSubject<Bool, Never> = .init()
    
    public var transactionStatusSubject: PassthroughSubject<PaymentTransactionStatus, Never> = .init()
    
    /// Creates an instance of FiservTTPCardReader
    ///
    /// This class should be created and owned by your view model. All necessary functions needed to initialize a Tap To Pay Session
    /// and accept a payment are exposed within this class.
    ///
    /// Public methods marked as throw will only ever throw a FiservTTPCardReaderError,
    /// helping to reduce the types of errors you would need to handle.
    ///
    /// - Parameter configuration: FiservTTPConfig
    ///
    /// - Returns: FiservTTPCardReader
    ///
    public init(configuration: FiservTTPConfig) {
        self.configuration = configuration
        self.fiservTTPReader = FiservTTPReader(config: configuration)
        self.services = FiservTTPServices(config: configuration)
        
        self.pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.networkReady = (path.status == .satisfied)
                self?.networkReadySubject.send(path.status == .satisfied)
            }
        }
        self.pathMonitor.start(queue: self.pathMonitorQueue)
    }
    
    // MARK: - Transaction Serialization
    //
    // Only one transaction may be in flight at a time. A new transaction can begin
    // only after the previous one has thrown an error, or returned a success or
    // failure response. This prevents a second transaction from starting while an
    // earlier one is still waiting on an http response due to network latency.
    //
    // Because `acquire()` and `release()` contain no suspension points (no `await`),
    // the actor guarantees the check-and-set executes atomically. This avoids the
    // reentrancy hazard that a plain actor method spanning an `await` would have,
    // where another task could interleave while the first is suspended.
    
    private actor TransactionSerializer {
        
        private var transactionInProgress = false
        
        func acquire() throws {
            guard !transactionInProgress else {
                throw FiservTTPCardReaderError(title: "Transaction In Progress",
                                               localizedDescription: NSLocalizedString("A transaction is already in progress. Only one transaction may be processed at a time.", comment: ""))
            }
            transactionInProgress = true
        }
        
        func release() {
            transactionInProgress = false
        }
    }
    
    private let transactionSerializer = TransactionSerializer()
    
    /// Runs `operation` with exclusive access so that transactions are processed one at a time.
    ///
    /// A new transaction may only begin once the previous transaction has thrown an error,
    /// or returned a success or failure response. A concurrent attempt throws a `FiservTTPCardReaderError`.
    ///
    /// - Parameter operation: The transaction work to perform exclusively.
    /// - Returns: The value produced by `operation`.
    /// - Throws: A `FiservTTPCardReaderError` if a transaction is already in progress, or any error thrown by `operation`.
    private func withExclusiveTransaction<T>(_ operation: () async throws -> T) async throws -> T {
        
        try await transactionSerializer.acquire()
        
        do {
            let result = try await operation()
            await transactionSerializer.release()
            return result
        } catch {
            await transactionSerializer.release()
            throw error
        }
    }
    
    /// When you are finished taking payments, you can deallocate the reader
    ///
    /// - Important: Never call `finalize()`, this will potentially require an app restart and is provided here for completeness
    public func finalize() {
        self.fiservTTPReader.finalize()
    }
    
    public func readerIsSupported() -> Bool {
        return self.fiservTTPReader.readerIsSupported()
    }
    
    /// Request a session token.
    ///
    /// This is the first step required to begin taking payments.
    ///
    /// - Parameters:
    ///   - ClientRequestId
    /// - Returns:
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    public func requestSessionToken(clientRequestId: String) async throws {
            
        let title = "Token Request"
        
        let result = await services.requestSessionToken(clientRequestId: clientRequestId)
        
        self.token = nil
        
        self.tokenExp = 0
        
        do {
            
            let jwtToken = try result.get().accessToken
            
            let tokenExpiration = try decode(jwtToken: jwtToken)["exp"] as? TimeInterval
            
            self.tokenExp = tokenExpiration ?? 0
            
            self.token = jwtToken
            
        } catch {
            
            if let err = error as? FiservTTPRequestError {
                
                throw FiservTTPCardReaderError(title: title,
                                               localizedDescription: err.localizedDescription,
                                               failureReason: err.failureReason)
            } else {
                
                throw FiservTTPCardReaderError(title: title,
                                               localizedDescription: NSLocalizedString("Unable to request a session token.", comment: ""))
            }
        }
    }
    
    /// A Boolean value that indicates whether the account is already linked.
    ///
    /// Call linkAccount(using:)  to link an account.
    ///
    /// If PaymentCardReader/prepare(using:) throws an PaymentCardReaderError/accountNotLinked error
    /// call linkAccount(using:) again to relink the account.
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    public func isAccountLinked() async throws -> Bool {
        
        if let token = self.token {
            
            return try await self.fiservTTPReader.isAccountLinked(token: token)
            
        } else {
            
            throw FiservTTPCardReaderError(title: "Missing Token",
                                           localizedDescription: NSLocalizedString("Unable to link this account, a token is required.", comment: ""))
        }
    }
    
    /// Presents a sheet for the merchant to accept Tap to Pay on iPhone’s Terms and Conditions on a device.
    ///
    /// To use Tap to Pay on iPhone, your participating payment service provider must provide the merchant using your app with a secure token.
    /// This token contains an unique identifier for each merchant.
    /// This merchant must accept Tap to Pay on iPhone’s Terms and Conditions.
    /// After a merchant accepts the Terms and Conditions for their specific merchant identifier on one device,
    /// they don’t need to accept it again on additional devices that use the same identifier.
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    public func linkAccount() async throws {
        
        if let token = self.token {
            
            try await self.fiservTTPReader.linkAccount(token: token)
            
        } else {
            
            throw FiservTTPCardReaderError(title: "Missing Token",
                                           localizedDescription: NSLocalizedString("Unable to link this account, a token is required.", comment: ""))
        }
    }
    
    /// Initialize a Card Reader Session
    ///
    /// A Card Reader Session was created for you when using initializeDevice(), however, if your application becomes inactive,
    /// the session will need to be re-initialized when your application becomes active again.
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    public func initializeSession() async throws {
            
        if self.token != nil {
            
            // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            // Check CommerceHub Token Expiration
            // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            let timestamp = Date().timeIntervalSince1970
            
            if self.tokenExp - timestamp < 1800 { // 30 minutes
                
                try await requestSessionToken(clientRequestId: UUID().uuidString)   // Auto Refresh
            }
            
        } else {
            
            throw FiservTTPCardReaderError(title: "Missing Token",
                                           localizedDescription: NSLocalizedString("Unable to initialize the session, a token is required.", comment: ""))
        }
        
        if let token = self.token {
            
            try await self.fiservTTPReader.initializeSession(token: token, eventHandler: { event in
                
                if event == "notReady" {
                    self.sessionReadySubject.send(false)
                }
            })
            
            self.sessionReadySubject.send(true)
            
        } else {

            throw FiservTTPCardReaderError(title: "Missing Token",
                                           localizedDescription: NSLocalizedString("Unable to initialize the session, a token is required.", comment: ""))
        }
    }
    
    /// A request to verify details for a contactless payment card.
    ///
    /// This method verifies that a card can be read and does not charge or approve the card for any  amount
    ///
    /// - Returns:FiservTTPValidateCardResponse
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    public func validateCard() async throws -> FiservTTPValidateCardResponse {
        return try await withExclusiveTransaction {
            try await self.validateCardImpl()
        }
    }
    
    private func validateCardImpl() async throws -> FiservTTPValidateCardResponse {
        
        let title = "Validate Payment Card"
        
        guard let _ = try await self.fiservTTPReader.readerIdentifier() else {
                    
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: NSLocalizedString("Payment Card Reader not identified.", comment: ""))
        }
        
        return try await self.fiservTTPReader.validateCard(currencyCode: self.configuration.currencyCode)
        
    }
    
    /// Use this method to perform an **Account Verification**. This will check the validity and respond if an account is valid or not
    ///
    /// - Parameters:
    ///   - ClientRequestId
    ///   - Models.TransactionDetailsRequest
    ///   - Models.BillingAddressRequest
    ///
    /// - Returns:Models.AccountVerificationResponse
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    /// - SeeAlso: [Commerce Hub Verification](https://developer.fiserv.com/product/CommerceHub/api/?type=post&path=/payments-vas/v1/accounts/verification)
    ///
    public func accountVerification(clientRequestId: String,
                                    transactionDetailsRequest: Models.TransactionDetailsRequest,
                                    paymentTokenSourceRequest: Models.PaymentTokenSourceRequest? = nil,
                                        billingAddressRequest: Models.BillingAddressRequest? = nil) async throws -> Models.AccountVerificationResponse {
        return try await withExclusiveTransaction {
            try await self.accountVerificationImpl(clientRequestId: clientRequestId,
                                                   transactionDetailsRequest: transactionDetailsRequest,
                                                   paymentTokenSourceRequest: paymentTokenSourceRequest,
                                                   billingAddressRequest: billingAddressRequest)
        }
    }
    
    private func accountVerificationImpl(clientRequestId: String,
                                    transactionDetailsRequest: Models.TransactionDetailsRequest,
                                    paymentTokenSourceRequest: Models.PaymentTokenSourceRequest? = nil,
                                        billingAddressRequest: Models.BillingAddressRequest? = nil) async throws -> Models.AccountVerificationResponse {
        
        let title = "Account Verification"
        
        // Card Reader Identifier
        var cardReaderIdentifier: String?
        
        // Card Verification
        var cardVerificationResponse: Models.CardVerificationResponse?
        
        // Support Account Verification using Payment Token - nil Payment Token requires card read
        if paymentTokenSourceRequest == nil {
            
            // Confirm Card Reader Identifier
            guard let readerIdentifier = try await self.fiservTTPReader.readerIdentifier() else {
                        
                throw FiservTTPCardReaderError(title: title,
                                               localizedDescription: NSLocalizedString("Payment Card Reader not identified.", comment: ""))
            }
            
            cardReaderIdentifier = readerIdentifier
            
            // Read Card
            let response = try await self.fiservTTPReader.validateCard(currencyCode: self.configuration.currencyCode, reason: .lookUp)
            
            guard let generalCardData = response.generalCardData, let paymentCardData = response.paymentCardData else {
            
                throw FiservTTPCardReaderError(title: title,
                                               localizedDescription: NSLocalizedString("Payment Card data missing or corrupt.", comment: ""))
            }
            
            cardVerificationResponse = Models.CardVerificationResponse(cardReaderId: readerIdentifier,
                                                                      transactionId: response.id,
                                                                    generalCardData: generalCardData,
                                                                    paymentCardData: paymentCardData)
        }
        
        let accountVerificationResult = await services.accountVerification(clientRequestId: clientRequestId,
                                                                           transactionDetails: transactionDetailsRequest,
                                                                           billingAddress: billingAddressRequest,
                                                                           paymentCardReaderId: cardReaderIdentifier,
                                                                           paymentTokenSourceRequest: paymentTokenSourceRequest,
                                                                           cardVerificationResponse: cardVerificationResponse)

        switch accountVerificationResult {
    
        case .success(let response):
            
            let sourceResponse = appendGeneralCardDataToSourceResponse(generalCardData: cardVerificationResponse?.generalCardData,
                                                                       response: response.source)
            
            let appendedResponse = Models.AccountVerificationResponse(gatewayResponse: response.gatewayResponse,
                                                                      processorResponseDetails: response.processorResponseDetails,
                                                                      source: sourceResponse,
                                                                      billingAddress: response.billingAddress,
                                                                      transactionDetails: response.transactionDetails,
                                                                      transactionInteraction: response.transactionInteraction,
                                                                      merchantDetails: response.merchantDetails,
                                                                      paymentTokens: response.paymentTokens,
                                                                      error: response.error)
            return appendedResponse
    
        case .failure(let err):

            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: err.errorDescription ?? "",
                                           failureReason: err.failureReason)
        }
    }
    
    /// Use this payload to create a **Payment token** from a payment source.
    ///
    /// - Parameters:
    ///    - ClientRequestId
    ///    - Models.TransactionDetailsRequest
    ///
    /// - Returns: Models.TokenizeCardResponse
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    /// - SeeAlso: [Commerce Hub Tokenization](https://developer.fiserv.com/product/CommerceHub/api/?type=post&path=/payments-vas/v1/tokens)
    ///
    public func tokenizeCard(clientRequestId: String,
                             transactionDetailsRequest: Models.TransactionDetailsRequest) async throws -> Models.TokenizeCardResponse {
        return try await withExclusiveTransaction {
            try await self.tokenizeCardImpl(clientRequestId: clientRequestId,
                                            transactionDetailsRequest: transactionDetailsRequest)
        }
    }
    
    private func tokenizeCardImpl(clientRequestId: String,
                             transactionDetailsRequest: Models.TransactionDetailsRequest) async throws -> Models.TokenizeCardResponse {
        
        let title = "Tokenize Card"
        
        guard let readerIdentifier = try await self.fiservTTPReader.readerIdentifier() else {
                    
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: NSLocalizedString("Payment Card Reader not identified.", comment: ""))
        }
        
        let response = try await self.fiservTTPReader.validateCard(currencyCode: self.configuration.currencyCode,
                                                                               reason: .lookUp)
        
        guard let generalCardData = response.generalCardData, let paymentCardData = response.paymentCardData else {
        
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: NSLocalizedString("Payment Card data missing or corrupt.", comment: ""))
        }
        
        let verificationResponse = Models.CardVerificationResponse(cardReaderId: readerIdentifier,
                                                                   transactionId: response.id,
                                                                   generalCardData: generalCardData,
                                                                   paymentCardData: paymentCardData)
        
        let tokenizeResult = await services.tokenize(clientRequestId: clientRequestId,
                                                     transationDetails: transactionDetailsRequest,
                                                     cardVerificationResponse: verificationResponse)
    
        switch tokenizeResult {
    
        case .success(let response):
            
            let sourceResponse = appendGeneralCardDataToSourceResponse(generalCardData: generalCardData,
                                                                       response: response.source)
            
            let appendedResponse = Models.TokenizeCardResponse(gatewayResponse: response.gatewayResponse,
                                                               source: sourceResponse,
                                                               paymentTokens: response.paymentTokens,
                                                               cardDetails: response.cardDetails,
                                                               processorResponseDetails: response.processorResponseDetails,
                                                               error: response.error)
            return appendedResponse
    
        case .failure(let err):
            
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: err.errorDescription ?? "",
                                           failureReason: err.failureReason)
        }
    }
    
    /// Use this method to return a **Commerce Hub transaction(s)** and their attributes based on order identifier.
    ///
    /// - Parameters:
    ///    - ClientRequestId
    ///    - Models.ReferenceTransactionDetailsRequest
    ///
    /// - Returns: Models.InquireResponse
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    /// - SeeAlso: [Commerce Hub Inquiry](https://developer.fiserv.com/product/CommerceHub/api/?type=post&path=/payments/v1/transaction-inquiry)
    ///
    public func transactionInquiry(clientRequestId: String,
                                   referenceTransactionDetailsRequest: Models.ReferenceTransactionDetailsRequest) async throws -> [Models.InquireResponse] {
        return try await withExclusiveTransaction {
            try await self.transactionInquiryImpl(clientRequestId: clientRequestId,
                                                  referenceTransactionDetailsRequest: referenceTransactionDetailsRequest)
        }
    }
    
    private func transactionInquiryImpl(clientRequestId: String,
                                   referenceTransactionDetailsRequest: Models.ReferenceTransactionDetailsRequest) async throws -> [Models.InquireResponse] {
        
        let title = "Transaction Inquiry"
        
        let merchantDetails = Models.MerchantDetailsRequest(merchantId: self.configuration.merchantId,
                                                            terminalId: self.configuration.terminalId)
        
        let inquireRequest = Models.TransactionInquiryRequest(referenceTransactionDetails: referenceTransactionDetailsRequest,
                                                              merchantDetails: merchantDetails)
        
        let inquireResult = await services.transactionInquiry(clientRequestId: clientRequestId,
                                                              inquireRequest: inquireRequest)
        
        switch inquireResult {
            
        case .success(let response):
            
            return response
            
        case .failure(let err):
            
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: err.localizedDescription,
                                           failureReason: err.failureReason)
        }
    }

    // TRANS TYPE           CAP FLAG        READ CARD       CREATE TOKEN
    //
    // USE PAY_TOKEN        TRUE            FALSE           FALSE
    //
    // AUTH                 FALSE           TRUE            FALSE
    //
    // CAPTURE              TRUE            FALSE           FALSE
    //
    // SALE                 TRUE            TRUE            FALSE
    
    // ADDITIONAL
    //
    // AUTH + CAPTURE == SALE
    // SALE == CURRENT SDK
    //
    // ARGS                            SALE     AUTH    CAPTURE   TOKEN
    //
    // READ CARD                        Y        Y         N        N
    // MERCHANT DETAILS                 Y        Y         Y        Y
    // CAPTURE FLAG                     T        F         T        T
    // TRANSACTION DETAILS              Y        Y         Y        Y
    // REFERENCE TRANSACTION DETAILS    N        N         O*       N
    
    // * OPTIONAL -> REFERENCE TRANSACTION DETAILS + CAPTURE (MUST BE FROM [PREVIOUS AUTH])
    
    // MERCHANT DETAILS    (merchantId, terminalId)
    // TRANSACTION DETAILS (merchantTransactionId, merchantOrderId, captureFlag)
    // REFERENCE TRANS DET (referenceTransactionId, referenceMerchantTransactionId, referenceOrderId, referenceMerchantOrderId, referenceClientRequestId)
    
    // * NOT USING Models.TransactionDetailsRequest because of captureFlag (so merchant won't make a mistake)
    
    /// Use this method to originate a **Financial transaction** based on the captureFlag * Pre-Auth = false * Sale = true * Capture = true with a transaction identifier
    ///
    /// - Parameters:
    ///   - ClientRequestId
    ///   - Amount
    ///   - PaymentTransactionType
    ///   - Models.TransactionDetailsRequest
    ///   - Models.ReferenceTransactionDetailsRequest
    ///   - Models.PaymentTokenSourceRequest
    ///
    /// - Returns: Models.CommerceHubResponse
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    /// - SeeAlso: [Commerce Hub Charges](https://developer.fiserv.com/product/CommerceHub/api/?type=post&path=/payments/v1/charges)
    ///
    public func charges(clientRequestId: String,
                        amount: Decimal,
                        transactionType: PaymentTransactionType,
                        transactionDetailsRequest: Models.TransactionDetailsRequest,
                        referenceTransactionDetailsRequest: Models.ReferenceTransactionDetailsRequest? = nil,
                        paymentTokenSourceRequest: Models.PaymentTokenSourceRequest? = nil) async throws -> Models.CommerceHubResponse {
        return try await withExclusiveTransaction {
            try await self.chargesImpl(clientRequestId: clientRequestId,
                                       amount: amount,
                                       transactionType: transactionType,
                                       transactionDetailsRequest: transactionDetailsRequest,
                                       referenceTransactionDetailsRequest: referenceTransactionDetailsRequest,
                                       paymentTokenSourceRequest: paymentTokenSourceRequest)
        }
    }
    
    private func chargesImpl(clientRequestId: String,
                        amount: Decimal,
                        transactionType: PaymentTransactionType,
                        transactionDetailsRequest: Models.TransactionDetailsRequest,
                        referenceTransactionDetailsRequest: Models.ReferenceTransactionDetailsRequest? = nil,
                        paymentTokenSourceRequest: Models.PaymentTokenSourceRequest? = nil) async throws -> Models.CommerceHubResponse {
        
        let title = "Charges"
        
        var cardReadResult: PaymentCardReadResult?
        
        var cardVerificationResponse: Models.CardVerificationResponse?
        
        var paymentTokenChargeRequest: Models.PaymentTokenChargeRequest?
        
        var requiresCardRead = false
        
        // Transaction Details Request - At Least One Reference Value Must be Provided to Support Time Out Reversals via CANCEL
        if !transactionDetailsRequest.isValid {
        
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: NSLocalizedString("At least one value must be non nil and non zero length in the Transaction Details Request.", comment: ""))
        }
        
        if transactionType == PaymentTransactionType.capture {
            
            if referenceTransactionDetailsRequest?.isValid == false {
            
                throw FiservTTPCardReaderError(title: title,
                                               localizedDescription: NSLocalizedString("At least one value must be non nil and non zero length in the Reference Transaction Details Request.", comment: ""))
            }
        }
        
        // AUTH using PAYMENT TOKEN - No Card Read, No Capture
        
        // AUTH - NO PAYMENT TOKEN
        if paymentTokenSourceRequest == nil && transactionType == PaymentTransactionType.auth {
            
            // Requires CARD READ, No CAPTURE
            requiresCardRead = true
        }
        
        // SALE using PAYMENT TOKEN - No Card Read

        // SALE - NO PAYMENT TOKEN
        if paymentTokenSourceRequest == nil && transactionType == PaymentTransactionType.sale {
            
            requiresCardRead = true
        }
        
        if transactionType != PaymentTransactionType.auth && transactionDetailsRequest.captureFlag == false {
            
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: NSLocalizedString("Invalid value for captureFlag, expected TRUE.", comment: ""))
        }
        
        if transactionType == PaymentTransactionType.auth && transactionDetailsRequest.captureFlag == true {
            
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: NSLocalizedString("Invalid value for captureFlag, expected FALSE for PaymentTransactionType.auth.", comment: ""))
        }
        
        // [AUTH (No Token), SALE] -> REQUIRES CARD READ
        if requiresCardRead {
            
            // 1) CONFIRM CARD READER IDENTIFIER
            guard let readerIdentifier = try await self.fiservTTPReader.readerIdentifier() else {
                        
                throw FiservTTPCardReaderError(title: title,
                                               localizedDescription: NSLocalizedString("Payment Card Reader not identified.", comment: ""))
            }
            
            // 2) READ CARD
            let result = try await self.fiservTTPReader.readCard(for: amount,
                                                                 currencyCode: self.configuration.currencyCode,
                                                                 transactionType: .purchase,
                                                                 eventHandler: { _ in
            })
            
            // 3) GET READ RESULT
            do {
                cardReadResult = try result.get()
            } catch {
                throw FiservTTPCardReaderError(title: title, localizedDescription: error.localizedDescription)
            }
            
            guard let generalCardData = cardReadResult?.generalCardData,
                  let paymentCardData = cardReadResult?.paymentCardData,
                  let transactionId = cardReadResult?.id else {
            
                throw FiservTTPCardReaderError(title: title,
                                               localizedDescription: NSLocalizedString("Payment Card data missing or corrupt.", comment: ""))
            }
            
            cardVerificationResponse = Models.CardVerificationResponse(cardReaderId: readerIdentifier,
                                                                       transactionId: transactionId,
                                                                       generalCardData: generalCardData,
                                                                       paymentCardData: paymentCardData)
        }
        
        // AMOUNT
        let amountRequest = Models.AmountRequest(total: amount, currency: self.configuration.currencyCode)
        
        // (SALE, AUTH, CAPTURE, TOKEN)
        let merchantDetailsRequest = Models.MerchantDetailsRequest(merchantId: self.configuration.merchantId,
                                                                   terminalId: self.configuration.terminalId)
        
        if transactionType == .paymentToken || (transactionType == .auth && paymentTokenSourceRequest != nil) {
            
            let posFeaturesRequest = Models.PosFeaturesRequest(pinAuthenticationCapability: "UNSPECIFIED", terminalEntryCapability: "MANUAL_ONLY")

            let posHardwareAndSoftwareRequest = Models.PosHardwareAndSoftwareRequest(softwareApplicationName: self.services.app_name,
                                                                                     softwareVersionNumber: self.services.app_version,
                                                                                     hardwareVendorIdentifier: self.services.vendorId)
            
            let additionalPosInformationRequest = Models.DataEntrySourceRequest(dataEntrySource: "MOBILE_TERMINAL",
                                                                                posFeatures: posFeaturesRequest,
                                                                                posHardwareAndSoftware: posHardwareAndSoftwareRequest)
            
            let transactionInteractionRequest = Models.TransactionInteractionRequest(origin: "POS",
                                                                                     posEntryMode: "MANUAL",
                                                                                     posConditionCode: "CARD_NOT_PRESENT_F2F",
                                                                                     additionalPosInformation: additionalPosInformationRequest)
            
            paymentTokenChargeRequest = Models.PaymentTokenChargeRequest(amount: amountRequest,
                                                                         source: paymentTokenSourceRequest,
                                                                         transactionDetails: transactionDetailsRequest,
                                                                         transactionInteraction: transactionInteractionRequest,
                                                                         merchantDetails: merchantDetailsRequest)
        }
        
        let chargesResponse = await self.services.charges(clientRequestId: clientRequestId,
                                                          amountRequest: amountRequest,
                                                          transactionDetailsRequest: transactionDetailsRequest,
                                                          referenceTransactionDetailsRequest: referenceTransactionDetailsRequest,
                                                          paymentTokenChargeRequest: paymentTokenChargeRequest,
                                                          cardVerificationResponse: cardVerificationResponse)
        
        
        switch chargesResponse {
        case .success(let response):
            
            if requiresCardRead {
                
                let sourceResponse = appendGeneralCardDataToSourceResponse(generalCardData: cardVerificationResponse?.generalCardData,
                                                                           response: response.source)
                let commerceHubResponse = Models.CommerceHubResponse(gatewayResponse: response.gatewayResponse,
                                                                     source: sourceResponse,
                                                                     paymentReceipt: response.paymentReceipt,
                                                                     transactionDetails: response.transactionDetails,
                                                                     transactionInteraction: response.transactionInteraction,
                                                                     merchantDetails: response.merchantDetails,
                                                                     networkDetails: response.networkDetails,
                                                                     cardDetails: response.cardDetails,
                                                                     paymentTokens: response.paymentTokens,
                                                                     error: response.error)
                
                return commerceHubResponse
                
            }
            
            return response
            
        case .failure(let err):
            
            if err.code == URLError.timedOut.rawValue {
                
                let result = try await timeoutReversal(clientRequestId: UUID().uuidString,
                                                       transactionType: transactionType,
                                                       refundTransactionType: .none,
                                                       amount: amount,
                                                       transactionDetailsRequest: transactionDetailsRequest,
                                                       referenceTransactionDetailsRequest: referenceTransactionDetailsRequest)
                
                return result
            }

            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: err.localizedDescription,
                                           failureReason: err.failureReason)
        }
    }
    
    /// Use this payload to perform a **Cancel** transaction (aka void).
    ///
    /// - Parameters:
    ///   - ClientRequestId
    ///   - Amount
    ///   - Models.ReferenceTransactionDetailsRequest
    ///
    /// - Returns: Models.CommerceHubResponse
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    /// - SeeAlso: [Commerce Hub Cancels](https://developer.fiserv.com/product/CommerceHub/api/?type=post&path=/payments/v1/cancels)
    ///
    public func cancels(clientRequestId: String,
                        amount: Decimal,
                        referenceTransactionDetailsRequest: Models.ReferenceTransactionDetailsRequest) async throws -> Models.CommerceHubResponse {
        return try await withExclusiveTransaction {
            try await self.cancelsImpl(clientRequestId: clientRequestId,
                                       amount: amount,
                                       referenceTransactionDetailsRequest: referenceTransactionDetailsRequest)
        }
    }
    
    private func cancelsImpl(clientRequestId: String,
                        amount: Decimal,
                        referenceTransactionDetailsRequest: Models.ReferenceTransactionDetailsRequest) async throws -> Models.CommerceHubResponse {
        
        let title = "Cancel Transaction"
        
        let amountRequest = Models.AmountRequest(total: amount, currency: self.configuration.currencyCode)
        
        let cancelResponse = await services.cancels(clientRequestId: clientRequestId,
                                                    amountRequest: amountRequest,
                                                    referenceTransactionDetailsRequest: referenceTransactionDetailsRequest)
        
        switch cancelResponse {
            
        case .success(let response):
            
            return response
        
        case .failure(let err):
            
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: err.localizedDescription,
                                           failureReason: err.failureReason)
        }
    }
    
    
    // ARGS                            MATCHED    UNMATCHED    OPEN
    //
    // READ CARD                        N           Y           Y
    // MERCHANT DETAILS                 Y           Y           Y
    // CAPTURE FLAG                     F           T           T
    // TRANSACTION DETAILS              N           Y           Y
    // REFERENCE TRANSACTION DETAILS    Y           Y           N
    
    /// Use this payload to perform a **Refund** transaction (aka void).
    ///
    /// - Parameters:
    ///   - ClientRequestId
    ///   - Amount
    ///   - RefundTransactionType
    ///   - Models.TransactionDetailsRequest
    ///   - Models.ReferenceTransactionDetailsRequest
    ///
    /// - Returns: Models.CommerceHubResponse
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    /// - SeeAlso: [Commerce Hub Refunds](https://developer.fiserv.com/product/CommerceHub/api/?type=post&path=/payments/v1/refunds)
    ///
    public func refunds(clientRequestId: String,
                        amount: Decimal,
                        refundTransactionType: RefundTransactionType,
                        transactionDetails: Models.TransactionDetailsRequest? = nil,
                        referenceTransactionDetails: Models.ReferenceTransactionDetailsRequest? = nil) async throws -> Models.CommerceHubResponse {
        return try await withExclusiveTransaction {
            try await self.refundsImpl(clientRequestId: clientRequestId,
                                       amount: amount,
                                       refundTransactionType: refundTransactionType,
                                       transactionDetails: transactionDetails,
                                       referenceTransactionDetails: referenceTransactionDetails)
        }
    }
    
    private func refundsImpl(clientRequestId: String,
                        amount: Decimal,
                        refundTransactionType: RefundTransactionType,
                        transactionDetails: Models.TransactionDetailsRequest? = nil,
                        referenceTransactionDetails: Models.ReferenceTransactionDetailsRequest? = nil) async throws -> Models.CommerceHubResponse {
        
        let title = "Refunds Transaction"
        
        var cardReadResult: PaymentCardReadResult?
        
        var cardVerificationResponse: Models.CardVerificationResponse?
        
        let requiresCardRead = (refundTransactionType != .matched)
        
        // MATCHED AND UNMATCHED REFUNDS REQUIRE REFERENCE TRANSACTION DETAILS
        if refundTransactionType == .matched || refundTransactionType == .unmatched {
            
            if referenceTransactionDetails?.isValid == false {
                
                throw FiservTTPCardReaderError(title: title,
                      localizedDescription: NSLocalizedString("At least one value must be non nil and non zero length in the Reference Transaction Details Request.", comment: ""))
            }
        }
        
        
        // UNMATCHED AND OPEN REFUNDS REQUIRE TRANSACTION DETAILS
        if refundTransactionType == .unmatched || refundTransactionType == .open {
            
            if transactionDetails?.isValid == false {

                throw FiservTTPCardReaderError(title: title,
                      localizedDescription: NSLocalizedString("At least one value must be non nil and non zero length in the Transaction Details Request.", comment: ""))
            }
        }
        
        if requiresCardRead {
            
            // 1) CONFIRM CARD READER IDENTIFIER
            guard let readerIdentifier = try await self.fiservTTPReader.readerIdentifier() else {
                        
                throw FiservTTPCardReaderError(title: title,
                                               localizedDescription: NSLocalizedString("Payment Card Reader not identified.", comment: ""))
            }
            
            // 2) READ CARD
            let result = try await self.fiservTTPReader.readCard(for: amount,
                                                                 currencyCode: self.configuration.currencyCode,
                                                                 transactionType: .purchase,
                                                                 eventHandler: { _ in
            })
            
            // 3) GET READ RESULT
            do {
                cardReadResult = try result.get()
            } catch {
                throw FiservTTPCardReaderError(title: title, localizedDescription: error.localizedDescription)
            }
        
            guard let generalCardData = cardReadResult?.generalCardData,
                  let paymentCardData = cardReadResult?.paymentCardData,
                  let transactionId = cardReadResult?.id else {
            
                throw FiservTTPCardReaderError(title: title,
                                               localizedDescription: NSLocalizedString("Payment Card data missing or corrupt.", comment: ""))
            }
            
            cardVerificationResponse = Models.CardVerificationResponse(cardReaderId: readerIdentifier,
                                                                       transactionId: transactionId,
                                                                       generalCardData: generalCardData,
                                                                       paymentCardData: paymentCardData)
        }
        
        let amountRequest = Models.AmountRequest(total: amount, currency: self.configuration.currencyCode)
        
        let refundsResponse = await self.services.refunds(clientRequestId: clientRequestId,
                                                          amountRequest: amountRequest,
                                                          transactionDetailsRequest: transactionDetails,
                                                          referenceTransactionDetailsRequest: referenceTransactionDetails,
                                                          cardVerificationResponse: cardVerificationResponse)
        
        switch refundsResponse {
            
        case .success(let response):
            
            if requiresCardRead {
                
                let sourceResponse = appendGeneralCardDataToSourceResponse(generalCardData: cardVerificationResponse?.generalCardData,
                                                                           response: response.source)
                let commerceHubResponse = Models.CommerceHubResponse(gatewayResponse: response.gatewayResponse,
                                                                     source: sourceResponse,
                                                                     paymentReceipt: response.paymentReceipt,
                                                                     transactionDetails: response.transactionDetails,
                                                                     transactionInteraction: response.transactionInteraction,
                                                                     merchantDetails: response.merchantDetails,
                                                                     networkDetails: response.networkDetails,
                                                                     cardDetails: response.cardDetails,
                                                                     paymentTokens: response.paymentTokens,
                                                                     error: response.error)
                return commerceHubResponse
            }
            
            return response
            
        case .failure(let err):
            
            if err.code == URLError.timedOut.rawValue {
                
                let result = try await timeoutReversal(clientRequestId: UUID().uuidString,
                                                       transactionType: .none,
                                                       refundTransactionType: refundTransactionType,
                                                       amount: amount,
                                                       transactionDetailsRequest: transactionDetails,
                                                       referenceTransactionDetailsRequest: referenceTransactionDetails)
                
                return result
            }
            
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: err.localizedDescription,
                                           failureReason: err.failureReason)
        }
    }
    
    internal func timeoutReversal(clientRequestId: String,
                                  transactionType: PaymentTransactionType,
                                  refundTransactionType: RefundTransactionType,
                                  amount: Decimal,
                                  transactionDetailsRequest: Models.TransactionDetailsRequest?,
                                  referenceTransactionDetailsRequest: Models.ReferenceTransactionDetailsRequest?) async throws -> Models.CommerceHubResponse {
        
        let title = "Timeout Reversal"
        
        for attempt in 1..<4 {
            
            if self.networkReady == true {
            
                let status = PaymentTransactionStatus(eventType: .cancelRequested,
                                                      transactionType: transactionType,
                                                      refundTransactionType: .none,
                                                      attempt: attempt,
                                                      description: "Cancel Requested - Attempt: \(attempt) of 3")
                
                self.transactionStatusSubject.send(status)
                
                let amountRequest = Models.AmountRequest(total: amount, currency: self.configuration.currencyCode)
                
                var referenceTransactionDetails = Models.ReferenceTransactionDetailsRequest.init(
                                                  referenceTransactionId: "",
                                                  referenceMerchantTransactionId: "",
                                                  referenceOrderId: "",
                                                  referenceMerchantOrderId: "")
                
                // CHARGES
                if refundTransactionType == .none {
            
                    referenceTransactionDetails = Models.ReferenceTransactionDetailsRequest.init(
                                                  referenceMerchantTransactionId: transactionDetailsRequest?.merchantTransactionId,
                                                  referenceMerchantOrderId: transactionDetailsRequest?.merchantOrderId)
                }
                
                // REFUNDS
                if transactionType == .none {
                    
                    referenceTransactionDetails = Models.ReferenceTransactionDetailsRequest.init(
                        referenceTransactionId: referenceTransactionDetailsRequest?.referenceTransactionId,
                        referenceMerchantTransactionId: referenceTransactionDetailsRequest?.referenceMerchantTransactionId,
                        referenceOrderId: referenceTransactionDetailsRequest?.referenceOrderId,
                        referenceMerchantOrderId: referenceTransactionDetailsRequest?.referenceMerchantOrderId)
                }
                
                let cancelResponse = await services.cancels(timeout: 10.0,
                                                            clientRequestId: clientRequestId,
                                                            amountRequest: amountRequest,
                                                            referenceTransactionDetailsRequest: referenceTransactionDetails)
                
                switch cancelResponse {
                    
                case .success(let response):

                    let status = PaymentTransactionStatus(eventType: .cancelRequested,
                                                          transactionType: transactionType,
                                                          refundTransactionType: .none,
                                                          attempt: attempt,
                                                          description: "")
                    self.transactionStatusSubject.send(status)
                    
                    return response

                case .failure(let err):
                    
                    // Only Timeout Error will keep us in the attempt loop
                    if err.code != URLError.timedOut.rawValue {
                        
                        let status = PaymentTransactionStatus(eventType: .cancelRequested,
                                                              transactionType: transactionType,
                                                              refundTransactionType: .none,
                                                              attempt: attempt,
                                                              description: "")
                        self.transactionStatusSubject.send(status)
                        
                        throw FiservTTPCardReaderError(title: title,
                                                       localizedDescription: err.localizedDescription,
                                                       failureReason: err.failureReason)
                    }
                    
                }
                
            } else {
                
                let status = PaymentTransactionStatus(eventType: .cancelPendngNetworkAvailability,
                                                      transactionType: transactionType,
                                                      refundTransactionType: .none,
                                                      attempt: attempt,
                                                      description: "Cancel Requested Pendng Network Availability - Attempt: \(attempt) of 3")
                
                self.transactionStatusSubject.send(status)
                
                try? await Task.sleep(for: .seconds(10))
            }
        }
        
        throw FiservTTPCardReaderError(title: title, localizedDescription: NSLocalizedString("Maximum number of reversal attempts reached.", comment: ""))
    }
    
    private func appendGeneralCardDataToSourceResponse(generalCardData: String?, response: Models.SourceResponse?) -> Models.SourceResponse {
        
        let sourceResponse = Models.SourceResponse(sourceType: response?.sourceType,
                                                   hasBeenDecrypted: response?.hasBeenDecrypted,
                                                   card: response?.card,
                                                   emvData: response?.emvData,
                                                   generalCardData: base64ToHex(generalCardData))
        
        return sourceResponse
    }
    
    private func appGeneralCardData(generalCardData: String, response: FiservTTPChargeResponse) -> FiservTTPChargeResponse {
        
        let appendedResponse = FiservTTPChargeResponse(gatewayResponse: response.gatewayResponse,
                                                       source: FiservTTPChargeResponseSource(sourceType: response.source?.sourceType,
                                                                                             card: response.source?.card,
                                                                                             emvData: response.source?.emvData,
                                                                                             generalCardData: base64ToHex(generalCardData)),
                                                       paymentReceipt: response.paymentReceipt,
                                                       transactionDetails: response.transactionDetails,
                                                       transactionInteraction: response.transactionInteraction,
                                                       merchantDetails: response.merchantDetails,
                                                       networkDetails: response.networkDetails,
                                                       cardDetails: response.cardDetails,
                                                       paymentTokens: response.paymentTokens,
                                                       error: response.error)
        
        return appendedResponse
    }
    
    private func base64ToHex(_ base64String: String?) -> String? {
        
        guard let data = Data(base64Encoded: base64String ?? String()) else {
            return nil
        }
        
        return data.map { String(format: "%02hhx", $0) }.joined()
    }
}

extension FiservTTPCardReader {
    
    func decode(jwtToken jwt: String) throws -> [String: Any] {

        enum DecodeErrors: Error {
            case badToken
            case other
        }

        func base64Decode(_ base64: String) throws -> Data {
            let base64 = base64
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            let padded = base64.padding(toLength: ((base64.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
            guard let decoded = Data(base64Encoded: padded) else {
                throw DecodeErrors.badToken
            }
            return decoded
        }

        func decodeJWTPart(_ value: String) throws -> [String: Any] {
            let bodyData = try base64Decode(value)
            let json = try JSONSerialization.jsonObject(with: bodyData, options: [])
            guard let payload = json as? [String: Any] else {
                throw DecodeErrors.other
            }
            return payload
        }

        let segments = jwt.components(separatedBy: ".")
        return try decodeJWTPart(segments[1])
    }
}
