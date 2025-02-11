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

import SwiftUI
import Foundation
import CryptoKit
import ProximityReader

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// ENVIRONMENT

/**
 The destination environment for network requests
 */
public enum FiservTTPEnvironment {
    case Int
    case QA
    case Sandbox
    case Cat
    case Production
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// REQUEST METHOD

internal enum FiservTTPRequestMethod: String {
    case get    = "GET"
    case post   = "POST"
    case head   = "HEAD"
    case put    = "PUT"
    case delete = "DELETE"
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// PATH (TO API ENDPOINT)

internal enum FiservTTPPath {
    
    case authenticate(String, String)
    case accountVerification(String, String)
    case tokenization(String, String)
    case token(String, String)
    case charge(String, String)
    case inquiry(String, String)
    case cancel(String, String)
    case void(String, String)
    case refund(String, String)
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// ERROR

struct FiservTTPRequestError: Error {

    let errorMessage: String
    let failureReason: String?

    init(message: String, failureReason: String? = nil) {
        self.errorMessage = message
        self.failureReason = failureReason
    }
}

extension FiservTTPRequestError: LocalizedError {

    public var errorDescription: String? {
        return NSLocalizedString(errorMessage, comment: "")
    }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// ENDPOINT

internal struct FiservTTPEndpoint {
    
    private var fsconfig     : FiservTTPConfig
    private var fsmethod     : FiservTTPRequestMethod
    private var fspath       : FiservTTPPath
    
    init(config: FiservTTPConfig, method: FiservTTPRequestMethod, path: FiservTTPPath) {
        
        self.fsmethod = method
        self.fspath = path
        self.fsconfig = config
    }
    
    var scheme: String {
        return "https"
    }
    
    var host: String {
        switch self.fsconfig.environment {
        case .Int:
            return "connect-dev.fiservapis.com"
        case .QA:
            return "connect-qa.fiservapis.com"
        case .Sandbox:
            return "connect-cert.fiservapis.com"
        case .Cat:
            return "connect-uat.fiservapis.com"
        case .Production:
            return "connect.fiservapis.com"
        }
    }
    
    var path: String {
        switch self.fspath {
        case .authenticate(let value, _):
            return value
        case .tokenization(let value, _):
            return value
        case .accountVerification(let value, _):
            return value
        case .token( let value, _):
            return value
        case .charge( let value, _):
            return value
        case .inquiry( let value, _):
            return value
        case .cancel(let value, _):
            return value
        case .void( let value, _):
            return value
        case .refund( let value, _):
            return value
        }
    }
    
    var method: FiservTTPRequestMethod {
        return fsmethod
    }
}

extension FiservTTPEndpoint {
    
    internal func httpHeaders(requestBody: String, clientRequestId: Int, timestamp: Int64) -> [String : String] {
        
        var headers = commonHttpHeaders(clientRequestId: clientRequestId, timestamp: timestamp)
        
        if let authHeaderValue = authHeaderValue(requestBody: requestBody,
                                                 clientRequestId: clientRequestId,
                                                 timestamp: timestamp) {
            
            headers["Authorization"] = authHeaderValue
        }
        
        return headers
    }
    
    private func commonHttpHeaders(clientRequestId: Int, timestamp: Int64) -> [String : String] {

        var headers = [String : String]()
        headers["Accept"] = "application/json"
        headers["Content-Type"] = "application/json"
        headers["Accept-language"] = "en"
        headers["Auth-Token-Type"] = "HMAC"
        headers["Timestamp"] = String(timestamp)
        headers["Api-Key"] = self.fsconfig.apiKey
        headers["Client-Request-Id"] = String(clientRequestId)
        
        return headers
    }
    
    private func authHeaderValue(requestBody:String, clientRequestId:Int, timestamp:Int64) -> String? {
        
        if let secretData = self.fsconfig.secretKey.data(using: .utf8) {
          
            let signingKey = SymmetricKey(data: secretData)
            
            let signatureString = "\(self.fsconfig.apiKey)\(clientRequestId)\(timestamp)\(requestBody)"
            
            if let signatureData = signatureString.data(using: .utf8) {
                
                let rawSignature = HMAC<SHA256>.authenticationCode(for: signatureData, using:signingKey)
                
                let signature = Data(rawSignature).base64EncodedString()
                
                return signature
            }
        }
        
        return nil
    }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// SERVICES

internal struct FiservTTPServices {
    
    private let authenticateEndpoint: FiservTTPEndpoint
    private let accountVerificationEndpoint: FiservTTPEndpoint
    private let tokenizeEndpoint: FiservTTPEndpoint
    private let tokenEndpoint: FiservTTPEndpoint
    private var chargeEndpoint: FiservTTPEndpoint
    private var inquiryEndpoint: FiservTTPEndpoint
    private var cancelEndpoint: FiservTTPEndpoint
    private var voidEndpoint: FiservTTPEndpoint
    private var refundEndpoint: FiservTTPEndpoint
    private let bundleIdentifier = "com.fiserv.FiservTTP"
    internal let app_name = "fiserv_ch_apple_ttp_sdk"
    internal let app_version: String
    internal let vendorId: String
    private let config: FiservTTPConfig
    private let sourceTypeName = "AppleTapToPay"
    
