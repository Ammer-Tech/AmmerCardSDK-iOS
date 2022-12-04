import Foundation
import CoreNFC

@objc public protocol CardNFCServiceDelegate {
    @objc optional func cardService(_ cardService: CardNFCService, error: Error)
    @objc optional func cardService(_ cardService: CardNFCService, state: MetaState, guid: String, issuer: String, aid: AIDVersion)
    @objc optional func cardService(_ cardService: CardNFCService, signed data: [String])
    @objc optional func cardService(_ cardService: CardNFCService, progress: Float)
    @objc optional func cardService(_ cardService: CardNFCService, privateKey: String)    
    @objc optional func cardService(_ cardService: CardNFCService, pubKey: String, guid: String, issuer: String, state: MetaState, aid: AIDVersion)
    @objc optional func cardService(_ cardService: CardNFCService, amount: String, address: String, assetId: String, transactionId: String)
}