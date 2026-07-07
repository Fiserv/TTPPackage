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
| Credit                       | iOS 18.x (absolute minimum version as of September 2025)                           |
| Debit                        | iOS 18.x (absolute minimum version as of September 2025)                           |


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
    let clientRequestId = UUID().uuidString
    try await fiservTTPCardReader.requestSessionToken(clientRequestId: clientRequestId)
} catch let error as FiservTTPCardReaderError {
    // TODO handle exception
}
```

Note that the session token has a time to live of 48 hours. However, we have included an **auto-refresh feature** that will request a new token for you when the TTL value is 30 minutes or less. Moving the app from the background to the foreground, as well as unlocking (a locked iPhone) will trigger this check and the refresh will occur based on the time remaining of the token. 

Additional information can be found here:
[Commerce Hub Security](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Security/Credentials.md&branch=main)

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
## Idempotency in API requests

Commerce Hub supports an idempotency operation that allows the same API call to be submitted 
repeatedly while producing the same result. For example, in the case of a timeout error, a 
merchant can retry the same API call multiple times; this guarantees that the transaction processes once.
Our APIs use the Client-Request-Id element to ensure idempotency on transaction requests.

The Client-Request-Id is a client-generated number that is unique for each request. It is used as 
a nonce and validated against all Client-Request-Ids received by Commerce Hub within a predetermined 
time frame (24 hours is the default) to prevent replay attacks. Commerce Hub uses the timestamp of the 
request to validate against stale requests. Any request older than the specified duration is rejected.

The following transaction types support and require a unique identifier. The recommended value is a 128-bit UUID.

##### Session Token, Account Verification, Tokenization, Charges, Refunds, Cancels, and Transaction Inquiry

Additional Information can be found here:
[Idempotency in API requests](https://developer.fiserv.com/product/CommerceHub/docs/Developer-Resources/API-Reference/Idempotency.mdx)

**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**

## Transaction Serialization

A new transaction may only begin once the previous transaction has returned a success or failure response, or thrown an error. A concurrent attempt throws a `FiservTTPCardReaderError`.

```Swift
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
```

The following transactions support Transaction Serialization:

##### Validate Card, Account Verification, Tokenize Card, Transaction Inquiry, Charges, Refunds, Cancels

**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**

## Timeout Reversals

In the rare but possible event that a response from the server is not received, there is a new facility to attempt to reverse (cancel) a primary transaction. If the expected response is not received within 30 seconds, the Apple Tap To Pay package will attempt a cancel. This will continue for a maximum of 3 times after the initial timeout, with the first wait period of 30 seconds and then 3 10 seconds wait periods. After each wait period, a cancel will be attempted. In the event a response is received at anytime during a wait cycle, the response will be returned as expected. If all of the attempts do not return a response, an error will be thrown and no further cancel attempts will be made.

Timeout Reversals are implemented for:

##### Charges and Refunds

**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**

#### Charges API

**This API supports Sale, Authorizations, Capture, Auth with PaymentToken**

| Request Parameters           |    SALE    |    AUTH    |  CAPTURE  |   PAYMENT TOKEN |
|------------------------------|------------|------------|-----------|-----------------|
| PaymentTransactionType       |    sale    |    auth    |  capture  |  paymentToken   |
| transactionDetails           |     Y      |     Y      |    Y      |     Y           |
| referenceTransactionDetails  |     N      |     N      |    Y      |     N           |

**OPTIONAL -> Reference Transaction Details + Capture must be from a previous Authorization**

**TransactionDetailsRequest.createToken can be true for any PaymentTransactionType -requires Merchant configuration**

Use the code snippet below to perform a sale transaction.

```Swift
let clientRequestId = UUID().uuidString  // 128 bit uinque Identifier
let amount = 12.04
let createPaymentToken = true
let merchantOrderId = "1234567890"       // Unique merchant order ID
let merchantTransactionId = "1234567890" // Unique merchant transaction ID
let merchantInvoiceNumber = "1234567890" // Optional
let transactionType = PaymentTransactionType.sale
let transactionDetails = Models.TransactionDetailsRequest(
    merchantTransactionId: merchantTransactionId,
    merchantOrderId: merchantOrderId,
    merchantInvoiceNumber: merchantInvoiceNumber,
    createToken: createPaymentToken
)