    internal init(config: FiservTTPConfig) {
        
        self.app_version = "1.0.7"
        
        self.config = config
        
        self.vendorId = UIDevice.current.identifierForVendor?.uuidString.string ?? ""
        
        self.authenticateEndpoint = FiservTTPEndpoint(config: config,
                                                      method: .post,
                                                      path: .authenticate("/ch/security/v1/ttpcredentials", "Authenticate"))
                
                
        self.accountVerificationEndpoint = FiservTTPEndpoint(config: config,
                                                             method: .post,
                                                             path: .accountVerification("/ch/payments-vas/v1/accounts/verification", "Account Verification Request"))
                
        self.tokenizeEndpoint = FiservTTPEndpoint(config: config,
                                                  method: .post,
                                                  path: .token("/ch/payments-vas/v1/tokens", "Tokenize Request"))
        
        self.tokenEndpoint = FiservTTPEndpoint(config: config,
                                               method: .post,
                                               path: .token("/ch/security/v1/ttpcredentials", "Token Request"))
        
        self.chargeEndpoint = FiservTTPEndpoint(config: config,
                                                method: .post,
                                                path: .charge("/ch/payments/v1/charges", "Charges Request"))
        
        self.inquiryEndpoint = FiservTTPEndpoint(config: config,
                                                 method: .post,
                                                 path: .charge("/ch/payments/v1/transaction-inquiry", "Inquiry Request"))
        
        self.cancelEndpoint = FiservTTPEndpoint(config: config,
                                                method: .post,
                                                path: .charge("/ch/payments/v1/cancels", "Void Request"))
        
        self.voidEndpoint = FiservTTPEndpoint(config: config,
                                                method: .post,
                                                path: .charge("/ch/payments/v1/cancels", "Void Request"))
        
        self.refundEndpoint = FiservTTPEndpoint(config: config,
                                                method: .post,
                                                path: .charge("/ch/payments/v1/refunds", "Refund Request"))
    }
    
    internal func requestSessionToken() async -> Result<FiservTTPTokenResponse, FiservTTPRequestError> {
        
        return await sendRequest(endpoint: tokenEndpoint,
                                 httpBody: bodyForTokenRequest(),
                                 responseModel: FiservTTPTokenResponse.self)
    }

    internal func bodyFor<T: Codable>(_ value: T) -> Data? {
            
        let jsonEncoder = JSONEncoder()

        let encoded = try? jsonEncoder.encode(value)
        print("Http Body: \(String(data: encoded!, encoding: .utf8) ?? "")")
        return encoded
    }
    
    // NEW
    internal func accountVerification(transactionDetails: Models.TransactionDetailsRequest,
                                           billingAddress: Models.BillingAddressRequest? = nil,
                                      paymentCardReaderId: String? = nil,
                                paymentTokenSourceRequest: Models.PaymentTokenSourceRequest? = nil,
                                 cardVerificationResponse: Models.CardVerificationResponse? = nil) async -> Result <Models.AccountVerificationResponse, FiservTTPRequestError> {
            
            return await sendRequest(endpoint: accountVerificationEndpoint,
                                     httpBody: bodyForAccountVerification(transactionDetails: transactionDetails,
                                                                          billingAddress: billingAddress,
                                                                          cardVerificationResponse: cardVerificationResponse,
                                                                          paymentTokenSourceRequest: paymentTokenSourceRequest),
                                     responseModel: Models.AccountVerificationResponse.self)
    }
    
    // NEW
    internal func tokenize(transationDetails: Models.TransactionDetailsRequest,
                           cardVerificationResponse: Models.CardVerificationResponse) async -> Result<Models.TokenizeCardResponse, FiservTTPRequestError> {

        return await sendRequest(endpoint: tokenizeEndpoint,
                                 httpBody: bodyForTokenizeRequest(transactionDetails: transationDetails,
                                                                  paymentCardReaderId: cardVerificationResponse.cardReaderId,
                                                                  generalCardData: cardVerificationResponse.generalCardData,
                                                                  paymentCardData: cardVerificationResponse.paymentCardData,
                                                                  cardReaderTransactionId: cardVerificationResponse.transactionId),
                                 responseModel: Models.TokenizeCardResponse.self)
        
    }
    
    // NEW
    internal func transactionInquiry(inquireRequest: Models.TransactionInquiryRequest) async -> Result<[Models.InquireResponse], FiservTTPRequestError> {
        
        return await sendRequest(endpoint: inquiryEndpoint,
                                 httpBody: bodyFor(inquireRequest),
                                 responseModel: [Models.InquireResponse].self)
    }
    
    // NEW
    internal func charges(amountRequest: Models.AmountRequest,
                          transactionDetailsRequest: Models.TransactionDetailsRequest,
                          referenceTransactionDetailsRequest: Models.ReferenceTransactionDetailsRequest? = nil,
                          paymentTokenChargeRequest: Models.PaymentTokenChargeRequest? = nil,
                          cardVerificationResponse: Models.CardVerificationResponse? = nil) async -> Result<Models.CommerceHubResponse, FiservTTPRequestError> {
        
        if paymentTokenChargeRequest != nil {
            
            return await sendRequest(endpoint: chargeEndpoint,
                                     httpBody: bodyForPaymentTokenRequest(paymentTokenChargeRequest: paymentTokenChargeRequest),
                                     responseModel: Models.CommerceHubResponse.self)
        } else {
            
                return await sendRequest(endpoint: chargeEndpoint,
                                         httpBody: bodyForChargesRequest(amountRequest: amountRequest,
                                                                         transactionDetailsRequest: transactionDetailsRequest,
                                                                         referenceTransactionDetailsRequest: referenceTransactionDetailsRequest,
                                                                         cardVerificationResponse: cardVerificationResponse),
                                         responseModel: Models.CommerceHubResponse.self)
        }
    }

    // NEW
    internal func cancels(amountRequest: Models.AmountRequest,
                          referenceTransactionDetailsRequest: Models.ReferenceTransactionDetailsRequest) async -> Result<Models.CommerceHubResponse, FiservTTPRequestError> {
        
        return await sendRequest(endpoint: cancelEndpoint,
                                 httpBody: bodyForCancelsRequest(amountRequest: amountRequest,
                                                                 referenceTransactionDetailsRequest: referenceTransactionDetailsRequest),
                                 responseModel: Models.CommerceHubResponse.self)
    }
    
