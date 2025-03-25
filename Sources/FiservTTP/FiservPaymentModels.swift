//  FiservPaymentModels
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

public struct Models {
    
    public struct DynamicDescriptorsRequest: Codable {
        public let merchantCategoryCode: String
        public let merchantName: String
        
        public init(merchantCategoryCode: String, merchantName: String) {
            self.merchantCategoryCode = merchantCategoryCode
            self.merchantName = merchantName
        }
    }
    
    public struct MerchantDetailsRequest: Codable {
        public let merchantId: String
        public let terminalId: String
        
        public init(merchantId: String, terminalId: String) {
            self.merchantId = merchantId
            self.terminalId = terminalId
        }
    }
    
    public struct SourceRequest: Codable {
        public let sourceType: String
        public let generalCardData: String?
        public let paymentCardData: String?
        public let cardReaderId: String?
        public let cardReaderTransactionId: String?
        public let appleTtpMerchantId: String?
        
        public init(sourceType: String,
                    generalCardData: String?,
                    paymentCardData: String?,
                    cardReaderId: String?,
                    cardReaderTransactionId: String?,
                    appleTtpMerchantId: String?) {
            
            self.sourceType = sourceType
            self.generalCardData = generalCardData
            self.paymentCardData = paymentCardData
            self.cardReaderId = cardReaderId
            self.cardReaderTransactionId = cardReaderTransactionId
            self.appleTtpMerchantId = appleTtpMerchantId
        }
    }
    
    public struct TransactionDetailsRequest: Codable {
        
        public let merchantTransactionId: String?
        public let merchantOrderId: String?
        public let merchantInvoiceNumber: String?
        public let captureFlag: Bool
        public let createToken: Bool
        
        public init(merchantTransactionId: String? = nil,
                    merchantOrderId: String? = nil,
                    merchantInvoiceNumber: String? = nil,
                    captureFlag: Bool = false,
                    createToken: Bool = false) {
            self.merchantTransactionId = merchantTransactionId
            self.merchantOrderId = merchantOrderId
            self.merchantInvoiceNumber = merchantInvoiceNumber
            self.captureFlag = captureFlag
            self.createToken = createToken
        }
    }
    
    public struct ReferenceTransactionDetailsRequest: Codable {
        
        public let referenceTransactionId: String?
        public let referenceMerchantTransactionId: String?
        public let referenceOrderId: String?
        public let referenceMerchantOrderId: String?
        public let referenceClientRequestId: String?
        
        public init(referenceTransactionId: String? = nil,
                    referenceMerchantTransactionId: String? = nil,
                    referenceOrderId: String? = nil,
                    referenceMerchantOrderId: String? = nil,
                    referenceClientRequestId: String? = nil) {
            
            self.referenceTransactionId = referenceTransactionId
            self.referenceMerchantTransactionId = referenceMerchantTransactionId
            self.referenceOrderId = referenceOrderId
            self.referenceMerchantOrderId = referenceMerchantOrderId
            self.referenceClientRequestId = referenceClientRequestId
        }
    }
    
    // RESPONSE
    public struct TransactionProcessingDetailsResponse: Codable {
        public let orderId: String?
        public let transactionTimestamp: String?
        public let apiTraceId: String?
        public let clientRequestId: String?
        public let transactionId: String?
        public let apiKey: String?
    }

    public struct GatewayResponse: Codable {
        public let transactionType: String?
        public let transactionState: String?
        public let transactionOrigin: String?
        public let transactionProcessingDetails: TransactionProcessingDetailsResponse?
    }
    
    public struct CardResponse: Codable {
        public let expirationMonth: String?
        public let expirationYear: String?
        public let bin: String?
        public let last4: String?
        public let scheme: String?
    }
    
    public struct SourceResponse: Codable {
        public let sourceType: String?
        public let hasBeenDecrypted: Bool?
        public let card: CardResponse?
        public let emvData: String?
        public let generalCardData: String?
    }
    
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // AUTHENTICATION
    