Task {
    do {
        let response = try await self.fiservTTPCardReader.charges(
            clientRequestId: clientRequestId,
            amount: bankersAmount(amount: amount),
            transactionType: transactionType,
            transactionDetailsRequest: transactionDetails
        )

        // Transaction response
        if response.gatewayResponse?.transactionState == "CAPTURED" {
            // Process the response here...
        }
    } catch {
        // Handle Error
    }
}
```

Use the code snippet below to perform an authorization (pre-authorization) transaction. A subsequent capture transaction is required to settle the authorization.

```Swift
let clientRequestId = UUID().uuidString  // 128 bit uinque Identifier
let amount = 12.04
let createPaymentToken = false
let merchantOrderId = "1234567890"       // Unique merchant order ID
let merchantTransactionId = "1234567890" // Unique merchant transaction ID
let merchantInvoiceNumber = "1234567890" // Optional
let transactionType = PaymentTransactionType.auth
let paymentTokenSource: Models.PaymentTokenSourceRequest // PaymentToken from the tokenize response
let transactionDetails = Models.TransactionDetailsRequest(
    merchantTransactionId: merchantTransactionId,
    merchantOrderId: merchantOrderId,
    merchantInvoiceNumber: merchantInvoiceNumber,
    createToken: createPaymentToken
)

Task {
    do {
        let response = try await self.fiservTTPCardReader.charges(
            clientRequestId: clientRequestId,
            amount: bankersAmount(amount: amount),
            transactionType: transactionType,
            transactionDetailsRequest: transactionDetails,
            paymentTokenSourceRequest: paymentTokenSource
        )

        // Transaction response
        if response.gatewayResponse?.transactionState == "AUTHORIZED" {
            // Process the response here...
        }
    } catch {
        // Handle Error
    }
}
```

Use the code snippet below to perform a capture transaction using a referenceTransactionId.
At least one reference transaction identifier must be provided to perform a capture.

```Swift
let clientRequestId = UUID().uuidString  // 128 bit uinque Identifier
let amount = 12.04
let createPaymentToken = false
let referenceTransactionDetails = Models.ReferenceTransactionDetailsRequest(referenceTransactionId: "DEF0987654321") // referenceTransactionId from previous Authorization
let transactionType = PaymentTransactionType.capture

Task {
    do {
        let transactionDetails = Models.TransactionDetailsRequest(
            merchantTransactionId: merchantTransactionId,
            merchantOrderId: merchantOrderId,
            merchantInvoiceNumber: merchantInvoiceNumber,
            createToken: createPaymentToken
        )

        let response = try await self.fiservTTPCardReader.charges(
            clientRequestId: clientRequest,
            amount: bankersAmount(amount: amount),
            transactionType: transactionType,
            transactionDetailsRequest: transactionDetails,
            referenceTransactionDetailsRequest: referenceTransactionDetails
        )

        // Transaction response
        if response.gatewayResponse?.transactionState == "CAPTURED" {
            // Process the response here...
        }
    } catch {
        // Handle Error
    }
}
```

Additional Information can be found here:
[Commerce Hub Charges](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Charges.md&branch=main)

**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**

#### Cancels API

Use the code snippet below to perform a cancel (void) transaction using a referenceTransactionId.
At least one reference transaction identifier must be provided to perform a cancel.

```Swift
let clientRequestId = UUID().uuidString  // 128 bit uinque Identifier
let amount = 12.04
let referenceTransactionDetails = Models.ReferenceTransactionDetailsRequest(referenceTransactionId: "DEF0987654321") // referenceTransactionId from previous transaction 