    internal func refunds(amountRequest: Models.AmountRequest,
                          transactionDetailsRequest: Models.TransactionDetailsRequest? = nil,
                          referenceTransactionDetailsRequest: Models.ReferenceTransactionDetailsRequest? = nil,
                          cardVerificationResponse: Models.CardVerificationResponse? = nil) async -> Result<Models.CommerceHubResponse, FiservTTPRequestError> {
        
        return await sendRequest(endpoint: refundEndpoint,
                                 httpBody: bodyForRefundsRequest(amountRequest: amountRequest,
                                                                 transactionDetailsRequest: transactionDetailsRequest,
                                                                 referenceTransactionDetailsRequest: referenceTransactionDetailsRequest,
                                                                 cardVerificationResponse: cardVerificationResponse),
                                 responseModel: Models.CommerceHubResponse.self)
        
    }
    
    internal func charge(amount: Decimal,
                        currencyCode: String,
                        merchantOrderId: String? = nil,
                        merchantTransactionId: String? = nil,
                        merchantInvoiceNumber: String? = nil,
                        paymentCardReaderId: String,
                        paymentCardReadResult: PaymentCardReadResult) async -> Result<FiservTTPChargeResponse, FiservTTPRequestError> {
        
        guard let generalCardData = paymentCardReadResult.generalCardData,
              let paymentCardData = paymentCardReadResult.paymentCardData else {
            
            return .failure(FiservTTPRequestError(message: "Payment Card data missing or corrupt."))
        }

        return await sendRequest(endpoint: chargeEndpoint,
                                 httpBody: bodyForChargeRequest(amount: amount,
                                                                currencyCode: currencyCode,
                                                                merchantOrderId: merchantOrderId,
                                                                merchantTransactionId: merchantTransactionId,
                                                                merchantInvoiceNumber: merchantInvoiceNumber,
                                                                paymentCardReaderId: paymentCardReaderId,
                                                                generalCardData: generalCardData,
                                                                paymentCardData: paymentCardData,
                                                                cardReaderTransactionId: paymentCardReadResult.id),
                                responseModel: FiservTTPChargeResponse.self)
    }

    internal func inquiry(referenceTransactionId: String? = nil,
                          referenceMerchantTransactionId: String? = nil,
                          referenceMerchantOrderId: String? = nil,
                          referenceOrderId: String? = nil) async -> Result<[FiservTTPChargeResponse], FiservTTPRequestError> {
        
        return await sendRequest(endpoint: inquiryEndpoint,
                                 httpBody: bodyForInquiryRequest(referenceTransactionId: referenceTransactionId,
                                                                 referenceMerchantTransactionId: referenceMerchantTransactionId,
                                                                 referenceMerchantOrderId: referenceMerchantOrderId,
                                                                 referenceOrderId: referenceOrderId),
                                                                 responseModel: [FiservTTPChargeResponse].self)
    }
    
    internal func void(referenceTransactionId: String? = nil,
                       referenceMerchantTransactionId: String? = nil,
                       referenceTransactionType: String,
                       total: Decimal,
                       currencyCode: String) async -> Result<FiservTTPChargeResponse, FiservTTPRequestError> {
        
        return await sendRequest(endpoint: voidEndpoint,
                                 httpBody: bodyForVoidRequest(referenceTransactionId: referenceTransactionId,
                                                              referenceMerchantTransactionId: referenceMerchantTransactionId,
                                                              referenceTransactionType: referenceTransactionType,
                                                              total: total,
                                                              currencyCode: currencyCode),
                                                              responseModel: FiservTTPChargeResponse.self)
    }
    
    internal func refund(referenceTransactionId: String? = nil,
                         referenceMerchantTransactionId: String? = nil,
                         referenceTransactionType: String,
                         total: Decimal,
                         currencyCode: String) async -> Result<FiservTTPChargeResponse, FiservTTPRequestError> {
    
        
        return await sendRequest(endpoint: refundEndpoint,
                                 httpBody: bodyForRefundRequest(referenceTransactionId: referenceTransactionId,
                                                                referenceMerchantTransactionId: referenceMerchantTransactionId,
                                                                referenceTransactionType: referenceTransactionType,
                                                                total: total,
                                                                currencyCode: currencyCode),
                                                                responseModel: FiservTTPChargeResponse.self)
    }
    
    internal func refundCard(merchantOrderId: String? = nil,
                             merchantTransactionId: String? = nil,
                             merchantInvoiceNumber: String? = nil,
                             referenceTransactionId: String? = nil,
                             referenceMerchantTransactionId: String? = nil,
                             referenceTransactionType: String,
                             total: Decimal,
                             currencyCode: String,
                             paymentCardReaderId: String,
                             paymentCardReadResult: PaymentCardReadResult) async -> Result<FiservTTPChargeResponse, FiservTTPRequestError> {

        guard let generalCardData = paymentCardReadResult.generalCardData,
              let paymentCardData = paymentCardReadResult.paymentCardData else {
        
            return .failure(FiservTTPRequestError(message: "Payment Card data missing or corrupt."))
        }
        
        return await sendRequest(endpoint: refundEndpoint,
                                 httpBody: bodyForRefundCardRequest(merchantOrderId: merchantOrderId,
                                                                    merchantTransactionId: merchantTransactionId,
                                                                    merchantInvoiceNumber: merchantInvoiceNumber,
                                                                    referenceTransactionId: referenceTransactionId,
                                                                    referenceMerchantTransactionId: referenceMerchantTransactionId,
                                                                    referenceTransactionType: referenceTransactionType,
                                                                    total: total,
                                                                    currencyCode: currencyCode,
                                                                    generalCardData: generalCardData,
                                                                    paymentCardData: paymentCardData,
                                                                    cardReaderId: paymentCardReaderId,
                                                                    cardReaderTransactionId: paymentCardReadResult.id),
                                                                    responseModel: FiservTTPChargeResponse.self)
    }
    