    // REQUEST
    public struct AuthenticateRequest: Codable {
        public let terminalProfileId: String
        public let channel: String
        public let accessTokenTimeToLive: Int
        public let dynamicDescriptorsRequest: Models.DynamicDescriptorsRequest
        public let merchantDetailsRequest: Models.MerchantDetailsRequest
        public let appleTtpMerchantId: String?
        
        public init(terminalProfileId: String,
                    channel: String,
                    accessTokenTimeToLive: Int,
                    dynamicDescriptorsRequest: Models.DynamicDescriptorsRequest,
                    merchantDetailsRequest: MerchantDetailsRequest,
                    appleTtpMerchantId: String?) {

            self.terminalProfileId = terminalProfileId
            self.channel = channel
            self.accessTokenTimeToLive = accessTokenTimeToLive
            self.dynamicDescriptorsRequest = dynamicDescriptorsRequest
            self.merchantDetailsRequest = merchantDetailsRequest
            self.appleTtpMerchantId = appleTtpMerchantId
        }
    }
    
    // RESPONSE
    public struct AuthenticateResponse: Codable {
        public let gatewayResponse: GatewayResponse
        public let accessToken: String
        public let accessTokenTimeToLive: Int
        public let accessTokenType: String
    }
    
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // CARD VERIFICATION RESPONSE (APPLE PROXIMITY READER)
    
    public struct CardVerificationResponse: Codable {
        public let cardReaderId: String
        public let transactionId: String
        public let generalCardData: String
        public let paymentCardData: String
    }
    
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // ACCOUNT VERIFICATION REQUEST
    
    public struct AddressRequest: Codable {
        public let street: String
        public let houseNumberOrName: String
        public let city: String
        public let stateOrProvince: String
        public let postalCode: String
        public let country: String
        
        public init(street: String, houseNumberOrName: String, city: String, stateOrProvince: String, postalCode: String, country: String) {
            self.street = street
            self.houseNumberOrName = houseNumberOrName
            self.city = city
            self.stateOrProvince = stateOrProvince
            self.postalCode = postalCode
            self.country = country
        }
    }
        
    public struct BillingAddressRequest: Codable {
        public let firstName: String
        public let lastName: String
        public let address: AddressRequest?
        
        public init(firstName: String, lastName: String, addressRequest: AddressRequest? = nil) {
            
            self.firstName = firstName
            self.lastName = lastName
            self.address = addressRequest
        }
    }
    
    public struct PosFeaturesRequest: Codable {
        public let pinAuthenticationCapability: String
        public let terminalEntryCapability: String
        
        public init(pinAuthenticationCapability: String,
                    terminalEntryCapability: String) {
            
            self.pinAuthenticationCapability = pinAuthenticationCapability
            self.terminalEntryCapability = terminalEntryCapability
        }
    }
    
    public struct PosHardwareAndSoftwareRequest: Codable {
        public let softwareApplicationName: String
        public let softwareVersionNumber: String
        public let hardwareVendorIdentifier: String
        
        public init(softwareApplicationName: String,
                    softwareVersionNumber: String,
                    hardwareVendorIdentifier: String) {
            
            self.softwareApplicationName = softwareApplicationName
            self.softwareVersionNumber = softwareVersionNumber
            self.hardwareVendorIdentifier = hardwareVendorIdentifier
        }
    }
    
    public struct DataEntrySourceRequest: Codable {
        public let dataEntrySource: String
        public let posFeatures: PosFeaturesRequest
        public let posHardwareAndSoftware : PosHardwareAndSoftwareRequest?
        
        public init(dataEntrySource: String,
                    posFeatures: PosFeaturesRequest,
                    posHardwareAndSoftware: PosHardwareAndSoftwareRequest?) {
            
            self.dataEntrySource = dataEntrySource
            self.posFeatures = posFeatures
            self.posHardwareAndSoftware = posHardwareAndSoftware
        }
    }
    