Task {
    do {
        let voidResponse = try await cancels(
            clientRequestId: clientRequestId,
            amount:amount,
            referenceTransactionDetails: referenceTransactionDetails
        )

        // Transaction response
        if response.gatewayResponse?.transactionState == "CANCELLED" {
            // Process the response here...
        }
    } catch {
            // Handle Error
        }
}
```

**NOTE:** At least one of the values for the referenceTransactionDetailsRequest must be provided.

Additional information can be found here:
[Commerce Hub Cancel](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Cancel.md&branch=main)

**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**

#### Refunds API

**This API supports Matched, Unmatched, and Open Refunds**

| Request Parameters           |    MATCHED    |   UNMATCHED   |    OPEN    |
|------------------------------|---------------|---------------|------------|
| RefundTransactionType        |   matched     |   unmatched   |    open    |
| transactionDetails           |      N        |      Y        |     Y      |
| referenceTransactionDetails  |      Y        |      Y        |     N      |


Use the code snippet below to perform a matched (tagged) refund transaction using a referenceTransactionId.
At least one reference transaction identifier must be provided to perform a tagged refund.

```Swift
let clientRequestId = UUID().uuidString  // 128 bit uinque Identifier
let amount = 12.04
let refundTransactionType = RefundTransactionType.matched
let referenceTransactionDetails = Models.ReferenceTransactionDetailsRequest(referenceTransactionId: "DEF0987654321") // referenceTransactionId from previous transaction

Task {
    do {
        let response = try await self.fiservTTPCardReader.refunds(
            clientRequestId: clientRequestId,
            amount: bankersAmount(amount: amount),
            refundTransactionType: refundTransactionType,
            referenceTransactionDetails: referenceTransactionDetails
        )

        // Transaction response
        if response.gatewayResponse?.transactionState == "CAPTURED" {
            // Process the response here...
        }
    } catch {
        // Handle Error
    }
}
```

Use the code snippet below to perform a unmatched refund transaction using a referenceTransactionId.
At least one reference transaction identifier must be provided to perform an unmatched tagged refund.

```Swift
let clientRequestId = UUID().uuidString  // 128 bit uinque Identifier
let amount = 12.04
let refundTransactionType = RefundTransactionType.unmatched
let referenceTransactionDetails = Models.ReferenceTransactionDetailsRequest(referenceTransactionId: "DEF0987654321") // referenceTransactionId from previous transaction
let transactionDetails = Models.TransactionDetailsRequest(
    merchantTransactionId: merchantTransactionId,
    merchantOrderId: merchantOrderId,
    merchantInvoiceNumber: merchantInvoiceNumber
)

Task {
    do {
        let response = try await self.fiservTTPCardReader.refunds(
            clientRequestId: clientRequestId,
            amount: bankersAmount(amount: amount),
            refundTransactionType: refundTransactionType,
            transactionDetails: transactionDetails,
            referenceTransactionDetails: referenceTransactionDetails
        )

        if response.gatewayResponse?.transactionState == "CAPTURED" {
            // Process the response here...
        }

    } catch {
        // Handle Error
    }
}
```
Use the code snippet below to perform a open refund (credit) transaction.

```Swift
let clientRequestId = UUID().uuidString  // 128 bit uinque Identifier
let amount = 12.04
let refundTransactionType = RefundTransactionType.open
let merchantOrderId = "1234567890" // Unique merchant order ID
let merchantTransactionId = "1234567890" // Unique merchant transaction ID
let merchantInvoiceNumber = "1234567890" // Optional
let transactionDetails = Models.TransactionDetailsRequest(
    merchantTransactionId: merchantTransactionId,
    merchantOrderId: merchantOrderId,
    merchantInvoiceNumber: merchantInvoiceNumber
)