    // NEW
    internal func bodyForAccountVerification(transactionDetails: Models.TransactionDetailsRequest,
                                                 billingAddress: Models.BillingAddressRequest? = nil,
                                       cardVerificationResponse: Models.CardVerificationResponse? = nil,
                                      paymentTokenSourceRequest: Models.PaymentTokenSourceRequest? = nil) -> Data? {
        
        let merchantDetails = Models.MerchantDetailsRequest(merchantId: self.config.merchantId, terminalId: self.config.terminalId)
        
        let posFeatures = Models.PosFeaturesRequest(pinAuthenticationCapability: "CAN_ACCEPT_PIN",
                                                            terminalEntryCapability: "CONTACTLESS")
        
        let posHardwareAndSoftware = Models.PosHardwareAndSoftwareRequest(softwareApplicationName: self.app_name,
                                                                            softwareVersionNumber: self.app_version,
                                                                         hardwareVendorIdentifier: self.vendorId)
        
        let additionalPosInformationRequest = Models.DataEntrySourceRequest(dataEntrySource: "MOBILE_TERMINAL",
                                                                                posFeatures: posFeatures,
                                                                     posHardwareAndSoftware: posHardwareAndSoftware)

        let transactionInteraction = Models.TransactionInteractionRequest(origin: "POS",
                                                                    posEntryMode: "CONTACTLESS",
                                                                posConditionCode: "CARD_PRESENT",
                                                        additionalPosInformation: additionalPosInformationRequest)
        
        // (Account Verification from Card Read - Not Payment Token)
        if cardVerificationResponse != nil {
            
            let sourceRequest = Models.SourceRequest(sourceType: sourceTypeName,
                                                generalCardData: cardVerificationResponse?.generalCardData,
                                                paymentCardData: cardVerificationResponse?.paymentCardData,
                                                   cardReaderId: cardVerificationResponse?.cardReaderId,
                                        cardReaderTransactionId: cardVerificationResponse?.transactionId,
                                             appleTtpMerchantId: self.config.appleTtpMerchantId)
            
            let accountVerificationRequest = Models.AccountVerificationRequest(source: sourceRequest,
                                                                               transactionDetails: transactionDetails,
                                                                               transactionInteraction: transactionInteraction,
                                                                               billingAddress: billingAddress,
                                                                               merchantDetails: merchantDetails)
            let jsonEncoder = JSONEncoder()

            let encoded = try? jsonEncoder.encode(accountVerificationRequest)

            return encoded
        }
        
        if let request = paymentTokenSourceRequest {
                        
            let accountVerificationTokenRequest = Models.AccountVerificationTokenRequest(source: request,
                                                                        transactionDetails: transactionDetails,
                                                                    transactionInteraction: transactionInteraction,
                                                                            billingAddress: billingAddress,
                                                                           merchantDetails: merchantDetails)
            let jsonEncoder = JSONEncoder()

            let encoded = try? jsonEncoder.encode(accountVerificationTokenRequest)

            return encoded
        }
        
        return nil
    }
    
    // NEW
    internal func bodyForTokenizeRequest(transactionDetails: Models.TransactionDetailsRequest,
                                         paymentCardReaderId: String,
                                         generalCardData: String,
                                         paymentCardData: String,
                                         cardReaderTransactionId: String) -> Data? {
        
        let source = Models.SourceRequest(sourceType: sourceTypeName,
                                          generalCardData: generalCardData,
                                          paymentCardData: paymentCardData,
                                          cardReaderId: paymentCardReaderId,
                                          cardReaderTransactionId: cardReaderTransactionId,
                                          appleTtpMerchantId: self.config.appleTtpMerchantId)
        
        let merchantDetails = Models.MerchantDetailsRequest(merchantId: self.config.merchantId, terminalId: self.config.terminalId)
     
        let tokenizeRequest = Models.TokenizeCardRequest(source: source,
                                                         transactionDetails: transactionDetails,
                                                         merchantDetails: merchantDetails)

        let jsonEncoder = JSONEncoder()

        let encoded = try? jsonEncoder.encode(tokenizeRequest)

        return encoded
    }
    
    internal func bodyForTokenRequest() -> Data? {
        
        let merchantDetails = FiservTTPMerchantDetails(merchantId: self.config.merchantId,
                                                       terminalId: self.config.terminalId)
        
        let dynamicDescriptors = FiservTTPDynamicDescriptors(mcc: self.config.merchantCategoryCode,
                                                          merchantName: self.config.merchantName)
        
        let tokenRequest = FiservTTPTokenRequest(terminalProfileId: self.config.terminalProfileId,
                                                 channel: "ISV",
                                                 accessTokenTimeToLive: 172800,
                                                 dynamicDescriptors: dynamicDescriptors,
                                                 merchantDetails: merchantDetails,
                                                 appleTtpMerchantId: self.config.appleTtpMerchantId)
        
        let jsonEncoder = JSONEncoder()
        
        let encoded = try? jsonEncoder.encode(tokenRequest)
        
        return encoded
    }
    
    // NEW
    internal func bodyForPaymentTokenRequest(paymentTokenChargeRequest: Models.PaymentTokenChargeRequest?) -> Data? {
        
        let jsonEncoder = JSONEncoder()

        let encoded = try? jsonEncoder.encode(paymentTokenChargeRequest)

        return encoded
    }

