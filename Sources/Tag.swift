import Foundation

struct Tag {
    static let STATE: UInt8 = 0x01
    static let CARD_GUID: UInt8 = 0x02
    static let CARD_ISSUER: UInt8 = 0x03
    static let CARD_SERIES: UInt8 = 0x04
    static let PROCESSING_PUBLIC_KEY: UInt8 = 0x05
    static let CARD_PIN: UInt8 = 0x06
    static let CARD_PIN_RETRIES: UInt8 = 0x07
    static let CARD_PUBLIC_KEY: UInt8 = 0x08
    static let CARD_PRIVATE_KEY: UInt8 = 0x09
    static let DATA_FOR_SIGN: UInt8 = 0x0A
    static let DATA_SIGNATURE: UInt8 = 0x0B
    
    static let ED_CARD_PUBLIC_KEY: UInt8 = 0x0C
    static let ED_CARD_PUBLIC_KEY_ENCODED: UInt8 = 0x0D
    static let ED_PRIVATE_NONCE: UInt8 = 0x0E
    static let ED_PUBLIC_NONCE: UInt8 = 0x0F
    static let ED_DATA_SIGNATURE: UInt8 = 0x10
    
    static let PUBKEY_DATA_SIGNATURE: UInt8 = 0x0C
    static let PRIVATE_NONCE_DATA_SIGNATURE: UInt8 = 0x0D
    static let PUBLIC_NONCE_DATA_SIGNATURE: UInt8 = 0x0E
}