    public struct TransactionInteractionRequest: Codable {
        public let origin: String
        public let posEntryMode: String
        public let posConditionCode: String
        public let additionalPosInformation: Models.DataEntrySourceRequest?
        
        public init(origin: String,
                    posEntryMode: String,
                    posConditionCode: String,
                    additionalPosInformation: Models.DataEntrySourceRequest?) {
            
            self.origin = origin
            self.posEntryMode = posEntryMode
            self.posConditionCode = posConditionCode
            self.additionalPosInformation = additionalPosInformation
        }
    }
    
    public struct AccountVerificationRequest: Codable {
        public let source: SourceRequest
        public let transactionDetails: TransactionDetailsRequest
        public let transactionInteraction: TransactionInteractionRequest
        public let billingAddress: BillingAddressRequest?
        public let merchantDetails: MerchantDetailsRequest
        
        public init(source: SourceRequest,
                    transactionDetails: TransactionDetailsRequest,
                    transactionInteraction: TransactionInteractionRequest,
                    billingAddress: BillingAddressRequest?,
                    merchantDetails: MerchantDetailsRequest) {
            self.source = source
            self.transactionDetails = transactionDetails
            self.transactionInteraction = transactionInteraction
            self.billingAddress = billingAddress
            self.merchantDetails = merchantDetails
        }
    }
    
    public struct AccountVerificationTokenRequest: Codable {
        public let source: Models.PaymentTokenSourceRequest
        public let transactionDetails: TransactionDetailsRequest
        public let transactionInteraction: TransactionInteractionRequest
        public let billingAddress: BillingAddressRequest?
        public let merchantDetails: MerchantDetailsRequest
        
        public init(source: Models.PaymentTokenSourceRequest,
                    transactionDetails: TransactionDetailsRequest,
                    transactionInteraction: TransactionInteractionRequest,
                    billingAddress: BillingAddressRequest?,
                    merchantDetails: MerchantDetailsRequest) {
            self.source = source
            self.transactionDetails = transactionDetails
            self.transactionInteraction = transactionInteraction
            self.billingAddress = billingAddress
            self.merchantDetails = merchantDetails
        }
    }
    
    // ACCOUNT VERIFICATION RESPONSE
    
    public struct MerchantDetailsResponse: Codable {
        public let tokenType: String?
        public let terminalId: String?
        public let merchantId: String?
    }
    
    public struct PosFeaturesResponse: Codable {
        public let pinAuthenticationCapability: String?
        public let PINcaptureCapability: String?
        public let terminalEntryCapability: String?
    }
    
    public struct AdditionalPosInformationResponse: Codable {
        public let dataEntrySource: String?
        public let stan: String?
        public let posFeatures: PosFeaturesResponse?
        public let cardPresentIndicator: String?
        public let cardPresentAtPosIndicator: String?
    }
    
    public struct TransactionInteractionResponse: Codable {
        public let posEntryMode: String?
        public let posConditionCode: String?
        public let posData: String?
        public let cardholderAuthenticationMethod: String?
        public let authorizationCharacteristicsIndicator: String?
        public let cardholderAuthenticationEntity: String?
        public let hostPosConditionCode: String?
        public let additionalPosInformation: AdditionalPosInformationResponse?
        public let cardPresentIndicator: String?
        public let cardPresentAtPosIndicator: String?
    }
    
    public struct TransactionDetailsResponse: Codable {
        public let captureFlag: Bool?
        public let transactionCaptureType: String?
        public let authentication3DS: Bool?
        public let processingCode: String?
        public let merchantTransactionId: String?
        public let merchantOrderId: String?
        public let merchantInvoiceNumber: String?
        public let createToken: Bool?
        public let retrievalReferenceNumber: String?
    }
    
    public struct BillingAddressResponse: Codable {
        public let firstName: String?
        public let lastName: String?
    }
    
    public struct AvsCodeResponse: Codable {
        public let avsCode: String?
    }
    