    // NEW
    internal func bodyForChargesRequest(amountRequest: Models.AmountRequest,
                                        transactionDetailsRequest: Models.TransactionDetailsRequest,
                                        referenceTransactionDetailsRequest: Models.ReferenceTransactionDetailsRequest? = nil,
                                        cardVerificationResponse: Models.CardVerificationResponse? = nil) -> Data? {
        
        var sourceRequest: Models.SourceRequest?
        
        // (Only Sale and Auth [Read Card == TRUE])
        if cardVerificationResponse != nil {
        
            sourceRequest = Models.SourceRequest(sourceType: sourceTypeName,
                                                     generalCardData: cardVerificationResponse?.generalCardData,
                                                     paymentCardData: cardVerificationResponse?.paymentCardData,
                                                     cardReaderId: cardVerificationResponse?.cardReaderId,
                                                     cardReaderTransactionId: cardVerificationResponse?.transactionId,
                                                     appleTtpMerchantId: self.config.appleTtpMerchantId)
        }
        
        let posFeatures = Models.PosFeaturesRequest(pinAuthenticationCapability: "CAN_ACCEPT_PIN",
                                                    terminalEntryCapability: "CONTACTLESS")
        
        let posHardwareAndSoftware = Models.PosHardwareAndSoftwareRequest(softwareApplicationName: self.app_name,
                                                                          softwareVersionNumber: self.app_version,
                                                                          hardwareVendorIdentifier: self.vendorId)
        
        let dataEntrySource = Models.DataEntrySourceRequest(dataEntrySource: "MOBILE_TERMINAL",
                                                            posFeatures: posFeatures,
                                                            posHardwareAndSoftware: posHardwareAndSoftware)

        let transactionInteraction = Models.TransactionInteractionRequest(origin: "POS",
                                                                          posEntryMode: "CONTACTLESS",
                                                                          posConditionCode: "CARD_PRESENT",
                                                                          additionalPosInformation: dataEntrySource)
        
        let processor = Models.AdditionalDataCommonProcessorRequest(processorName: "FISERV",
                                                                    processingPlatform: "NASHVILLE",
                                                                    settlementPlatform: "NORTH",
                                                                    priority: "PRIMARY")
        
        let processors = Models.AdditionalDataCommonProcessorsRequest(processors: processor)

        let additionalDataCommon = Models.AdditionalDataCommonRequest(origin: processors)
        
        let merchantDetails = Models.MerchantDetailsRequest(merchantId: self.config.merchantId, terminalId: self.config.terminalId)
        
        let chargeRequest = Models.ChargesRequest(amount: amountRequest,
                                                  source: sourceRequest,
                                                  merchantDetails: merchantDetails,
                                                  transactionDetails: transactionDetailsRequest,
                                                  referenceTransactionDetails: referenceTransactionDetailsRequest,
                                                  transactionInteraction: transactionInteraction,
                                                  additionalDataCommon: additionalDataCommon)

        let jsonEncoder = JSONEncoder()

        let encoded = try? jsonEncoder.encode(chargeRequest)
        print("Body For Charges Request: \(String(data: encoded!, encoding: .utf8) ?? "")")
        return encoded
    }
    
    internal func bodyForChargeRequest(amount: Decimal,
                                       currencyCode: String,
                                       merchantOrderId: String? = nil,
                                       merchantTransactionId: String? = nil,
                                       merchantInvoiceNumber: String? = nil,
                                       paymentCardReaderId: String,
                                       generalCardData: String,
                                       paymentCardData: String,
                                       cardReaderTransactionId: String) -> Data? {
        
        let amount = FiservTTPChargeRequestAmount(total: amount, currency: currencyCode)
        
        let source = FiservTTPChargeRequestSource(sourceType: sourceTypeName,
                                                  generalCardData: generalCardData,
                                                  paymentCardData: paymentCardData,
                                                  cardReaderId: paymentCardReaderId,
                                                  cardReaderTransactionId: cardReaderTransactionId,
                                                  appleTtpMerchantId: self.config.appleTtpMerchantId)
        
        let transactionDetails = FiservTTPChargeRequestTransactionDetails(captureFlag: true,
                                                                          merchantOrderId: merchantOrderId,
                                                                          merchantTransactionId: merchantTransactionId,
                                                                          merchantInvoiceNumber: merchantInvoiceNumber)

        let posFeatures = FiservTTPChargeRequestPosFeatures(pinAuthenticationCapability: "CAN_ACCEPT_PIN",
                                                            terminalEntryCapability: "CONTACTLESS")
        
        let posHardwareAndSoftware = FiservTTPChargeRequestPosHardwareAndSoftware(softwareApplicationName: self.app_name,
                                                                                  softwareVersionNumber: self.app_version,
                                                                                  hardwareVendorIdentifier: self.vendorId)
        
        let dataEntrySource = FiservTTPChargeRequestDataEntrySource(dataEntrySource: "MOBILE_TERMINAL",
                                                                    posFeatures: posFeatures,
                                                                    posHardwareAndSoftware: posHardwareAndSoftware)

        let transactionInteraction = FiservTTPChargeRequestTransactionInteraction(origin: "POS",
                                                                                  posEntryMode: "CONTACTLESS",
                                                                                  posConditionCode: "CARD_PRESENT",
                                                                                  additionalPosInformation: dataEntrySource)
        
        let processor = FiservTTPChargeRequestAdditionalDataCommonProcessor(processorName: "FISERV",
                                                                            processingPlatform: "NASHVILLE",
                                                                            settlementPlatform: "NORTH",
                                                                            priority: "PRIMARY")
        
        let processors = FiservTTPChargeRequestAdditionalDataCommonProcessors(processors: processor)
        
        let additionalDataCommon = FiservTTPChargeRequestAdditionalDataCommon(origin: processors)
        
        let merchantDetails = FiservTTPMerchantDetails(merchantId: self.config.merchantId, terminalId: self.config.terminalId)
        
        let chargeRequest = FiservTTPChargeRequest(amount: amount,
                                                   source: source,
                                                   transactionDetails: transactionDetails,
                                                   transactionInteraction: transactionInteraction,
                                                   merchantDetails: merchantDetails,
                                                   additionalDataCommon: additionalDataCommon)

        let jsonEncoder = JSONEncoder()

        let encoded = try? jsonEncoder.encode(chargeRequest)

        return encoded
    }
    
