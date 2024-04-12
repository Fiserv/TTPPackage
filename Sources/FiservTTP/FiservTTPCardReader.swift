//  FiservTTP
//
//  Copyright (c) 2022 - 2023 Fiserv, Inc.
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
    
    private var token: String?
    
    private var tokenExp: Double = 0.0
    
    public var sessionReadySubject: PassthroughSubject<Bool, Never> = .init()
    
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
    /// - Returns:
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    public func requestSessionToken() async throws {
            
        let title = "Token Request"
        
        let result = await services.requestSessionToken()
        
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
    @available(iOS 16.4, *)
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
                
                try await requestSessionToken()   // Auto Refresh
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
        
        let title = "Validate Payment Card"
        
        guard let _ = self.fiservTTPReader.readerIdentifier() else {
            
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: NSLocalizedString("Payment Card Reader not identified.", comment: ""))
        }
        
        return try await self.fiservTTPReader.validateCard(currencyCode: self.configuration.currencyCode)
        
    }
    
    /// Read and processes a card for the amount provided
    ///
    /// This method allow a card to be charged for the specified amount.
    ///
    /// - Parameter amount: Decimal
    ///
    /// - Parameter merchantOrderId: String
    ///
    /// - Parameter merchantTransactionId: String
    ///
    /// - Returns:FiservTTPChargeResponse
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    public func readCard(amount: Decimal,
                         merchantOrderId: String,
                         merchantTransactionId: String) async throws -> FiservTTPChargeResponse {
        
        let title = "Read Payment Card"
        
        guard let readerIdentifier = self.fiservTTPReader.readerIdentifier() else {
            
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: NSLocalizedString("Payment Card Reader not identified.", comment: ""))
        }
        
        let result = try await self.fiservTTPReader.readCard(for: amount,
                                                             currencyCode: self.configuration.currencyCode,
                                                             transactionType: .purchase,
                                                             eventHandler: { _ in
        })
        
        switch result {
            
        case .success(let cardReadResult):
            
            guard let generalCardData = cardReadResult.generalCardData, let _ = cardReadResult.paymentCardData else {
            
                throw FiservTTPCardReaderError(title: title,
                                               localizedDescription: NSLocalizedString("Payment Card data missing or corrupt.", comment: ""))
            }
            
            let chargeResult = await services.charge(amount: amount,
                                                     currencyCode: self.configuration.currencyCode,
                                                     merchantOrderId: merchantOrderId,
                                                     merchantTransactionId: merchantTransactionId,
                                                     paymentCardReaderId: readerIdentifier,
                                                     paymentCardReadResult: cardReadResult)
            
            switch chargeResult {
                
            case .success(let response):
                
                let appendedResponse = appGeneralCardData(generalCardData: generalCardData, response: response)
                
                return appendedResponse
            
            case .failure(let err):
                
                throw FiservTTPCardReaderError(title: title,
                                               localizedDescription: err.localizedDescription,
                                               failureReason: err.failureReason)
            }
            
        case .failure(let error):
            
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: error.localizedDescription)
        }
    }
    
    /// Inquire a transaction
    ///
    /// This method provides a way to lookup an existing transaction. At least one of the optional values must be provided.
    ///
    /// - Parameter referenceTransactionId: String
    ///
    /// - Parameter referenceMerchantTransactionId: String
    ///
    /// - Parameter referenceMerchantOrderId: String
    ///
    /// - Parameter referenceOrderId: String
    ///
    /// - Returns:FiservTTPChargeResponse
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    public func inquiryTransaction(referenceTransactionId: String? = nil,
                                   referenceMerchantTransactionId: String? = nil,
                                   referenceMerchantOrderId: String? = nil,
                                   referenceOrderId: String? = nil) async throws -> [FiservTTPChargeResponse] {
        
        let title = "Inquiry Transaction"
        
        let inquiryResult = await services.inquiry(referenceTransactionId: referenceTransactionId,
                                                   referenceMerchantTransactionId: referenceMerchantTransactionId,
                                                   referenceMerchantOrderId: referenceMerchantOrderId,
                                                   referenceOrderId: referenceOrderId)
        
        switch inquiryResult {
            
        case .success(let response):
            
            return response
            
        case .failure(let err):
            
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: err.localizedDescription,
                                           failureReason: err.failureReason)
        }
    }
    
    /// Void a transaction
    ///
    /// This method provides a way to void an existing transaction. At least one of the optional values must be provided.
    ///
    /// - Parameter amount: Decimal
    ///
    /// - Parameter referenceTransactionId: String
    ///
    /// - Parameter referenceMerchantTransactionId: String
    ///
    /// - Returns:FiservTTPChargeResponse
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    public func voidTransaction(amount: Decimal,
                                referenceTransactionId: String? = nil,
                                referenceMerchantTransactionId: String? = nil) async throws -> FiservTTPChargeResponse {
        
        let title = "Void Transaction"
        
        let voidResult = await services.void(referenceTransactionId: referenceTransactionId,
                                             referenceMerchantTransactionId: referenceMerchantTransactionId,
                                             referenceTransactionType: "CHARGES",
                                             total: amount,
                                             currencyCode: self.configuration.currencyCode)
        
        switch voidResult {
            
        case .success(let response):
            
            return response
        
        case .failure(let err):
            
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: err.localizedDescription,
                                           failureReason: err.failureReason)
        }
    }
    
    /// Refund a transaction
    ///
    /// This method provides a way to refund an existing transaction. At least one of the optional values must be provided.
    ///
    /// - Parameter amount: Decimal
    ///
    /// - Parameter referenceTransactionId: String
    ///
    /// - Parameter referenceMerchantTransactionId: String
    ///
    /// - Returns:FiservTTPChargeResponse
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    public func refundTransaction(amount: Decimal,
                                  referenceTransactionId: String? = nil,
                                  referenceMerchantTransactionId: String? = nil) async throws -> FiservTTPChargeResponse {
        
        let title = "Refund Transaction"
        
        let refundResult = await services.refund(referenceTransactionId: referenceTransactionId,
                                                 referenceMerchantTransactionId: referenceMerchantTransactionId,
                                                 referenceTransactionType: "CHARGES",
                                                 total: amount,
                                                 currencyCode: self.configuration.currencyCode)
        
        switch refundResult {
            
        case .success(let response):
            
            return response
        
        case .failure(let err):
            
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: err.localizedDescription,
                                           failureReason: err.failureReason)
        }
    }
    
    /// Read and process a card for the amount provided
    ///
    /// This method allows a card to be refunded for the specified amount.
    ///
    /// - Parameter amount: Decimal
    ///
    /// - Parameter referenceTransactionId: String
    ///
    /// - Parameter referenceMerchantTransactionId: String
    ///
    /// - Returns:FiservTTPChargeResponse
    ///
    /// - Throws: An error of type FiservTTPCardReaderError
    ///
    public func refundCard(amount: Decimal,
                           referenceTransactionId: String? = nil,
                           referenceMerchantTransactionId: String? = nil) async throws -> FiservTTPChargeResponse {
        
        let title = "Refund Payment Card"
        
        guard let readerIdentifier = self.fiservTTPReader.readerIdentifier() else {
            
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: NSLocalizedString("Payment Card Reader not identified.", comment: ""))
        }
        
        let result = try await self.fiservTTPReader.readCard(for: amount,
                                                             currencyCode: self.configuration.currencyCode,
                                                             transactionType: .refund,
                                                             eventHandler: { _ in
        })
        
        switch result {
            
        case .success(let cardReadResult):
            
            guard let generalCardData = cardReadResult.generalCardData, let _ = cardReadResult.paymentCardData else {
                
                throw FiservTTPCardReaderError(title: title,
                                               localizedDescription: NSLocalizedString("Payment Card data missing or corrupt.", comment: ""))
            }
            
            let refundCardResult = await services.refundCard(referenceTransactionId: referenceTransactionId,
                                                             referenceMerchantTransactionId: referenceMerchantTransactionId,
                                                             referenceTransactionType: "CHARGES",
                                                             total: amount,
                                                             currencyCode: self.configuration.currencyCode,
                                                             paymentCardReaderId: readerIdentifier,
                                                             paymentCardReadResult: cardReadResult)
            
            switch refundCardResult {
                
            case .success(let response):
                
                let appendedResponse = appGeneralCardData(generalCardData: generalCardData, response: response)
                
                return appendedResponse
            
            case .failure(let err):
                
                throw FiservTTPCardReaderError(title: title,
                                               localizedDescription: err.localizedDescription,
                                               failureReason: err.failureReason)
            }
            
        case .failure(let error):
            
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: error.localizedDescription)
        }
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
                                                       error: response.error)
        
        return appendedResponse
    }
    
    private func base64ToHex(_ base64String: String) -> String? {
        
        guard let data = Data(base64Encoded: base64String) else {
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
