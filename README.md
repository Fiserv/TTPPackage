# Tap to Pay on iPhone SDK by Fiserv

## Purpose
This Package is an SDK that facilitates enabling Apple's Tap To Pay on iPhone functionality in your own app.  With just a bit of configuration and a few lines of code, your iPhone app will be able to securely accept contactless payments on a supported iPhone without any additional hardware (e.g. POS terminal, external card reader device, etc.)  

Currently this functionality is only available in the U.S.

By using this Package, you will *not* need to certify your app.   We have taken care of that for you.


## Pre-requisites


### Device Requirements 
Apple Tap to Pay on iPhone requires iPhone XS or later.

| Transaction Type             | Minimum iOS Version                                                                |   
|------------------------------|------------------------------------------------------------------------------------|
| Credit                       | iOS 16.7                                                                           |
| Debit                        | iOS 16.7                                                                           |


### Tap to Pay Entitlement
You must request a special entitlement from Apple to enable Tap To Pay.  Log-into your Apple Developer Account and then [click here](https://developer.apple.com/contact/request/tap-to-pay-on-iphone) to request the entitlement.  In the text box titled 'PSP, enter 'Fiserv' as the value.

Follow the instructions here to [add the entitlement to your app's profile](https://developer.apple.com/documentation/proximityreader/setting-up-the-entitlement-for-tap-to-pay-on-iphone)

### Obtain Fiserv Credentials
You can obtain test credentials for your app on [Fiserv's Developer Studio](https://developer.fiserv.com) by following these directions:

1. Create an account by clicking the orange button in the upper right of the page
2. Log-into [Developer Studio](https://developer.fiserv.com) with your email address/password
3. Click the Workspaces option in the top toolbar
4. Tap the button 'Add New Workspace'
5. Create a workspace of type 'CommerceHub'.  Provide a name and description, then select 'CommerceHub' from the 'Product' drop-down list
6. Click the 'Create Button'
7. In the Workspace, click the 'Credentials' tab
8. Click the 'Create API key'. You will need to select a Merchant Id from the drop-down, provide a name for the API Key, click the 'Sandbox' radio button from the 'API Key Type' list, and select 'Payments' in the 'Features' checkboxes.  Click the 'Create' button.
9. Important!  Copy the full API Key and Secret and store them __securely__.  Or, you can click the 'Save to File' button to download them into a file.   You will need these credentials to access the Fiserv SDK and back-end API's.  Protect these credentials in your code and in your app.


## Getting Started


### CocoaPods

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate Alamofire into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'FiservTTP'
```

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler.

Create a new project or open your existing app in XCode.

Add the Fiserv Package to your app by following these instructions:
1. With your app open in Xcode, select File->Add Packages...
2. In the search bar in the upper-right, enter the Package Url: `https://github.com/Fiserv/TTPPackage`
3. Click the 'Add Package' button at the bottom of the screen
4. Click 'Add Package' one more time.  The Package will be downloaded and added to your project

### Configure the Card Reader 

Create an instance of `FiservTTPConfig` and load it with your configuration as follows:

```Swift
let myConfig = FiservTTPConfig(
    secretKey: "<your secret key from Developer Studio>",
    apiKey: "<your API key from Developer Studio>",
    environment: .Sandbox,
    currencyCode: "USD",
    appleTtpMerchantId: "<optional apple ttp merchantId provided by fiserv>",
    merchantId: "<your merchantId from the CommerceHub workspace on Developer Studio>",
    merchantName: "<your merchant name as it will be displayed in the Tap to Pay payment sheet>",
    merchantCategoryCode: "<your MCC>",
    terminalId: "10000001", /// Identifies the specific device or point of entry where the transaction originated assigned by the acquirer or the gateway
    terminalProfileId: "3c00e000-a00e-2043-6d63-936859000002") /// Unique identifier for the terminal profile used to configure the kernels of the card reader and manage payment terminal behavior
```

Now create an instance of `FiservTTPCardReader`, which is the main class that your app will interact with.  Typically you would put this in a view model.

```Swift
private let fiservTTPCardReader: FiservTTPCardReader = FiservTTPCardReader(configuration: myConfig)
```

Early in the startup process of your app, call the following method to validate that the device running your app is supported for Apple Tap To Pay on iPhone:

```Swift
if !fiservTTPCardReader.readerIsSupported() {
    // TODO handle unsupported device
}
```

### Obtain PSP Token

You must obtain a session token in order to utilize the SDK.  Acquire the token by making this call:

```Swift
do {
    try await fiservTTPCardReader.requestSessionToken()
} catch let error as FiservTTPCardReaderError {
    // TODO handle exception
}
```

Note that the session token has a time to live of 48 hours. However, we have included an **auto-refresh feature** that will request a new token for you when the TTL value is 30 minutes or less. Moving the app from the background to the foreground, as well as unlocking (a locked iPhone) will trigger this check and the refresh will occur based on the time remaining of the token. 

Additional information can be found here:
[Commerce Hub Security](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Security/Credentials.md&branch=main#endpoint)

### Link Account
Next you must link the device running the app to an Apple ID. This needs to happen **just once**.  You are responsible for tracking whether the linking process has occurred already or not.  If not, then perform linking by making this call:

```Swift
do {
    try await fiservTTPCardReader.linkAcount()
} catch let error as FiservTTPCardReaderError {
    // TODO handle exception
}
```

### Is Account Linked
When targeting iOS 16.4 or greater, the option to check if the account is already linked is available.

```Swift
do {
    let isLinked = try await fiservTTPCardReader.isAccountLinked()
} catch let error as FiservTTPCardReaderError {
    // TODO handle exception
}
```

Additional information can be found here:
[isAccountLinked](https://developer.apple.com/documentation/proximityreader/paymentcardreader/isaccountlinked\(using:\))

### Initialize the Card Reader Session
Now you're ready to initialize the Apple Proximity Reader by calling:

```Swift
do {
    try await fiservTTPCardReader.initializeSession()
} catch let error as FiservTTPCardReaderError {
    // TODO handle exception
}
```

**NOTE:** that you must re-initialize the reader session each time the app starts.

**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**

### 😀 Account Verification API

**INTERNAL NOTE ONLY**

**CommerceHub supports paymentToken for Account Verification**

**Need to know if we should support it here**

```SWift
public func accountVerification(transactionDetailsRequest: Models.TransactionDetailsRequest,
                                paymentTokenSourceRequest: Models.PaymentTokenSourceRequest? = nil,
                                billingAddressRequest: Models.BillingAddressRequest? = nil) async throws -> Models.AccountVerificationResponse
```

Additional information can be found here:
[Commerce Hub Account Verification](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments_VAS/Verification.md&branch=main)


**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**

### 😀 Tokenization API

```Swift
public func tokenizeCard(transactionDetailsRequest: Models.TransactionDetailsRequest) async throws -> Models.TokenizeCardResponse
```

**NOTE:** the createToken field in the TransactionDetailsRequest does not need to be explicitly set to true.

Additional information can be found here:
[Commerce Hub Tokenization](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/Guides/Payment-Sources/Tokenization/TransAmor.md&branch=main)

**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**
### 😀 Charges API

**This API supports Authorizations, Payment Tokens, Capture, and Sale**

```Swift
public enum PaymentTransactionType {
    case sale
    case auth
    case capture
    case paymentToken
}
```

```Swift
public func charges(amount: Decimal,
                    transactionType: PaymentTransactionType,
                    transactionDetailsRequest: Models.TransactionDetailsRequest,
                    referenceTransactionDetailsRequest: Models.ReferenceTransactionDetailsRequest? = nil,
                    paymentTokenSourceRequest: Models.PaymentTokenSourceRequest? = nil) async throws -> Models.CommerceHubResponse
```

| TRANSACTION TYPE             |    SALE    |    AUTH    |  CAPTURE  |   TOKEN   |
|------------------------------|------------|------------|-----------|-----------|
| READ CARD                    |      Y     |      Y     |     N     |     N     |
| CAPTURE FLAG                 |      T     |      F     |     T     |     T     |
| TRANSACTION DETAILS          |      Y     |      Y     |     Y     |     Y     |
| REF TRANS DETAILS            |      N     |      N     |     O     |     N     |

**OPTIONAL -> Reference Transaction Details + Capture must be from a previous Authorization**

**TransactionDetailsRequest.createToken can be true for any PaymentTransactionType -requires Merchant configuration**

Additional Information can be found here:
[Commerce Hub Charges](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Charges.md&branch=main)

**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**

### 😀 Cancels API

```Swift
public func cancels(amount: Decimal,
                    referenceTransactionDetailsRequest: Models.ReferenceTransactionDetailsRequest) async throws -> Models.CommerceHubResponse
```

**NOTE:** At least one of the values for the referenceTransactionDetailsRequest must be provided.

Additional information can be found here:
[Commerce Hub Cancel](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Cancel.md&branch=main)

**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**
### 😀 Refunds API

**This API supports Matched, Unmatched, and Open Refunds**

```Swift
public enum RefundTransactionType {
    case matched
    case unmatched
    case open
}
```

```Swift
public func refunds(amount: Decimal,
                    refundTransactionType: RefundTransactionType,
                    transactionDetails: Models.TransactionDetailsRequest? = nil,
                    referenceTransactionDetails: Models.ReferenceTransactionDetailsRequest? = nil) async throws -> Models.CommerceHubResponse
```

| TRANSACTION TYPE             |    MATCHED    |   UNMATCHED   |    OPEN    |
|------------------------------|---------------|---------------|------------|
| READ CARD                    |      N        |      Y        |     Y      |
| CAPTURE FLAG                 |      F        |      T        |     T      |
| TRANSACTION DETAILS          |      N        |      Y        |     Y      |
| REF TRANS DETAILS            |      Y        |      Y        |     N      |

Additional information can be found here:
[Commerce Hub Matched Refund](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Refund-Tagged.md&branch=main)

Additional information can be found here:
[Commerce Hub Unmatched Refund](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Refund-Unmatched.md&branch=main)

Additional information can be found here:
[Commerce Hub Open Refund](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Refund-Open.md&branch=main)

**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**
### 😀 Transaction Inquiry API

To retrieve the current state of any previous transaction, an inquiry request can be submitted against the Commerce Hub transaction identifier or merchant transaction identifier.

**NOTE:** At least one of the values for the referenceTransactionDetailsRequest must be provided.

```Swift
public func transactionInquiry(referenceTransactionDetailsRequest: Models.ReferenceTransactionDetailsRequest) async throws -> [Models.InquireResponse]
```

Additional information can be found here:
[Commerce Hub Inquiry](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Inquiry.md&branch=main)

**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**

## Download the sample app
We've prepared an end-to-end sample app to get you up and running fast. [Get the Sample App here](https://github.com/Fiserv/TTPSampleApp)

## Additional Resources
[Commerce Hub](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/Master-Data/Reference-Transaction-Details.md)

[Sample App](https://github.com/Fiserv/TTPSampleApp)  

[Merchant FAQ's from Apple](https://register.apple.com/tap-to-pay-on-iphone/faq) 
[Tap to Pay on iPhone Security from Apple](https://support.apple.com/guide/security/tap-to-pay-on-iphone-sec72cb155f4/web)

**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**

### ⛔️ DEPRECATED - Take a Payment (Charges)
Congrats on getting this far!  Now you are ready to process your first payment.  Simply make this call and the SDK takes care of the rest for you:

```Swift
let amount = 10.99  // amount to charge
let merchantOrderId = "your order ID, for tracking purposes"
let merchantTransactionId = "your transaction ID, for tracking purposes"

do {
    let chargeResponse = try await fiservTTPCardReader.readCard(amount: amount, 
                                                                merchantOrderId: merchantOrderId, 
                                                                merchantTransactionId: merchantTransactionId)
    // TODO inspect the chargeResponse to see the authorization result
} catch let error as FiservTTPCardReaderError {
    // TODO handle exception
}
```

**NOTE:** If the card used for the charges endpoint is PIN DEBIT, the user will see a pin entry screen after tapping the card.

Additional information can be found here:
[Commerce Hub Charges](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Charges.md&branch=main)

### ⛔️ DEPRECATED - Inquiry

To retrieve the current state of any previous transaction, an inquiry request can be submitted against the Commerce Hub transaction identifier or merchant transaction identifier.

**NOTE:** At least one of the arguments must be provided.

```Swift
do {
    let inquireResponse = try await fiservTTPCardReader.inquiryTransaction(referenceTransactionId: referenceTransactionId,
                                                                           referenceMerchantTransactionId: referenceMerchantTransactionId,
                                                                           referenceMerchantOrderId: referenceMerchantOrderId,
                                                                           referenceOrderId: referenceOrderId)
    // TODO inspect the Inquire Response to see the result
} catch let error as FiservTTPCardReaderError {
    // TODO handle exception
}
```
Additional information can be found here:
[Commerce Hub Inquiry](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Inquiry.md&branch=main)

### ⛔️ DEPRECATED - Refund Payment without Tap

At least one reference transaction identifier must be provided to perform a Tagged Refund.

```Swift
let amount = 10.99 // amount to void
let referenceTransactionId = "this value was returned in the charge response"
do {
  let refundResponse = try await fiservTTPCardReader.refundTransaction(amount: amount,
                                                                       referenceTransactionId = referenceTransactionId)
    // TODO inspect the refundResponse to see the result   
} catch let error as FiservTTPCardReaderError {
    // TODO handle exception
}
```

**NOTE:** If using PIN DEBIT, refer to the Unmatched-Tagged Refund below.

Additional information can be found here:
[Commerce Hub Matched Refund](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Refund-Tagged.md&branch=main)

### ⛔️ DEPRECATED - Refund Payment with Tap (Unmatched Tagged Refund and Open Refund)

**NOTE:** The fiservTTPCardReader.refundCard API supports both 'Unmatched Tagged Refunds' and 'Open Refunds'.

**Open Refund**

An open refund (credit) is a refund to a card without a reference to the prior transaction.

To perform an Open Refund, do not provide any reference transaction identifiers, but your merchantOrderId or merchantTransactionId can be passed as an argument.


```Swift
let amount = 10.99 // amount to void
let referenceTransactionId = "this value was returned in the charge response"
do {
    let refundResponse = try await fiservTTPCardReader.refundCard(amount: amount),
                                                                  merchantTransactionId: transactionId)
    // TODO inspect the refundResponse to see the result
} catch let error as FiservTTPCardReaderError {
    // TODO handle exception
}                                                                 
```

Additional information can be found here:
[Commerce Hub Open Refund](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Refund-Open.md&branch=main)

**Unmatched Tagged Refund**

To perform an Unmatched Tagged Refund, the referenceTransactionId or the referenceMerchantTrancation must be provided. It is also acceptable to provide all values as well.

An unmatched tagged refund allows a merchant to issue a refund to a payment source other than the one used in the original transaction. The refund is associated with the original charge request by using the Commerce Hub transaction identifier or merchant transaction identifier. This allows the merchant to maintain the linking of the transaction information in Commerce Hub when issuing a refund or store credit.

**Unmatched Tagged Refund example:**
```Swift
let amount = 10.99 // amount to void
let referenceTransactionId = "this value was returned in the charge response"
do {
    let refundResponse = try await fiservTTPCardReader.refundCard(amount: amount),
                                                                  referenceTransactionId: referenceTransactionId,
                                                                  referenceMerchantTransactionId: referenceMerchantTransactionId)
    // TODO inspect the refundResponse to see the result
} catch let error as FiservTTPCardReaderError {
    // TODO handle exception
}                                                                 
```
**NOTE:** If the card used for the refund card endpoint is PIN DEBIT, the user will see a pin entry screen after tapping the card.

Additional information can be found here:
[Commerce Hub Unmatched Refund](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Refund-Unmatched.md&branch=main)

**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**

### ⛔️ DEPRECATED - Cancel a Payment

```Swift
let amount = 10.99 // amount to void
let referenceTransactionId = "this value was returned in the charge response"
do {
  let voidResponse = try await fiservTTPCardReader.voidTransaction(amount: amount,
                                                                   referenceTransactionId = referenceTransactionId)
    // TODO inspect the voidResponse to see the result
} catch let error as FiservTTPCardReaderError {
    // TODO handle exception
}
```
Additional information can be found here:
[Commerce Hub Cancel](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Cancel.md&branch=main)

### Object Models

```Swift
//  FiservPaymentModels
//
//  Copyright (c) 2022 - 2024 Fiserv, Inc.
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
        public let addressRequest: AddressRequest?
        
        public init(firstName: String, lastName: String, addressRequest: AddressRequest? = nil) {
            
            self.firstName = firstName
            self.lastName = lastName
            self.addressRequest = addressRequest
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
        public let posHardwareAndSoftware : PosHardwareAndSoftwareRequest
        
        public init(dataEntrySource: String, 
                    posFeatures: PosFeaturesRequest,
                    posHardwareAndSoftware: PosHardwareAndSoftwareRequest) {
            
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
```