Task {
    do {
        let response = try await self.fiservTTPCardReader.refunds(
            clientRequestId: clientRequestId,
            amount: bankersAmount(amount: amount),
            refundTransactionType: refundTransactionType,
            transactionDetails: transactionDetails
        )

        if response.gatewayResponse?.transactionState == "CAPTURED" {
            // Process the response here...
        }

    } catch {
        // Handle Error
    }
}
```

Additional information can be found here:
[Commerce Hub Matched Refund](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Refund-Tagged.md&branch=main)

Additional information can be found here:
[Commerce Hub Unmatched Refund](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Refund-Unmatched.md&branch=main)

Additional information can be found here:
[Commerce Hub Open Refund](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments/Refund-Open.md&branch=main)

**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**
#### Account Verification

Use the code snippet below to perform an account verification.

```Swift
let clientRequestId = UUID().uuidString  // 128 bit uinque Identifier
let usesAddress = true
let amount = 12.04
let createPaymentToken = true
let merchantOrderId = "1234567890"       // Unique merchant order ID
let merchantTransactionId = "1234567890" // Unique merchant transaction ID
let merchantInvoiceNumber = "1234567890" // Optional
let transactionDetails = Models.TransactionDetailsRequest(
    merchantTransactionId: merchantTransactionId,
    merchantOrderId: merchantOrderId,
    merchantInvoiceNumber: merchantInvoiceNumber,
    createToken: createPaymentToken
)
var addressRequest: Models.AddressRequest?
var billingAddressRequest: Models.BillingAddressRequest?

if usesAddress {
    addressRequest = Models.AddressRequest(
        street: streetName,
        houseNumberOrName: houseNumber,
        city: city,
        stateOrProvince: state,
        postalCode: postalCode,
        country: country
    )

    billingAddressRequest = Models.BillingAddressRequest(
        firstName: firstName,
        lastName: lastName,
        addressRequest: addressRequest
    )
}

Task {
    do {
        let response = try await self.fiservTTPCardReader.accountVerification(
            clientRequestId: clientRequestId,
            transactionDetailsRequest: transactionDetails,
            billingAddressRequest: billingAddressRequest
        )

        if response.gatewayResponse?.transactionState == "VERIFIED" {
            // Process the response here...
        }
    } catch {
        // Handle Error
    }
}
```

Additional information can be found here:
[Commerce Hub Account Verification](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/API-Documents/Payments_VAS/Verification.md&branch=main)

**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**

#### Tokenization

Use the code snippet below to tokenize a card.

```Swift
let clientRequestId = UUID().uuidString  // 128 bit uinque Identifier
let merchantOrderId = "1234567890"       // Unique merchant order ID
let merchantTransactionId = "1234567890" // Unique merchant transaction ID
let merchantInvoiceNumber = "1234567890" // Optional

Task {
    do {
        let transactionDetailsRequest = Models.TransactionDetailsRequest(
            merchantTransactionId: merchantTransactionId,
            merchantOrderId: merchantOrderId,
            merchantInvoiceNumber: merchantInvoiceNumber
        )

        let response = try await self.fiservTTPCardReader.tokenizeCard(
            clientRequestId: clientRequestId,
            transactionDetailsRequest: transactionDetailsRequest
        )

        if response.gatewayResponse?.transactionState == "AUTHORIZED" {
            // Process the response here...
        }
    } catch {
        // Handle Error
    }
}
```

**NOTE:** the createToken field in the TransactionDetailsRequest does not need to be explicitly set to true.

Additional information can be found here:
[Commerce Hub Tokenization](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/Guides/Payment-Sources/Tokenization/TransAmor.md&branch=main)

**- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -**
#### Transaction Inquiry API

To retrieve the current state of any previous transaction, an inquiry request can be submitted against the Commerce Hub transaction identifier or merchant transaction identifier.

**NOTE:** At least one of the values for the referenceTransactionDetailsRequest must be provided.

Use the code snippet below to perform a transaction inquiry using a referenceTransactionId.
At least one reference transaction identifier must be provided to perform an inquiry.

```Swift
let clientRequestId = UUID().uuidString  // 128 bit uinque Identifier
let referenceTransactionDetails = Models.ReferenceTransactionDetailsRequest(referenceTransactionId: "DEF0987654321") // referenceTransactionId from previous transaction

Task {
    do {
        let response = try await self.fiservTTPCardReader.transactionInquiry(
            clientRequestId: clientRequestId,
            referenceTransactionDetailsRequest: referenceTransactionDetails
        )
        // Process the response here...
    } catch {
        // Handle Error
    }
}
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