    internal func bodyForInquiryRequest(referenceTransactionId: String? = nil,
                                        referenceMerchantTransactionId: String? = nil,
                                        referenceMerchantOrderId: String? = nil,
                                        referenceOrderId: String? = nil) -> Data? {
            
        let referenceTransactionDetails = FiservTTPInquiryReferenceTransactionDetails(referenceTransactionId: referenceTransactionId,
                                                                                     referenceMerchantTransactionId: referenceMerchantTransactionId,
                                                                                     referenceMerchantOrderId: referenceMerchantOrderId,
                                                                                     referenceOrderId: referenceOrderId,
                                                                                     referenceClientRequestId: nil)
        
        let merchantDetails = FiservTTPInquiryMerchantDetails(tokenType: nil,
                                                              siteId: nil,
                                                              terminalId: self.config.terminalId,
                                                              merchantId: self.config.merchantId)
        
        let inquiryRequest = FiservTTPInquiryRequest(referenceTransactionDetails: referenceTransactionDetails, merchantDetails: merchantDetails)
        
        let jsonEncoder = JSONEncoder()

        let encoded = try? jsonEncoder.encode(inquiryRequest)

        return encoded
    }
    
    // NEW
    internal func bodyForCancelsRequest(amountRequest: Models.AmountRequest,
                                        referenceTransactionDetailsRequest: Models.ReferenceTransactionDetailsRequest) -> Data? {
        
        
        let merchantDetailsRequest = Models.MerchantDetailsRequest(merchantId: self.config.merchantId, terminalId: self.config.terminalId)
        
        let cancelsRequest = Models.CancelsRequest(amount: amountRequest,
                                                   merchantDetails: merchantDetailsRequest,
                                                   referenceTransactionDetails: referenceTransactionDetailsRequest)
        
        let jsonEncoder = JSONEncoder()

        let encoded = try? jsonEncoder.encode(cancelsRequest)

        return encoded
    }
    
    // ARGS                            MATCHED    UNMATCHED    OPEN
    //
    // READ CARD                        N           Y           Y
    // MERCHANT DETAILS                 Y           Y           Y
    // CAPTURE FLAG                     F           T           T
    // TRANSACTION DETAILS              N           Y           Y
    // REFERENCE TRANSACTION DETAILS    Y           Y           N
    // NEW
    internal func bodyForRefundsRequest(amountRequest: Models.AmountRequest,
                                        transactionDetailsRequest: Models.TransactionDetailsRequest? = nil,
                                        referenceTransactionDetailsRequest: Models.ReferenceTransactionDetailsRequest? = nil,
                                        cardVerificationResponse: Models.CardVerificationResponse? = nil) -> Data? {
        
        var sourceRequest: Models.SourceRequest?
        
        var transactionInteraction: Models.TransactionInteractionRequest?
        
        var additionalDataCommon: Models.AdditionalDataCommonRequest?
        
        // (Tagged UnMatched, Open [Read Card == TRUE])
        if cardVerificationResponse != nil {
        
            sourceRequest = Models.SourceRequest(sourceType: sourceTypeName,
                                                 generalCardData: cardVerificationResponse?.generalCardData,
                                                 paymentCardData: cardVerificationResponse?.paymentCardData,
                                                 cardReaderId: cardVerificationResponse?.cardReaderId,
                                                 cardReaderTransactionId: cardVerificationResponse?.transactionId,
                                                 appleTtpMerchantId: self.config.appleTtpMerchantId)
            
            let posFeatures = Models.PosFeaturesRequest(pinAuthenticationCapability: "CAN_ACCEPT_PIN",
                                                        terminalEntryCapability: "CONTACTLESS")
            
            let posHardwareAndSoftware = Models.PosHardwareAndSoftwareRequest(softwareApplicationName: self.app_name,
                                                                              softwareVersionNumber: self.app_version,
                                                                              hardwareVendorIdentifier: self.vendorId)
            
            let dataEntrySource = Models.DataEntrySourceRequest(dataEntrySource: "MOBILE_TERMINAL",
                                                                posFeatures: posFeatures,
                                                                posHardwareAndSoftware: posHardwareAndSoftware)
            
            transactionInteraction = Models.TransactionInteractionRequest(origin: "POS",
                                                                          posEntryMode: "CONTACTLESS",
                                                                          posConditionCode: "CARD_PRESENT",
                                                                          additionalPosInformation: dataEntrySource)
            
            let processor = Models.AdditionalDataCommonProcessorRequest(processorName: "FISERV",
                                                                        processingPlatform: "NASHVILLE",
                                                                        settlementPlatform: "NORTH",
                                                                        priority: "PRIMARY")
            
            let processors = Models.AdditionalDataCommonProcessorsRequest(processors: processor)

            additionalDataCommon = Models.AdditionalDataCommonRequest(origin: processors)
        }
        
        let merchantDetailsRequest = Models.MerchantDetailsRequest(merchantId: self.config.merchantId, terminalId: self.config.terminalId)
        
        let refundsRequest = Models.RefundsRequest(amount: amountRequest,
                                                   source: sourceRequest,
                                                   merchantDetails: merchantDetailsRequest,
                                                   transactionDetails: transactionDetailsRequest,
                                                   referenceTransactionDetails: referenceTransactionDetailsRequest,
                                                   transactionInteraction: transactionInteraction,
                                                   additionalDataCommon: additionalDataCommon)
        
        let jsonEncoder = JSONEncoder()

        let encoded = try? jsonEncoder.encode(refundsRequest)
        print("Body For Refunds Request: \(String(data: encoded!, encoding: .utf8) ?? "")")
        return encoded
    }
    
