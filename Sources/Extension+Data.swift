
import Foundation
import CommonCrypto

extension Data {
  
  struct HexEncodingOptions: OptionSet {
      let rawValue: Int
      static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
  }
  
  func hexEncodedString(options: HexEncodingOptions = []) -> String {
      let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
      return self.map { String(format: format, $0) }.joined()
  }
  
  public func sha256V2() -> String {
      return hexStringFromData(input: digest(input: self as NSData))
  }
  
  private func digest(input : NSData) -> NSData {
      let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
      var hash = [UInt8](repeating: 0, count: digestLength)
      CC_SHA256(input.bytes, UInt32(input.length), &hash)
      return NSData(bytes: hash, length: digestLength)
  }
  
  private func hexStringFromData(input: NSData) -> String {
      var bytes = [UInt8](repeating: 0, count: input.length)
      input.getBytes(&bytes, length: input.length)
      
      var hexString = ""
      for byte in bytes {
          hexString += String(format:"%02x", UInt8(byte))
      }
      
      return hexString
  }
  
  func copyBytes() -> [UInt8] {
      let size = MemoryLayout<UInt8>.stride
      return withUnsafeBytes{ (bytes: UnsafePointer<UInt8>) in
          Array(UnsafeBufferPointer(start: bytes, count: count / size))
      }
  }
  
  func hexadecimal() -> String {
      return map { String(format: "%02x", $0) }.joined(separator: "")
  }
  
  func to<T>(type: T.Type) -> T? where T: ExpressibleByIntegerLiteral {
      var value: T = 0
      guard count >= MemoryLayout.size(ofValue: value) else { return nil }
      _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0)} )
      return value
  }

}
