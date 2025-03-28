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
let amount = 12.04
let createPaymentToken = true
let merchantOrderId = "1234567890" // Unique merchant order ID
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
let amount = 12.04
let createPaymentToken = false
let merchantOrderId = "1234567890" // Unique merchant order ID
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
let amount = 12.04
let referenceTransactionId = "1234567890" // referenceTransactionId from previous transaction

Task {
    do {
        let voidResponse = try await voidTransaction(
            amount:amount,
            referenceTransactionId: = referenceTransactionId
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
let amount = 12.04
let refundTransactionType = RefundTransactionType.matched
let referenceTransactionDetails = Models.ReferenceTransactionDetailsRequest(referenceTransactionId: "DEF0987654321") // referenceTransactionId from previous transaction

Task {
    do {
        let response = try await self.fiservTTPCardReader.refunds(
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
let usesAddress = true
let amount = 12.04
let createPaymentToken = true
let merchantOrderId = "1234567890" // Unique merchant order ID
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
let merchantOrderId = "1234567890" // Unique merchant order ID
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
let referenceTransactionDetails = Models.ReferenceTransactionDetailsRequest(referenceTransactionId: "DEF0987654321") // referenceTransactionId from previous transaction

Task {
    do {
        let response = try await self.fiservTTPCardReader.transactionInquiry(
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


