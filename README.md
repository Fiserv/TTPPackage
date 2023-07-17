# Tap to Pay on iPhone SDK by Fiserv
​
## Purpose
This Package is an SDK that facilitates enabling Apple's Tap To Pay on iPhone functionality in your own app.  With just a bit of configuration and a few lines of code, your iPhone app will be able to securely accept contactless payments on a supported iPhone without any additional hardware (e.g. POS terminal, external card reader device, etc.)  
​
Currently this functionality is only available in the U.S.
​
By using this Package, you will *not* need to certify your app.   We have taken care of that for you.
​
​
## Pre-requisites
​
​
### Device Requirements 
Apple Tap to Pay on iPhone requires iPhone XS or later, running iOS 16 or later
​
### Tap to Pay Entitlement
You must request a special entitlement from Apple to enable Tap To Pay.  Log-into your Apple Developer Account and then [click here](https://developer.apple.com/contact/request/tap-to-pay-on-iphone) to request the entitlement.  In the text box titled 'PSP, enter 'Fiserv' as the value.
​
Follow the instructions here to [add the entitlement to your app's profile](https://developer.apple.com/documentation/proximityreader/setting-up-the-entitlement-for-tap-to-pay-on-iphone)
​
### Obtain Fiserv Credentials
You can obtain test credentials for your app on [Fiserv's Developer Studio](https://developer.fiserv.com) by following these directions:
​
1. Create an account by clicking the orange button in the upper right of the page
2. Log-into [Developer Studio](https://developer.fiserv.com) with your email address/password
3. Click the Workspaces option in the top toolbar
4. Tap the button 'Add New Workspace'
5. Create a workspace of type 'CommerceHub'.  Provide a name and description, then select 'CommerceHub' from the 'Product' drop-down list
6. Click the 'Create Button'
7. In the Workspace, click the 'Credentials' tab
8. Click the 'Create API key'. You will need to select a Merchant Id from the drop-down, provide a name for the API Key, click the 'Sandbox' radio button from the 'API Key Type' list, and select 'Payments' in the 'Features' checkboxes.  Click the 'Create' button.
9. Important!  Copy the full API Key and Secret and store them __securely__.  Or, you can click the 'Save to File' button to download them into a file.   You will need these credentials to access the Fiserv SDK and back-end API's.  Protect these credentials in your code and in your app.
​
​
​
​
## Getting Started
Create a new project or open your existing app in XCode.
​
Add the Fiserv Package to your app by following these instructions:
1. With your app open in Xcode, select File->Add Packages...
2. In the search bar in the upper-right, enter the Package Url: `https://github.com/Fiserv/TTPPackage`
3. Click the 'Add Package' button at the bottom of the screen
4. Click 'Add Package' one more time.  The Package will be downloaded and added to your project
​
### Configure the Card Reader 
​
Create an instance of `FiservTTPConfig` and load it with your configuration as follows:
​
```Swift
let myConfig = FiservTTPConfig(
    secretKey: "<your secret key from Developer Studio>",
    apiKey: "<your API key from Developer Studio>",
    environment: .Sandbox,
    currencyCode: "USD",
    merchantId: "<your merchantId from the CommerceHub workspace on Developer Studio>",
    merchantName: "<your merchant name as it will be displayed in the Tap to Pay payment sheet>",
    merchantCategoryCode: "<your MCC>",
    terminalId: "10000001",
    terminalProfileId: "3c00e000-a00e-2043-6d63-936859000002")
```
​
Now create an instance of `FiservTTPCardReader`, which is the main class that your app will interact with.  Typically you would put this in a view model.
​
```Swift
private let fiservTTPCardReader: FiservTTPCardReader = FiservTTPCardReader(configuration: myConfig)
```
​
Early in the startup process of your app, call the following method to validate that the device running your app is supported for Apple Tap To Pay on iPhone:
​
```Swift
if !fiservTTPCardReader.readerIsSupported() {
    ///TODO handle unsupported device
}
```
​
### Obtain PSP Token
You must obtain a session token in order to utilize the SDK.  Acquire the token by making this call:
​
```Swift
do {
    try await fiservTTPCardReader.requestSessionToken()
} catch let error as FiservTTPCardReaderError {
    ///TODO handle exception
}
```
​
Note that the session token will expire in 24 hours.  You are responsible for keeping track of when to obtain a new token.
​
### Link Account
Next you must link the device running the app to an Apple ID. This needs to happen **just once**.  You are responsible for tracking whether the linking process has occurred already or not.  If not, then perform linking by making this call:
​
```Swift
do {
    try await fiservTTPCardReader.linkAcount()
} catch let error as FiservTTPCardReaderError {
    ///TODO handle exception
}
```
​
### Initialize the Card Reader Session
Now you're ready to initialize the Apple Proximity Reader by calling:
​
```Swift
do {
    try await fiservTTPCardReader.activateReader()
} catch let error as FiservTTPCardReaderError {
    ///TODO handle exception
}
```
​
**NOTE** that you must re-initialize the reader session each time the app starts and/or returns to the foreground!
​
### Take a Payment
Congrats on getting this far!  Now you are ready to process your first payment.  Simply make this call and the SDK takes care of the rest for you:
​
```Swift
let amount = 10.99  // amount to charge
let merchantOrderId = "your order ID, for tracking purposes"
let merchantTransactionId = "your transaction ID, for tracking purposes"
​
do {
    let chargeResponse = try await readCard(
        amount: amount, 
        merchantOrderId: merchantOrderId, 
        merchantTransactionId: merchantTransactionId)
    ///TODO inspect the chargeResponse to see the authorization result
} catch let error as FiservTTPCardReaderError {
    ///TODO handle exception
}
```
### Void a Payment

```Swift
let amount = 10.99 // amount to void
let referenceTransactionId = "this value was returned in the charge response"
do {
  let voidResponse = try await voidTransaction(
      amount:amount,
      referenceTransactionId = referenceTransactionId)
    ///TODO inspect the voidResponse to see the result   
} catch let error as FiservTTPCardReaderError {
    ///TODO handle exception
}
```
### Refund a Payment

```Swift
let amount = 10.99 // amount to void
let referenceTransactionId = "this value was returned in the charge response"
do {
  let refundResponse = try await refundTransaction(
      amount:amount,
      referenceTransactionId = referenceTransactionId)
    ///TODO inspect the refundResponse to see the result   
} catch let error as FiservTTPCardReaderError {
    ///TODO handle exception
}
```

## Download the sample app
We've prepared an end-to-end sample app to get you up and running fast. [Get the Sample App here](https://github.com/Fiserv/TTPSampleApp)
​
## Additional Resources

[Commerce Hub](https://developer.fiserv.com/product/CommerceHub/docs/?path=docs/Resources/Master-Data/Reference-Transaction-Details.md)
​
[Sample App](https://github.com/Fiserv/TTPSampleApp)  

​[Merchant FAQ's from Apple](https://register.apple.com/tap-to-pay-on-iphone/faq)​  
​
​[Tap to Pay on iPhone Security from Apple](https://support.apple.com/guide/security/tap-to-pay-on-iphone-sec72cb155f4/web)
