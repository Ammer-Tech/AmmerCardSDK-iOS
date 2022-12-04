import Foundation

enum InstructionCode: UInt8 {
    case INS_GET_STATE = 0x01
    case INS_INIT = 0x02
    case INS_GET_CARD_GUID = 0x03
    case INS_GET_CARD_ISSUER = 0x04
    case INS_GET_CARD_SERIES = 0x05
    case INS_GET_PROCESSING_PUBLIC_KEY = 0x06
    case INS_SET_PROCESSING_PUBLIC_KEY = 0x07
    case INS_ACTIVATE = 0x08
    case INS_ACTIVATE_WITH_KEYS = 0x09
    case INS_DISABLE_PRIVATE_KEY_EXPORT = 0x10
    case INS_SIGN_DATA = 0x11
    case INS_SIGN_PROCESSING_DATA = 0x12
    case INS_LOCK = 0x0A
    case INS_UNLOCK = 0x0B
    case INS_CHANGE_PIN = 0x0C
    case INS_GET_PIN_RETRIES = 0x0D
    case INS_GET_PUBLIC_KEY = 0x0E
    case INS_EXPORT_PRIVATE_KEY = 0x0F
}