    public struct AvsSecurityCodeResponse: Codable {
        public let streetMatch: String?
        public let postalCodeMatch: String?
        public let securityCodeMatch: String?
        public let association: AvsCodeResponse?
    }
    
    public struct BankAssociationDetailsResponse: Codable {
        public let associationResponseCode: String?
        public let avsSecurityCodeResponse: AvsSecurityCodeResponse?
    }
    
    public struct AdditionalInfoResponse: Codable {
        public let name: String?
        public let value: String?
    }

    public struct AccountVerificationResponse: Codable {
        public let gatewayResponse: GatewayResponse?
        public let processorResponseDetails: ProcessorResponseDetailsResponse?
        public let source: SourceResponse?
        public let billingAddress: BillingAddressResponse?
        public let transactionDetails: TransactionDetailsResponse?
        public let transactionInteraction: TransactionInteractionResponse?
        public let merchantDetails: MerchantDetailsResponse?
        public let paymentTokens: [PaymentTokenResponse]?
        
        public let error: ServerErrorResponse?
    }
    
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // TOKENIZE REQUEST
    
    public struct TokenizeCardRequest: Codable {
        public let source: SourceRequest
        public let transactionDetails: TransactionDetailsRequest
        public let merchantDetails: MerchantDetailsRequest
        
        public init(source: SourceRequest,
                    transactionDetails: TransactionDetailsRequest,
                    merchantDetails: MerchantDetailsRequest) {
            
            self.source = source
            self.transactionDetails = transactionDetails
            self.merchantDetails = merchantDetails
        }
    }
    
    // TOKENIZE RESPONSE
    
    public struct PaymentTokenResponse: Codable {
        public let tokenData: String?
        public let tokenSource: String?
        public let tokenResponseCode: String?
        public let tokenResponseDescription: String?
    }
    
    public struct TokenizeCardResponse: Codable {
        public let gatewayResponse: GatewayResponse?
        public let source: SourceResponse?
        public let paymentTokens: [PaymentTokenResponse]?
        public let cardDetails: CardDetailsResponse?
        public let processorResponseDetails: ProcessorResponseDetailsResponse?
        public let error: ServerErrorResponse?
    }
    
    public struct AdditionalDataCommonProcessorRequest: Codable {
        public let processorName: String
        public let processingPlatform: String
        public let settlementPlatform: String
        public let priority: String
        
        public init(processorName: String,
                    processingPlatform: String,
                    settlementPlatform: String,
                    priority: String) {
            
            self.processorName = processorName
            self.processingPlatform = processingPlatform
            self.settlementPlatform = settlementPlatform
            self.priority = priority
        }
    }
    
    public struct AdditionalDataCommonProcessorsRequest: Codable {
        public let processors: AdditionalDataCommonProcessorRequest
        
        public init(processors: AdditionalDataCommonProcessorRequest) {
            self.processors = processors
        }
    }

    public struct AdditionalDataCommonRequest: Codable {
        public let origin: AdditionalDataCommonProcessorsRequest
        
        public init(origin: AdditionalDataCommonProcessorsRequest) {
            self.origin = origin
        }
    }
    
    public struct AmountRequest: Codable {
        public let total: Decimal
        public let currency: String
        
        public init(total: Decimal,
                    currency: String) {
            
            self.total = total
            self.currency = currency
        }
    }
    
    public struct PaymentTokenCardRequest: Codable {
        public let expirationMonth: String
        public let expirationYear: String
        
        public init(expirationMonth: String, expirationYear: String) {
            self.expirationMonth = expirationMonth
            self.expirationYear = expirationYear
        }
    }
    
    public struct PaymentTokenSourceRequest: Codable {
        public let sourceType: String
        public let tokenData:String
        public let tokenSource: String
        public let declineDuplicates: Bool
        public let card: PaymentTokenCardRequest
        