    internal func bodyForVoidRequest(referenceTransactionId: String? = nil,
                                     referenceMerchantTransactionId: String? = nil,
                                     referenceTransactionType: String,
                                     total: Decimal,
                                     currencyCode: String) -> Data? {
        
        let voidRequestAmount = FiservTTPVoidRequestAmount(total: total, currency: currencyCode)
        
        let voidMerchantDetails = FiservTTPVoidMerchantDetails(terminalId: self.config.terminalId, merchantId: self.config.merchantId)
        
        let referenceTransactionDetails = FiservTTPVoidReferenceTransactionDetails(referenceTransactionId: referenceTransactionId,
                                                                                   referenceMerchantTransactionId: referenceMerchantTransactionId,
                                                                                   referenceTransactionType: referenceTransactionType)
        
        let voidRequest = FiservTTPVoidRequest(referenceTransactionDetails: referenceTransactionDetails,
                                               amount: voidRequestAmount,
                                               merchantDetails: voidMerchantDetails)
        
        let jsonEncoder = JSONEncoder()

        let encoded = try? jsonEncoder.encode(voidRequest)

        return encoded
    }
    
    internal func bodyForRefundRequest(referenceTransactionId: String? = nil,
                                       referenceMerchantTransactionId: String? = nil,
                                       referenceTransactionType: String,
                                       total: Decimal,
                                       currencyCode: String) -> Data? {
        
        let refundRequestAmount = FiservTTPRefundRequestAmount(total: total, currency: currencyCode)
        
        let refundMerchantDetails = FiservTTPRefundMerchantDetails(terminalId: self.config.terminalId, merchantId: self.config.merchantId)
        
        let referenceTransactionDetails = FiservTTPRefundReferenceTransactionDetails(referenceTransactionId: referenceTransactionId,
                                                                                     referenceMerchantTransactionId: referenceMerchantTransactionId,
                                                                                     referenceTransactionType: referenceTransactionType)
        
        let refundRequest = FiservTTPRefundRequest(referenceTransactionDetails: referenceTransactionDetails,
                                                   amount: refundRequestAmount,
                                                   merchantDetails: refundMerchantDetails)
        
        let jsonEncoder = JSONEncoder()

        let encoded = try? jsonEncoder.encode(refundRequest)

        return encoded
    }

    internal func bodyForRefundCardRequest(merchantOrderId: String? = nil,
                                           merchantTransactionId: String? = nil,
                                           merchantInvoiceNumber: String? = nil,
                                           referenceTransactionId: String? = nil,
                                           referenceMerchantTransactionId: String? = nil,
                                           referenceTransactionType: String,
                                           total: Decimal,
                                           currencyCode: String,
                                           generalCardData: String,
                                           paymentCardData: String,
                                           cardReaderId: String,
                                           cardReaderTransactionId: String) -> Data? {
        
        let refundRequestAmount = FiservTTPRefundCardRequestAmount(total: total, currency: currencyCode)
        
        let refundMerchantDetails = FiservTTPRefundCardRequestMerchantDetails(merchantId: self.config.merchantId, terminalId: self.config.terminalId)
        
        let source = FiservTTPRefundCardRequestSource(sourceType: sourceTypeName,
                                                      generalCardData: generalCardData,
                                                      paymentCardData: paymentCardData,
                                                      cardReaderId: cardReaderId,
                                                      cardReaderTransactionId: cardReaderTransactionId,
                                                      appleTtpMerchantId: self.config.appleTtpMerchantId)
        
        let posFeatures = FiservTTPRefundCardRequestPosFeatures(pinAuthenticationCapability: "CAN_ACCEPT_PIN",
                                                                terminalEntryCapability: "CONTACTLESS")
        
        let posHardwareAndSoftware = FiservTTPChargeRequestPosHardwareAndSoftware(softwareApplicationName: self.app_name,
                                                                                  softwareVersionNumber: self.app_version,
                                                                                  hardwareVendorIdentifier: self.vendorId)
        
        let dataEntrySource = FiservTTPRefundCardRequestDataEntrySource(dataEntrySource: "MOBILE_TERMINAL",
                                                                        posFeatures: posFeatures,
                                                                        posHardwareAndSoftware: posHardwareAndSoftware)
        
        let transactionInteraction = FiservTTPRefundCardRequestTransactionInteraction(origin: "POS",
                                                                                      posEntryMode: "CONTACTLESS",
                                                                                      posConditionCode: "CARD_PRESENT",
                                                                                      additionalPosInformation: dataEntrySource)
        
        let processor = FiservTTPRefundCardRequestAdditionalDataCommonProcessor(processorName: "FISERV",
                                                                                processingPlatform: "NASHVILLE",
                                                                                settlementPlatform: "NORTH",
                                                                                priority: "PRIMARY")
        
        let processors = FiservTTPRefundCardRequestAdditionalDataCommonProcessors(processors: processor)
        
        let additionalDataCommon = FiservTTPRefundCardRequestAdditionalDataCommon(origin: processors)
        
        var refundCardRequest: FiservTTPRefundCardRequest
        
        let transactionDetails = FiservTTPRefundCardRequestTransactionDetails(captureFlag: true,
                                                                              merchantOrderId: merchantOrderId,
                                                                              merchantTransactionId: merchantTransactionId,
                                                                              merchantInvoiceNumber: merchantInvoiceNumber)
        
        if referenceTransactionId == nil && referenceMerchantTransactionId == nil {
            
            // Open Refund - No reference values should be provided
            
            refundCardRequest = FiservTTPRefundCardRequest(amount: refundRequestAmount,
                                                           source: source,
                                                           transactionDetails: transactionDetails,
                                                           referenceTransactionDetails: nil,
                                                           transactionInteraction: transactionInteraction,
                                                           merchantDetails: refundMerchantDetails,
                                                           additionalDataCommon: additionalDataCommon)
        } else {
            
            // Tagged Refund Unmatched - TransID + Tap + Different Card (than original sale)
            
            let referenceTransactionDetails = FiservTTPRefundReferenceTransactionDetails(referenceTransactionId: referenceTransactionId,
                                                                                         referenceMerchantTransactionId: referenceMerchantTransactionId,
                                                                                         referenceTransactionType: referenceTransactionType)
            
            refundCardRequest = FiservTTPRefundCardRequest(amount: refundRequestAmount,
                                                           source: source,
                                                           transactionDetails: transactionDetails,
                                                           referenceTransactionDetails: referenceTransactionDetails,
                                                           transactionInteraction: transactionInteraction,
                                                           merchantDetails: refundMerchantDetails,
                                                           additionalDataCommon: additionalDataCommon)
        }
        
        let jsonEncoder = JSONEncoder()
        
        let encoded = try? jsonEncoder.encode(refundCardRequest)
        
        return encoded
    }
    
