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

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// ERROR WRAPPER

public struct FiservTTPErrorWrapper: Identifiable {
    public let id: UUID
    public let error: FiservTTPCardReaderError
    public let guidance: String

    public init(id: UUID = UUID(), error: FiservTTPCardReaderError, guidance: String) {
        self.id = id
        self.error = error
        self.guidance = guidance
    }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// CHARGE RESPONSE WRAPPER

public struct FiservTTPResponseWrapper: Identifiable {
    public let id: UUID
    public let title: String
    public let response: FiservTTPChargeResponse?
    
    public init(id: UUID = UUID(), title: String, response: FiservTTPChargeResponse?) {
        self.id = id
        self.title = title
        self.response = response
    }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// CONFIGURATION

public struct FiservTTPConfig {
    public let secretKey: String
    public let apiKey: String
    public let environment: FiservTTPEnvironment
    public let currencyCode: String
    public let merchantId: String
    public let appleTtpMerchantId: String?
    public let merchantName: String
    public let merchantCategoryCode: String
    public let terminalId: String
    public let terminalProfileId: String

    /**
     Primary Configuration used for all requests

     - parameter secretKey:             Your provided Fiserv Secret Key
     - parameter apiKey:                Your provided Fiserv Api Key
     - parameter environment:           The destination for network requests (Sandbox or Production)
     - parameter currencyCode:          The Currency Code used for transactions
     - parameter merchantId:            Your MerchantId
     - parameter appleTtpMerchantId           Your apple TTP MerchantId (Optional)
     - parameter merchantName:          Your Merchant Name
     - parameter merchantCategoryCode:  Your MerchantId Category Code
     - parameter terminalId:            Your TerminalId
     - parameter terminalProfileId:     Your Terminal Profile Id
     
     - returns: FiservTTPConfig struct that will be used throughout the app lifecycle
     */
    public init(secretKey: String,
                apiKey: String,
                environment: FiservTTPEnvironment,
                currencyCode: String,
                merchantId: String,
                appleTtpMerchantId: String? = nil,
                merchantName: String,
                merchantCategoryCode: String,
                terminalId: String,
                terminalProfileId: String) {
        
        self.secretKey = secretKey
        self.apiKey = apiKey
        self.environment = environment
        self.currencyCode = currencyCode
        self.merchantId = merchantId
        self.appleTtpMerchantId = appleTtpMerchantId
        self.merchantName = merchantName
        self.merchantCategoryCode = merchantCategoryCode
        self.terminalId = terminalId
        self.terminalProfileId = terminalProfileId
    }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// AUTHENTICATION TOKEN REQUEST AND RESPONSE MODEL

internal struct FiservTTPMerchantDetails: Codable {
    let merchantId: String
    let terminalId: String
}

internal struct FiservTTPDynamicDescriptors: Codable {
    let mcc: String
    let merchantName: String
}

internal struct FiservTTPTokenRequest: Codable {
    let terminalProfileId: String
    let channel: String
    let accessTokenTimeToLive: Int
    let dynamicDescriptors: FiservTTPDynamicDescriptors
    let merchantDetails: FiservTTPMerchantDetails
    let appleTtpMerchantId: String?
}

public struct FiservTTPTokenResponse: Codable {
    public let gatewayResponse: FiservTTPChargeResponseGatewayResponse
    public let accessToken: String
    public let accessTokenTimeToLive: Int
    public let accessTokenType: String
}

// VALIDATE RESPONSE
public struct FiservTTPValidateCardResponse: Codable {
    
    let id: String
    public let generalCardData: String?
    public let paymentCardData: String?
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// INQUIRY REQUEST MODEL

internal struct FiservTTPInquiryReferenceTransactionDetails: Codable {
    
    let referenceTransactionId: String?
    let referenceMerchantTransactionId: String?
    let referenceMerchantOrderId: String?
    let referenceOrderId: String?
    let referenceClientRequestId: String?
    
