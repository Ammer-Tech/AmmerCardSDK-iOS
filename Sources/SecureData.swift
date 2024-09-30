import Foundation
import OpenSSL
import CryptoKit
import CommonCrypto
import CryptoSwift

final class SecureData {
    
    static func generateSecp256k1KeyPair() -> (privateKey: String, publicKey: String)? {
        let ctx = BN_CTX_new()
        let privKey = BN_new()
        let group = EC_GROUP_new_by_curve_name(NID_secp256k1)
        
        if BN_rand(privKey, 256, -1, 0) == 0 {
            return nil
        }
        
        let pubKey = EC_POINT_new(group)
        EC_POINT_mul(group, pubKey, privKey, nil, nil, ctx)
        let privKeyHex = String(cString: BN_bn2hex(privKey))
        let pubKeyHex = String(cString: EC_POINT_point2hex(group, pubKey, POINT_CONVERSION_UNCOMPRESSED, ctx))

        BN_CTX_free(ctx)
        BN_free(privKey)
        EC_POINT_free(pubKey)
        EC_GROUP_free(group)
        
        return (privateKey: privKeyHex, publicKey: pubKeyHex)
    }
        
    static func generateECDHSecret(hostPrivateKeyBytes: [UInt8], ecdhCardPublicKeyBytes: [UInt8], ecdhNonceBytes: [UInt8]) -> Data? {
        let ecKey = EC_KEY_new_by_curve_name(NID_secp256k1)
        
        // Set the host's private key
        let hostPrivateKeyBN = BN_bin2bn(hostPrivateKeyBytes, Int32(hostPrivateKeyBytes.count), nil)
        EC_KEY_set_private_key(ecKey, hostPrivateKeyBN)
        
        // Create EC point for card public key
        let ecGroup = EC_KEY_get0_group(ecKey)
        let cardPublicKeyPoint = EC_POINT_new(ecGroup)
        EC_POINT_oct2point(ecGroup, cardPublicKeyPoint, ecdhCardPublicKeyBytes, Int(Int32(ecdhCardPublicKeyBytes.count)), nil)
        
        // Generate shared secret
        var sharedSecret = [UInt8](repeating: 0, count: 32) // 32 bytes for the shared secret
        let sharedSecretLength = ECDH_compute_key(&sharedSecret, sharedSecret.count, cardPublicKeyPoint, ecKey, nil)
        
        // Hash the shared secret
        var sha256 = SHA256_CTX()
        SHA256_Init(&sha256)
        SHA256_Update(&sha256, sharedSecret, Int(sharedSecretLength))
        SHA256_Update(&sha256, ecdhNonceBytes, ecdhNonceBytes.count)
        
        var finalSecret = [UInt8](repeating: 0, count: Int(SHA256_DIGEST_LENGTH))
        SHA256_Final(&finalSecret, &sha256)
        
        // Clean up
        EC_POINT_free(cardPublicKeyPoint)
        EC_KEY_free(ecKey)
        BN_free(hostPrivateKeyBN)
        
        return Data(finalSecret)
    }

    static func decryptResponseData(responseData: Data, secretKey: Data, sw1: UInt8, sw2: UInt8) -> Data? {

        guard secretKey.count == 32 else {
            print("Invalid key length. Must be 32 bytes for AES-256.")
            return nil
        }

        let iv = responseData.prefix(16)
        guard let aes = try? AES(key: secretKey.bytes, blockMode: CBC(iv: iv.bytes), padding: .iso78164) else {
            return nil
        }
        
        let encryptedData = Data(responseData.suffix(from: 16))
        
        guard let decryptedBytes = try? aes.decrypt(encryptedData.bytes) else {
            return nil
        }
        let decryptedData = Data(decryptedBytes)

        var finalData = Data()
        finalData.append(decryptedData)
        //finalData.append(contentsOf: [sw1, sw2])
        
        return finalData
    }

    static func encryptCommandData(cmdData: Data, secretKey: Data) -> Data? {
        
        // Generate a random IV (initialization vector) of 16 bytes (AES block size)
        let iv = AES.randomIV(AES.blockSize)
        guard let aes = try? AES(key: secretKey.bytes, blockMode: CBC(iv: iv), padding: .iso78164) else {
            return nil
        }

        /* Encrypt Data */
        guard let encryptedBytes = try? aes.encrypt(cmdData.bytes) else {
            return nil
        }
        let encryptedData = Data(encryptedBytes)

        var resultData = Data(iv)
        resultData.append(encryptedData)

        return resultData
    }

}
