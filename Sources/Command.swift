import Foundation

public enum Command: UInt8 {
    case setNewPin = 0x01
    case sign = 0x02
    case getPrivateKey = 0x03
    case pay = 0x04
    case undefined = 0x05
}