        public init(sourceType: String,
                    tokenData: String,
                    tokenSource: String,
                    declineDuplicates: Bool,
                    card: PaymentTokenCardRequest) {
            
            self.sourceType = sourceType
            self.tokenData = tokenData
            self.tokenSource = tokenSource
            self.declineDuplicates = declineDuplicates
            self.card = card
        }
    }
    
    public struct PaymentTokenChargeRequest: Codable {
        public let amount: Models.AmountRequest
        public let source: Models.PaymentTokenSourceRequest?
        public let transactionDetails: Models.TransactionDetailsRequest
        public let transactionInteraction: Models.TransactionInteractionRequest
        public let merchantDetails: Models.MerchantDetailsRequest
        
        public init(amount: Models.AmountRequest,
                    source: Models.PaymentTokenSourceRequest?,
                    transactionDetails: Models.TransactionDetailsRequest,
                    transactionInteraction: Models.TransactionInteractionRequest,
                    merchantDetails: Models.MerchantDetailsRequest) {
            
            self.amount = amount
            self.source = source
            self.transactionDetails = transactionDetails
            self.transactionInteraction = transactionInteraction
            self.merchantDetails = merchantDetails
        }
    }

    public struct ChargesRequest: Codable {
        public let amount: Models.AmountRequest
        public let source: Models.SourceRequest?
        public let merchantDetails: Models.MerchantDetailsRequest
        public let transactionDetails: Models.TransactionDetailsRequest
        public let referenceTransactionDetails: Models.ReferenceTransactionDetailsRequest?
        public let transactionInteraction: Models.TransactionInteractionRequest?
        public let additionalDataCommon: AdditionalDataCommonRequest?
        
        public init(amount: Models.AmountRequest,
                    source: Models.SourceRequest?,
                    merchantDetails: Models.MerchantDetailsRequest,
                    transactionDetails: Models.TransactionDetailsRequest,
                    referenceTransactionDetails: Models.ReferenceTransactionDetailsRequest?,
                    transactionInteraction: Models.TransactionInteractionRequest?,
                    additionalDataCommon: AdditionalDataCommonRequest?) {
            
            self.amount = amount
            self.source = source
            self.merchantDetails = merchantDetails
            self.transactionDetails = transactionDetails
            self.referenceTransactionDetails = referenceTransactionDetails
            self.transactionInteraction = transactionInteraction
            self.additionalDataCommon = additionalDataCommon
        }
    }
    
    public struct CommerceHubResponse: Codable {
        public let gatewayResponse: GatewayResponse?
        public let source: SourceResponse?
        public let paymentReceipt: PaymentReceiptResponse?
        public let transactionDetails: TransactionDetailsResponse?
        public let transactionInteraction: TransactionInteractionResponse?
        public let merchantDetails: MerchantDetailsResponse?
        public let networkDetails: NetworkDetailsResponse?
        public let cardDetails: CardDetailsResponse?
        public let paymentTokens: [PaymentTokenResponse]?
        public let error: ServerErrorResponse?
    }

    public struct CancelsRequest: Codable {
        public let amount: Models.AmountRequest
        public let merchantDetails: Models.MerchantDetailsRequest
        public let referenceTransactionDetails: Models.ReferenceTransactionDetailsRequest
        
        public init(amount: Models.AmountRequest,
                    merchantDetails: Models.MerchantDetailsRequest,
                    referenceTransactionDetails: Models.ReferenceTransactionDetailsRequest) {
            
            self.amount = amount
            self.merchantDetails = merchantDetails
            self.referenceTransactionDetails = referenceTransactionDetails
        }
    }
    
    public struct RefundsRequest: Codable {
        public let amount: Models.AmountRequest
        public let source: Models.SourceRequest?
        public let merchantDetails: Models.MerchantDetailsRequest
        public let transactionDetails: Models.TransactionDetailsRequest?
        public let referenceTransactionDetails: Models.ReferenceTransactionDetailsRequest?
        public let transactionInteraction: Models.TransactionInteractionRequest?
        public let additionalDataCommon: AdditionalDataCommonRequest?
        