    internal init(referenceTransactionId: String? = nil,
                  referenceMerchantTransactionId: String? = nil,
                  referenceMerchantOrderId: String? = nil,
                  referenceOrderId: String? = nil,
                  referenceClientRequestId: String? = nil) {
        
        self.referenceTransactionId = referenceTransactionId
        self.referenceMerchantTransactionId = referenceMerchantTransactionId
        self.referenceMerchantOrderId = referenceMerchantOrderId
        self.referenceOrderId = referenceOrderId
        self.referenceClientRequestId = referenceClientRequestId
    }
}

internal struct FiservTTPInquiryMerchantDetails: Codable {
    
    let tokenType: String?
    let storeId: String?
    let siteId: String?
    let terminalId: String?
    let merchantId: String?
    
    internal init(tokenType: String? = nil,
                  storeId: String? = nil,
                  siteId: String? = nil,
                  terminalId: String? = nil,
                  merchantId: String? = nil) {
        
        self.tokenType = tokenType
        self.storeId = storeId
        self.siteId = siteId
        self.terminalId = terminalId
        self.merchantId = merchantId
    }
}

internal struct FiservTTPInquiryRequest: Codable {
    let referenceTransactionDetails: FiservTTPInquiryReferenceTransactionDetails
    let merchantDetails: FiservTTPInquiryMerchantDetails
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// CHARGES REQUEST AND RESPONSE MODEL

internal struct FiservTTPChargeRequestAmount: Codable {
    let total: Decimal
    let currency: String
}

internal struct FiservTTPChargeRequestSource: Codable {
    let sourceType: String
    let generalCardData: String
    let paymentCardData: String
    let cardReaderId: String
    let cardReaderTransactionId: String
    let appleTtpMerchantId: String?
}

internal struct FiservTTPChargeRequestTransactionDetails: Codable {
    let captureFlag: Bool
    let merchantOrderId: String
    let merchantTransactionId: String
}

internal struct FiservTTPChargeRequestPosFeatures: Codable {
    let pinAuthenticationCapability: String
    let terminalEntryCapability: String
}

internal struct FiservTTPChargeRequestAdditionalDataCommon: Codable {
    let origin: FiservTTPChargeRequestAdditionalDataCommonProcessors
}

internal struct FiservTTPChargeRequestAdditionalDataCommonProcessors: Codable {
    let processors: FiservTTPChargeRequestAdditionalDataCommonProcessor
}

internal struct FiservTTPChargeRequestAdditionalDataCommonProcessor: Codable {
    let processorName: String
    let processingPlatform: String
    let settlementPlatform: String
    let priority: String
}

internal struct FiservTTPChargeRequestDataEntrySource: Codable {
    let dataEntrySource: String
    let posFeatures: FiservTTPChargeRequestPosFeatures
}

internal struct FiservTTPChargeRequestTransactionInteraction: Codable {
    let origin: String
    let posEntryMode: String
    let posConditionCode: String
    let additionalPosInformation: FiservTTPChargeRequestDataEntrySource
}

internal struct FiservTTPChargeRequest: Codable {
    let amount: FiservTTPChargeRequestAmount
    let source: FiservTTPChargeRequestSource
    let transactionDetails: FiservTTPChargeRequestTransactionDetails
    let transactionInteraction: FiservTTPChargeRequestTransactionInteraction
    let merchantDetails: FiservTTPMerchantDetails
    let additionalDataCommon: FiservTTPChargeRequestAdditionalDataCommon
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// VOID REQUEST AND RESPONSE MODEL

internal struct FiservTTPVoidRequestAmount: Codable {
    let total: Decimal
    let currency: String
}

internal struct FiservTTPVoidMerchantDetails: Codable {
    let terminalId: String
    let merchantId: String
}

internal struct FiservTTPVoidReferenceTransactionDetails: Codable {
    let referenceTransactionId: String?
    let referenceOrderId: String?
    let referenceMerchantTransactionId: String?
    let referenceMerchantOrderId: String?
    let referenceTransactionType: String
    
