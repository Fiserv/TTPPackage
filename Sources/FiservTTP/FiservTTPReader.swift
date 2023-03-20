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
import ProximityReader

internal class FiservTTPReader {
    
    private var paymentCardReader: PaymentCardReader?
    
    private var cardReaderSession: PaymentCardReaderSession?
    
    private let config: FiservTTPConfig
    
    internal init(config: FiservTTPConfig) {
        
        self.config = config
        
        self.paymentCardReader = PaymentCardReader()
    }
    
    internal func finalize() {
        paymentCardReader = nil
        cardReaderSession = nil
    }
    
    internal func readerIdentifier() -> String? {
                
        if let cardReader = self.paymentCardReader {
            return String(UInt(bitPattern: ObjectIdentifier(cardReader)))
        }
        return nil
    }
    
    internal func readerIsSupported() -> Bool {
        
        return PaymentCardReader.isSupported
    }
    
    // Only handle the condition where the account is already linked
    // All other errors will propagate to surrounding scope
    internal func linkAccount(token: String) async throws {
        
        let title = "Link Account"
        
        guard let cardReader = self.paymentCardReader else {
            
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: NSLocalizedString("Payment Card Reader not available.", comment: ""))
        }
        
        let token = PaymentCardReader.Token(rawValue: token)
        
        do {
            
            try await cardReader.linkAccount(using: token)
            
            // Only handle the condition where the account is already linked
            // All other erreors will propagate to surrounding scope
        } catch PaymentCardReaderError.accountAlreadyLinked {
            // This error will not be thrown
        } catch {
            
            if let err = error as? PaymentCardReaderError {
            
                throw FiservTTPCardReaderError(title: err.errorName,
                                               localizedDescription: NSLocalizedString(err.errorDescription, comment: ""))
                
            } else {
                throw FiservTTPCardReaderError(title: title,
                                               localizedDescription: error.localizedDescription)
            }
        }
    }
    
    // Before using a device to read payment cards, you need to configure it appropriately.
    // This configuration must be done on every device using for Tap to Pay on iPhone
    // for the first time. The initial configuration of a device can take up to two minutes.
    // Any subsequent configuration updates typically take just a few seconds.
    
    internal func initializeSession(token: String, eventHandler: @escaping (String) -> Void) async throws {
        
        let title = "Initialize Session"
        
        guard let cardReader = self.paymentCardReader else {
            
            throw FiservTTPCardReaderError(title: title,
                                           localizedDescription: NSLocalizedString("Payment Card Reader not available.", comment: ""))
        }
        
        let readerToken = PaymentCardReader.Token(rawValue: token)
        
        let events = cardReader.events
        
        do {
            
            Task {
                
                for await event in events {
                    
                    await MainActor.run {
                        eventHandler(event.name)
                    }
                }
            }
            
            cardReaderSession = try await self.paymentCardReader?.prepare(using: readerToken)
            
        } catch {
            
            if let err = error as? PaymentCardReaderError {
            
                throw FiservTTPCardReaderError(title: err.errorName,
                                               localizedDescription: NSLocalizedString(err.errorDescription, comment: ""))
                
            } else {
                
                throw FiservTTPCardReaderError(title: title,
                                               localizedDescription: error.localizedDescription)
            }
        }
    }
    
    internal func validateCard(currencyCode: String) async throws -> FiservTTPValidateCardResponse {
        
        guard let session = cardReaderSession else {
         
            throw FiservTTPCardReaderError(title: "Invalid Session",
                                            localizedDescription: NSLocalizedString("The card reader session has not been initialized.", comment: ""))
        }
        
        do {
            
            let request = PaymentCardVerificationRequest(currencyCode: currencyCode, for: .other)
            
            // This method throws a ReadError if a person dismisses the sheet or the sheet fails to appear.
            let result = try await session.readPaymentCard(request)
            
            return FiservTTPValidateCardResponse(id: result.id,
                                                 generalCardData: result.generalCardData,
                                                 paymentCardData: result.paymentCardData)
        } catch {
            
            if let err = error as? PaymentCardReaderError {
            
                throw FiservTTPCardReaderError(title: err.errorName,
                                               localizedDescription: NSLocalizedString(err.errorDescription, comment: ""))
                
            } else if let err = error as? PaymentCardReaderSession.ReadError {
                
                throw FiservTTPCardReaderError(title: err.errorName,
                                               localizedDescription: NSLocalizedString(err.errorDescription, comment: ""))
                
            } else {
                
                throw FiservTTPCardReaderError(title: "Validate Card",
                                               localizedDescription: error.localizedDescription)
            }
        }
    }
    
    internal func readCard(for amount: Decimal,
                         currencyCode: String,
                         eventHandler: @escaping (String) -> Void) async throws -> Result<PaymentCardReadResult, Error> {
        
        guard let session = cardReaderSession else {
         
            return .failure(FiservTTPCardReaderError(title: "Invalid Session",
                                                     localizedDescription: NSLocalizedString("The card reader session has not been initialized.", comment: "")))
        }
        do {
            let request = PaymentCardTransactionRequest(amount: amount, currencyCode: currencyCode, for: .purchase)
            
            // This method throws a ReadError if a person dismisses the sheet or the sheet fails to appear.
            
            let result = try await session.readPaymentCard(request)
            
            if let _ = result.generalCardData, let _ = result.paymentCardData {
                
                return .success(result)
            }
            
            return .failure(FiservTTPCardReaderError(title: "Read Payment Card",
                                                     localizedDescription: "The card was unable to be successfully read."))
            
        } catch {
            
            if let err = error as? PaymentCardReaderError {
            
                throw FiservTTPCardReaderError(title: err.errorName,
                                               localizedDescription: NSLocalizedString(err.errorDescription, comment: ""))
                
            } else if let err = error as? PaymentCardReaderSession.ReadError {
                
                throw FiservTTPCardReaderError(title: err.errorName,
                                               localizedDescription: NSLocalizedString(err.errorDescription, comment: ""))
                
            } else {
                
                throw FiservTTPCardReaderError(title: "Read Card Payment",
                                               localizedDescription: error.localizedDescription)
            }
        }
    }
}
