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
    
    case token(String, String)
    case charge(String, String)
    case inquiry(String, String)
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
            return "int.api.fiservapps.com"
        case .QA:
            return "qa.api.fiservapps.com"
        case .Sandbox:
            return "cert.api.fiservapps.com"
        case .Cat:
            return "cat.api.fiservapps.com"
        case .Production:
            return "connect.fiservapis.com"
        }
    }
    
    var path: String {
        switch self.fspath {
        case .token( let value, _):
            return value
        case .charge( let value, _):
            return value
        case .inquiry( let value, _):
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

protocol FiservTTPServicesProtocol {
    
    func requestSessionToken() async -> Result<FiservTTPTokenResponse, FiservTTPRequestError>
    
    func charge(amount: Decimal,
                currencyCode: String,
                merchantOrderId: String,
                merchantTransactionId: String,
                paymentCardReaderId: String,
                paymentCardReadResult: PaymentCardReadResult) async -> Result<FiservTTPChargeResponse, FiservTTPRequestError>
    
    func inquiry(referenceTransactionId: String?,
                 referenceMerchantTransactionId: String?,
                 referenceMerchantOrderId: String?,
                 referenceOrderId: String?) async -> Result<[FiservTTPChargeResponse], FiservTTPRequestError>
    
    func void(referenceTransactionId: String?,
              referenceMerchantTransactionId: String?,
              referenceTransactionType: String,
              total: Decimal,
              currencyCode: String) async -> Result<FiservTTPChargeResponse, FiservTTPRequestError>
    
    func refund(referenceTransactionId: String?,
                referenceMerchantTransactionId: String?,
                referenceTransactionType: String,
                total: Decimal,
                currencyCode: String) async -> Result<FiservTTPChargeResponse, FiservTTPRequestError>
    
    func refundCard(referenceTransactionId: String?,
                    referenceMerchantTransactionId: String?,
                    referenceTransactionType: String,
                    total: Decimal,
                    currencyCode: String,
                    paymentCardReaderId: String,
                    paymentCardReadResult: PaymentCardReadResult) async -> Result<FiservTTPChargeResponse, FiservTTPRequestError>
    
    func sendRequest<T: Decodable>(endpoint: FiservTTPEndpoint,
                                   httpBody: Data?,
                                   responseModel: T.Type) async -> Result<T, FiservTTPRequestError>
}

internal struct FiservTTPServices: FiservTTPServicesProtocol {
    
    private let tokenEndpoint: FiservTTPEndpoint
    private var chargeEndpoint: FiservTTPEndpoint
    private var inquiryEndpoint: FiservTTPEndpoint
    private var voidEndpoint: FiservTTPEndpoint
    private var refundEndpoint: FiservTTPEndpoint
    
    private let config: FiservTTPConfig
    
    internal init(config: FiservTTPConfig) {
        
        self.config = config
        
        self.tokenEndpoint = FiservTTPEndpoint(config: config,
                                               method: .post,
                                               path: .token("/ch/security/v1/ttpcredentials", "Token Request"))
        
        self.chargeEndpoint = FiservTTPEndpoint(config: config,
                                                method: .post,
                                                path: .charge("/ch/payments/v1/charges", "Charges Request"))
        
        self.inquiryEndpoint = FiservTTPEndpoint(config: config,
                                                 method: .post,
                                                 path: .charge("/ch/payments/v1/transaction-inquiry", "Inquiry Request"))
        
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

    internal func charge(amount: Decimal,
                        currencyCode: String,
                        merchantOrderId: String,
                        merchantTransactionId: String,
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
    
    internal func refundCard(referenceTransactionId: String? = nil,
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
                                 httpBody: bodyForRefundCardRequest(referenceTransactionId: referenceTransactionId,
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
    
    internal func bodyForTokenRequest() -> Data? {
        
        let merchantDetails = FiservTTPMerchantDetails(merchantId: self.config.merchantId,
                                                       terminalId: self.config.terminalId)
        
        let dynamicDescriptors = FiservTTPDynamicDescriptors(mcc: self.config.merchantCategoryCode,
                                                          merchantName: self.config.merchantName)
        
        let tokenRequest = FiservTTPTokenRequest(terminalProfileId: self.config.terminalProfileId,
                                                 channel: "ISV",
                                                 accessTokenTimeToLive: 172000,
                                                 dynamicDescriptors: dynamicDescriptors,
                                                 merchantDetails: merchantDetails,
                                                 appleTtpMerchantId: self.config.appleTtpMerchantId)
        
        let jsonEncoder = JSONEncoder()
        
        let encoded = try? jsonEncoder.encode(tokenRequest)
        
        return encoded
    }
    
    internal func bodyForChargeRequest(amount: Decimal,
                                       currencyCode: String,
                                       merchantOrderId: String,
                                       merchantTransactionId: String,
                                       paymentCardReaderId: String,
                                       generalCardData: String,
                                       paymentCardData: String,
                                       cardReaderTransactionId: String) -> Data? {
        
        let amount = FiservTTPChargeRequestAmount(total: amount, currency: currencyCode)
        
        let source = FiservTTPChargeRequestSource(sourceType: "AppleTapToPay",
                                                  generalCardData: generalCardData,
                                                  paymentCardData: paymentCardData,
                                                  cardReaderId: paymentCardReaderId,
                                                  cardReaderTransactionId: cardReaderTransactionId,
                                                  appleTtpMerchantId: self.config.appleTtpMerchantId)
        
        let transactionDetails = FiservTTPChargeRequestTransactionDetails(captureFlag: true,
                                                                          merchantOrderId: merchantOrderId,
                                                                          merchantTransactionId: merchantTransactionId)

        let posFeatures = FiservTTPChargeRequestPosFeatures(pinAuthenticationCapability: "CANNOT_ACCEPT_PIN",
                                                            terminalEntryCapability: "CONTACTLESS")
        
        let dataEntrySource = FiservTTPChargeRequestDataEntrySource(dataEntrySource: "MOBILE_TERMINAL",
                                                                    posFeatures: posFeatures)

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
                                                                  storeId: nil,
                                                                  siteId: nil,
                                                                  terminalId: self.config.terminalId,
                                                                  merchantId: self.config.merchantId)
            
            let inquiryRequest = FiservTTPInquiryRequest(referenceTransactionDetails: referenceTransactionDetails, merchantDetails: merchantDetails)
            
            let jsonEncoder = JSONEncoder()

            let encoded = try? jsonEncoder.encode(inquiryRequest)

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

    internal func bodyForRefundCardRequest(referenceTransactionId: String? = nil,
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
        
        let source = FiservTTPRefundCardRequestSource(sourceType: "AppleTapToPay",
                                                      generalCardData: generalCardData,
                                                      paymentCardData: paymentCardData,
                                                      cardReaderId: cardReaderId,
                                                      cardReaderTransactionId: cardReaderTransactionId,
                                                      appleTtpMerchantId: self.config.appleTtpMerchantId)
        
        let posFeatures = FiservTTPRefundCardRequestPosFeatures(pinAuthenticationCapability: "CANNOT_ACCEPT_PIN",
                                                                terminalEntryCapability: "CONTACTLESS")
        
        let dataEntrySource = FiservTTPRefundCardRequestDataEntrySource(dataEntrySource: "MOBILE_TERMINAL",
                                                                        posFeatures: posFeatures)
        
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
        
        let referenceTransactionDetails = FiservTTPRefundReferenceTransactionDetails(referenceTransactionId: referenceTransactionId,
                                                                                     referenceMerchantTransactionId: referenceMerchantTransactionId,
                                                                                     referenceTransactionType: referenceTransactionType)

        refundCardRequest = FiservTTPRefundCardRequest(amount: refundRequestAmount,
                                                       source: source,
                                                       referenceTransactionDetails: referenceTransactionDetails,
                                                       transactionInteraction: transactionInteraction,
                                                       merchantDetails: refundMerchantDetails,
                                                       additionalDataCommon: additionalDataCommon)
        
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

            guard let response = response as? HTTPURLResponse else {
                return .failure(FiservTTPRequestError(message: "No Response"))
            }
            
            switch response.statusCode {
                case 200...299:
                do {
                    let decoded = try JSONDecoder().decode(responseModel, from: data)
                    
                    return .success(decoded)
                    
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