    internal init(referenceTransactionId: String? = nil,
                  referenceOrderId: String? = nil,
                  referenceMerchantTransactionId: String? = nil,
                  referenceMerchantOrderId: String? = nil,
                  referenceTransactionType: String) {
        self.referenceTransactionId = referenceTransactionId
        self.referenceOrderId = referenceOrderId
        self.referenceMerchantTransactionId = referenceMerchantTransactionId
        self.referenceMerchantOrderId = referenceMerchantOrderId
        self.referenceTransactionType = referenceTransactionType
    }
}

internal struct FiservTTPVoidRequest: Codable {
    let referenceTransactionDetails: FiservTTPVoidReferenceTransactionDetails
    let amount: FiservTTPVoidRequestAmount
    let merchantDetails: FiservTTPVoidMerchantDetails
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// REFUND REQUEST AND RESPONSE MODEL

internal struct FiservTTPRefundRequestAmount: Codable {
    let total: Decimal
    let currency: String
}

internal struct FiservTTPRefundMerchantDetails: Codable {
    let terminalId: String
    let merchantId: String
}

internal struct FiservTTPRefundReferenceTransactionDetails: Codable {
    let referenceTransactionId: String?
    let referenceOrderId: String?
    let referenceMerchantTransactionId: String?
    let referenceMerchantOrderId: String?
    let referenceTransactionType: String
    
