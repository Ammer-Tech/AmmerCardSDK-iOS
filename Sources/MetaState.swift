import Foundation

@objc public enum MetaState: UInt8 {
    case NOT_INITED = 0x02 //The card was not inited
    case INITED = 0x04 //The card was inited
    case ACTIVATED_LOCKED = 0x08 //The card was inited and now locked for any operations with public/private key
    case ACTIVATED_UNLOCKED = 0x0F //The card was inited and right now unlocked for any operations with public/private key
    case UNDEFINED = 0x00 //Sate no undefined
}
