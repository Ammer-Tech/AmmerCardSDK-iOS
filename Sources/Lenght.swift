import Foundation

struct Lenght {
    static let STATE_MIN_LENGTH: UInt8 = 1
    static let STATE_MAX_LENGTH: UInt8 = 1
    static let CARD_GUID_MIN_LENGTH: UInt8 = 16
    static let CARD_GUID_MAX_LENGTH: UInt8 = 16
    static let CARD_ISSUER_MIN_LENGTH: UInt8 = 1
    static let CARD_ISSUER_MAX_LENGTH: UInt8 = 1
    static let CARD_SERIES_MIN_LENGTH: UInt8 = 1
    static let CARD_SERIES_MAX_LENGTH: UInt8 = 1
    static let PROCESSING_PUBLIC_KEY_MIN_LENGTH: UInt8 = 65
    static let PROCESSING_PUBLIC_KEY_MAX_LENGTH: UInt8 = 65
    static let CARD_PIN_MIN_LENGTH: UInt8 = 5
    static let CARD_PIN_MAX_LENGTH: UInt8 = 6
    static let CARD_PIN_RETRIES_MIN_LENGTH: UInt8 = 1
    static let CARD_PIN_RETRIES_MAX_LENGTH: UInt8 = 1
    static let CARD_PUBLIC_KEY_MIN_LENGTH: UInt8 = 65
    static let CARD_PUBLIC_KEY_MAX_LENGTH: UInt8 = 65
    static let CARD_PRIVATE_KEY_MIN_LENGTH: UInt8 = 32
    static let CARD_PRIVATE_KEY_MAX_LENGTH: UInt8 = 32
    static let DATA_FOR_SIGN_MIN_LENGTH: UInt8 = 32
    static let DATA_FOR_SIGN_MAX_LENGTH: UInt8 = 32
    static let DATA_SIGNATURE_MIN_LENGTH: UInt8 = 70
    static let DATA_SIGNATURE_MAX_LENGTH: UInt8 = 72
    
}