        public init(amount: Models.AmountRequest,
                    source: Models.SourceRequest?,
                    merchantDetails: Models.MerchantDetailsRequest,
                    transactionDetails: Models.TransactionDetailsRequest?,
                    referenceTransactionDetails: Models.ReferenceTransactionDetailsRequest?,
                    transactionInteraction: Models.TransactionInteractionRequest?,
                    additionalDataCommon: AdditionalDataCommonRequest?) {
            
            self.amount = amount
            self.source = source
            self.merchantDetails = merchantDetails
            self.transactionDetails = transactionDetails
            self.referenceTransactionDetails = referenceTransactionDetails
            self.transactionInteraction = transactionInteraction
            self.additionalDataCommon = additionalDataCommon
        }
    }
    
    public struct ApprovedAmountResponse: Codable {
        public let total: Decimal?
        public let currency: String?
    }
    
    public struct ProcessorResponseIndicatorsResponse: Codable {
        public let alternateRouteDebitIndicator: Bool?
        public let signatureLineIndicator: Bool?
        public let signatureDebitRouteIndicator: Bool?
    }
    
    public struct ProcessorResponseDetailsResponse: Codable {
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
        public let responseIndicators: ProcessorResponseIndicatorsResponse?
        public let bankAssociationDetails: BankAssociationDetailsResponse?
        public let additionalInfo: [AdditionalInfoResponse]?
    }
    
    public struct PaymentReceiptResponse: Codable {
        public let approvedAmount: ApprovedAmountResponse?
        public let processorResponseDetails: ProcessorResponseDetailsResponse?
    }
    
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // TRANSACTION INQUIRY REQUEST
    public struct TransactionInquiryRequest: Codable {
        public let referenceTransactionDetails: ReferenceTransactionDetailsRequest
        public let merchantDetails: MerchantDetailsRequest
        
        public init(referenceTransactionDetails: ReferenceTransactionDetailsRequest,
                    merchantDetails: MerchantDetailsRequest) {
            
            self.referenceTransactionDetails = referenceTransactionDetails
            self.merchantDetails = merchantDetails
        }
    }
    
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // INQUIRY RESPONSE
    
    public struct ErrorResponse: Codable {
        public let type: String?
        public let field: String?
        public let code: String?
        public let message: String?
    }
    
    public struct ServerErrorResponse: Codable {
        public let gatewayResponse: GatewayErrorResponse
        public let error: [ErrorResponse]?
    }

    public struct GatewayErrorResponse: Codable {
        public let transactionType: String?
        public let transactionState: String?
        public let transactionProcessingDetails: TransactionProcessingDetailsResponse?
    }

    public struct DebitPinlessIndicatorResponse: Codable {
        public let debitNetworkId: String?
        public let pinnedPOS: String?
    }
    
    public struct CardDetailsResponse: Codable {
        public let binSource: String?
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
        public let debitPinlessIndicator: [DebitPinlessIndicatorResponse]?
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
    
    public struct NetworkResponse: Codable {
        public let network: String?
        public let cardAuthenticationResultCode: String?
    }
    
    public struct NetworkDetailsResponse: Codable {
        public let network: NetworkResponse?
        public let debitNetworkId: String?
        public let networkResponseCode: String?
        public let cardLevelResultCode: String?
        public let validationCode: String?
        public let transactionIdentifier: String?
    }
    
    public struct InquireResponse: Codable {
        public let gatewayResponse: GatewayResponse?
        public let source: SourceResponse?
        public let paymentReceipt: PaymentReceiptResponse?
        public let transactionDetails: TransactionDetailsResponse?
        public let transactionInteraction: TransactionInteractionResponse?
        public let merchantDetails: MerchantDetailsResponse?
        public let networkDetails: NetworkDetailsResponse?
        public let cardDetails: CardDetailsResponse?
        public let paymentTokens: [PaymentTokenResponse]?
        public let error: ServerErrorResponse?
    }
}

extension Models.ApprovedAmountResponse {

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