    internal func sendRequest<T: Decodable>(endpoint: FiservTTPEndpoint,
                                            httpBody: Data?,
                                            responseModel: T.Type) async -> Result<T, FiservTTPRequestError> {
        
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // URL COMPONENTS
        var components = URLComponents()
        components.scheme = endpoint.scheme
        components.host = endpoint.host
        components.path = endpoint.path
        
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // HTTP URL
        guard let url = components.url else {
            return .failure(FiservTTPRequestError(message: "Invalid URL"))
        }
        
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // HTTP REQUEST
        var request = URLRequest(url: url)
        
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // HTTP METHOD
        request.httpMethod = endpoint.method.rawValue
        
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // HTTP BODY

        guard let body = httpBody else {
            return .failure(FiservTTPRequestError(message: "Missing Body"))
        }
        print("Request Body:\(String(data: body, encoding: .utf8) ?? "")")
        request.httpBody = body
        
        let bodyString = String(decoding: body, as: UTF8.self)
        
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // HTTP HEADERS
        let timestamp = timestamp
        
        let clientRequestId = clientRequestId
        
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        
        request.allHTTPHeaderFields = endpoint.httpHeaders(requestBody: bodyString,
                                                           clientRequestId: clientRequestId,
                                                           timestamp: timestamp)
        
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        
        do {
            
            let (data, response) = try await URLSession.shared.data(for: request)
            print("Raw: \(String(data: data, encoding: .utf8) ?? "")")
            guard let response = response as? HTTPURLResponse else {
                return .failure(FiservTTPRequestError(message: "No Response"))
            }
            
            switch response.statusCode {
                case 200...299:
                do {
                    let decoded = try JSONDecoder().decode(responseModel, from: data)
                    
                    return .success(decoded)
                    
                } catch let DecodingError.dataCorrupted(context) {
                    print(context)
                    return .failure(FiservTTPRequestError(message: "Decode Response", failureReason: ""))
                } catch let DecodingError.keyNotFound(key, context) {
                    print("Key '\(key)' not found:", context.debugDescription)
                    print("codingPath:", context.codingPath)
                    return .failure(FiservTTPRequestError(message: "Decode Response", failureReason: ""))
                } catch let DecodingError.valueNotFound(value, context) {
                    print("Value '\(value)' not found:", context.debugDescription)
                    print("codingPath:", context.codingPath)
                    return .failure(FiservTTPRequestError(message: "Decode Response", failureReason: ""))
                } catch let DecodingError.typeMismatch(type, context)  {
                    print("Type '\(type)' mismatch:", context.debugDescription)
                    print("codingPath:", context.codingPath)
                    return .failure(FiservTTPRequestError(message: "Decode Response", failureReason: ""))
                } catch {
                    return .failure(FiservTTPRequestError(message: "Decode Response", failureReason: error.localizedDescription))
                }
                
                default:
                
                return .failure(evaluateHttpStatusCode(statusCode: response.statusCode, data: data))
            }
        } catch {
            
            return .failure(FiservTTPRequestError(message: "Unknown Error", failureReason: error.localizedDescription))
        }
    }
}

extension String {
    func hexToData() -> Data? {
        var hex = self
        var data = Data()
        while !hex.isEmpty {
            let subHex = String(hex.prefix(2))
            hex = String(hex.dropFirst(2))
            guard let byte = UInt8(subHex, radix: 16) else {
                return nil
            }
            data.append(byte)
        }
        return data
    }
}

extension FiservTTPServices {
    
    var timestamp: Int64 {
        
        return Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
    }
    
    var clientRequestId: Int {
        
        return Int.random(in: 10000000..<100000000)
    }
}

extension FiservTTPServices {
    
    func evaluateHttpStatusCode(statusCode: Int, data: Data) -> FiservTTPRequestError {
        
        let serverMessage = String(decoding: data, as: UTF8.self)
        
        switch statusCode {
        case 400:
            return FiservTTPRequestError(message: "Bad Request.", failureReason: serverMessage)
        case 401:
            return FiservTTPRequestError(message: "Unauthorized", failureReason: serverMessage)
        case 404:
            return FiservTTPRequestError(message: "Not Found", failureReason: serverMessage)
        case 500:
            return FiservTTPRequestError(message: "Internal Error", failureReason: serverMessage)
        case 501:
            return FiservTTPRequestError(message: "Not Implemented", failureReason: serverMessage)
        case 502:
            return FiservTTPRequestError(message: "Bad Gateway", failureReason: serverMessage)
        case 503:
            return FiservTTPRequestError(message: "Service Unavailable", failureReason: serverMessage)
        case 504:
            return FiservTTPRequestError(message: "Gateway Timeout", failureReason: serverMessage)
        default:
            return FiservTTPRequestError(message: "Unexpected Error", failureReason: serverMessage)
        }
    }
}