    internal init(referenceTransactionId: String? = nil,
                  referenceOrderId: String? = nil,
                  referenceMerchantTransactionId: String? = nil,
                  referenceMerchantOrderId: String? = nil,
                  referenceTransactionType: String) {
        self.referenceTransactionId = referenceTransactionId
        self.referenceOrderId = referenceOrderId
        self.referenceMerchantTransactionId = referenceMerchantTransactionId
        self.referenceMerchantOrderId = referenceMerchantOrderId
        self.referenceTransactionType = referenceTransactionType
    }
}

internal struct FiservTTPRefundRequest: Codable {
    let referenceTransactionDetails: FiservTTPRefundReferenceTransactionDetails
    let amount: FiservTTPRefundRequestAmount
    let merchantDetails: FiservTTPRefundMerchantDetails
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// REFUND CARD REQUEST AND RESPONSE MODEL

internal struct FiservTTPRefundCardRequestAmount: Codable {
    let total: Decimal
    let currency: String
}

internal struct FiservTTPRefundCardRequestMerchantDetails: Codable {
    let merchantId: String
    let terminalId: String
}

internal struct FiservTTPRefundCardRequestSource: Codable {
    let sourceType: String
    let generalCardData: String
    let paymentCardData: String
    let cardReaderId: String
    let cardReaderTransactionId: String
    let appleTtpMerchantId: String?
}

internal struct FiservTTPRefundCardRequestPosFeatures: Codable {
    let pinAuthenticationCapability: String
    let terminalEntryCapability: String
}


internal struct FiservTTPRefundCardRequestAdditionalDataCommon: Codable {
    let origin: FiservTTPRefundCardRequestAdditionalDataCommonProcessors
}

internal struct FiservTTPRefundCardRequestAdditionalDataCommonProcessors: Codable {
    let processors: FiservTTPRefundCardRequestAdditionalDataCommonProcessor
}

internal struct FiservTTPRefundCardRequestAdditionalDataCommonProcessor: Codable {
    let processorName: String
    let processingPlatform: String
    let settlementPlatform: String
    let priority: String
}

internal struct FiservTTPRefundCardRequestDataEntrySource: Codable {
    let dataEntrySource: String
    let posFeatures: FiservTTPRefundCardRequestPosFeatures
}

internal struct FiservTTPRefundCardRequestTransactionInteraction: Codable {
    let origin: String
    let posEntryMode: String
    let posConditionCode: String
    let additionalPosInformation: FiservTTPRefundCardRequestDataEntrySource
}

internal struct FiservTTPRefundCardRequest: Codable {
    let amount: FiservTTPRefundCardRequestAmount
    let source: FiservTTPRefundCardRequestSource
    let referenceTransactionDetails: FiservTTPRefundReferenceTransactionDetails?
    let transactionInteraction: FiservTTPRefundCardRequestTransactionInteraction
    let merchantDetails: FiservTTPRefundCardRequestMerchantDetails
    let additionalDataCommon: FiservTTPRefundCardRequestAdditionalDataCommon
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

public struct FiservTTPServerError: Codable {
    public let gatewayResponse: FiservTTPServerErrorGatewayResponse
    public let error: [FiservTTPServerErrorError]?
}

public struct FiservTTPServerErrorGatewayResponse: Codable {
    public let transactionType: String?
    public let transactionState: String?
    public let transactionProcessingDetails: FiservTTPServerErrorTransactionProcessingDetails?
}

public struct FiservTTPServerErrorTransactionProcessingDetails: Codable {
    public let orderId: String?
    public let transactionTimestamp: String?
    public let apiTraceId: String?
    public let clientRequestId: String?
    public let transactionId: String?
}

public struct FiservTTPServerErrorError: Codable {
    public let type: String?
    public let field: String?
    public let code: String?
    public let message: String?
}

public struct FiservTTPChargeResponse: Codable {
    public let gatewayResponse: FiservTTPChargeResponseGatewayResponse?
    public let source: FiservTTPChargeResponseSource?
    public let paymentReceipt: FiservTTPChargeResponsePaymentReceipt?
    public let transactionDetails: FiservTTPChargeResponseTransactionDetails?
    public let transactionInteraction: FiservTTPChargeResponseTransactionInteraction?
    public let merchantDetails: FiservTTPChargeResponseMerchantDetails?
    public let networkDetails: FiservTTPChargeResponseNetworkDetails?
    public let cardDetails: FiservTTPChargeResponseCardDetails?
}

public struct FiservTTPChargeResponseGatewayResponse: Codable {
    public let transactionType: String?
    public let transactionState: String?
    public let transactionOrigin: String?
    public let transactionProcessingDetails: FiservTTPChargeResponseTransactionProcessingDetails?
}

public struct FiservTTPChargeResponseTransactionProcessingDetails: Codable {
    public let orderId: String?
    public let transactionTimestamp: String?
    public let apiTraceId: String?
    public let clientRequestId: String?
    public let transactionId: String?
}

public struct FiservTTPChargeResponseSource: Codable {
    public let sourceType: String?
    public let card: FiservTTPChargeResponseCard?
    public let emvData: String?
    public let generalCardData: String?
}

public struct FiservTTPChargeResponseCard: Codable {
    public let expirationMonth: String?
    public let expirationYear: String?
    public let bin: String?
    public let last4: String?
    public let scheme: String?
}

public struct FiservTTPChargeResponsePaymentReceipt: Codable {
    public let approvedAmount: FiservTTPChargeResponseApprovedAmount?
    public let processorResponseDetails: FiservTTPChargeResponseProcessorResponseDetails?
}

public struct FiservTTPChargeResponseApprovedAmount: Codable {
    public let total: Decimal?
    public let currency: String?
}

extension LosslessStringConvertible {
    var string: String { .init(self) }
}

extension FloatingPoint where Self: LosslessStringConvertible {
    var decimal: Decimal? { Decimal(string: string) }
}

extension FiservTTPChargeResponseApprovedAmount {

    enum CodingKeys: String, CodingKey {
        case total = "total"
        case currency = "currency"
    }

    public init(from decoder: Decoder) throws {

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.total = try container.decode(Double.self, forKey: .total).decimal ?? .zero

        self.currency = try container.decode(String.self, forKey: .currency)
    }
}

public struct FiservTTPChargeResponseProcessorResponseDetails: Codable {
    public let approvalStatus: String?
    public let approvalCode: String?
    public let referenceNumber: String?
    public let processor: String?
    public let host: String?
    public let networkRouted: String?
    public let networkInternationalId: String?
    public let responseCode: String?
    public let responseMessage: String?
    public let hostResponseCode: String?
    public let hostResponseMessage: String?
    public let responseIndicators: FiservTTPChargeResponseProcessorResponseIndicators?
    public let bankAssociationDetails: FiservTTPChargeResponseBankAssociationDetails?
    public let additionalInfo: [FiservTTPChargeResponseAdditionalInfo]?
}

public struct FiservTTPChargeResponseProcessorResponseIndicators: Codable {
    public let alternateRouteDebitIndicator: Bool?
    public let signatureLineIndicator: Bool?
    public let signatureDebitRouteIndicator: Bool?
}

public struct FiservTTPChargeResponseBankAssociationDetails: Codable {
    public let associationResponseCode: String?
}

public struct FiservTTPChargeResponseAdditionalInfo: Codable {
    public let name: String?
    public let value: String?
}

public struct FiservTTPChargeResponseTransactionDetails: Codable {
    public let captureFlag: Bool?
    public let transactionCaptureType: String?
    public let authentication3DS: Bool?
    public let processingCode: String?
    public let merchantTransactionId: String?
    public let merchantOrderId: String?
    public let createToken: Bool?
    public let retrievalReferenceNumber: String?
}

public struct FiservTTPChargeResponseTransactionInteraction: Codable {
    public let posEntryMode: String?
    public let posConditionCode: String?
    public let additionalPosInformation: FiservTTPChargeResponseAdditionalPosInformation?
    public let authorizationCharacteristicsIndicator: String?
    public let hostPosEntryMode: String?
    public let hostPosConditionCode: String?
}

public struct FiservTTPChargeResponseAdditionalPosInformation: Codable {
    public let stan: String?
    public let dataEntrySource: String?
    public let posFeatures: FiservTTPChargeResponsePosFeatures?
}

public struct FiservTTPChargeResponsePosFeatures: Codable {
    public let pinAuthenticationCapability: String?
    public let terminalEntryCapability: String?
}

public struct FiservTTPChargeResponseMerchantDetails: Codable {
    public let tokenType: String?
    public let terminalId: String?
    public let merchantId: String?
}

public struct FiservTTPChargeResponseNetworkDetails: Codable {
    public let network: FiservTTPChargeResponseNetwork?
    public let networkResponseCode: String?
    public let cardLevelResultCode: String?
    public let validationCode: String?
    public let transactionIdentifier: String?
}

public struct FiservTTPChargeResponseNetwork: Codable {
    public let network: String?
    public let cardAuthenticationResultCode: String?
}

public struct FiservTTPChargeResponseCardDetails: Codable {
    public let recordType: String?
    public let lowBin: String?
    public let highBin: String?
    public let binLength: String?
    public let binDetailPan: String?
    public let issuerBankName: String?
    public let countryCode: String?
    public let detailedCardProduct: String?
    public let detailedCardIndicator: String?
    public let pinSignatureCapability: String?
    public let issuerUpdateYear: String?
    public let issuerUpdateMonth: String?
    public let issuerUpdateDay: String?
    public let regulatorIndicator: String?
    public let cardClass: String?
    public let debitPinlessIndicator: [FiservTTPChargeResponseDebitPinlessIndicator]?
    public let nonMoneyTransferOCTsDomestic: String?
    public let nonMoneyTransferOCTsCrossBorder: String?
    public let onlineGamblingOCTsDomestic: String?
    public let onlineGamblingOCTsCrossBorder: String?
    public let moneyTransferOCTsDomestic: String?
    public let moneyTransferOCTsCrossBorder: String?
    public let fastFundsDomesticMoneyTransfer: String?
    public let fastFundsCrossBorderMoneyTransfer: String?
    public let fastFundsDomesticNonMoneyTransfer: String?
    public let fastFundsCrossBorderNonMoneyTransfer: String?
    public let fastFundsDomesticGambling: String?
    public let fastFundsCrossBorderGambling: String?
    public let productId: String?
    public let accountFundSource: String?
    public let panLengthMin: String?
    public let panLengthMax: String?
}

public struct FiservTTPChargeResponseDebitPinlessIndicator: Codable {
    public let debitNetworkId: String?
    public let pinnedPOS: String?
}
