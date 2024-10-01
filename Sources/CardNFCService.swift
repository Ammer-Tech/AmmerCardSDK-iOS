import Foundation
import CoreNFC
import UIKit

public final class CardNFCService: NSObject {
    
    private var fullResponse: [UInt8]
    private var pincode: String?
    private var newPincode: String?
    private var dataForSign: [(String, String)]?
    private var stateCard: MetaState = .UNDEFINED
    
    private var command: Command = .undefined
    private var cardGUID: String = ""
    private var publicKey: String = ""
    private var attempts: Int = 0
    private var allAttempts: Int = 0
    
    private var ed_publicKey: String = ""
    private var ed_privateNonce: String = ""
    private var ed_publicNonce: String = ""
    private var ed_payload: String = ""
    private var ed_payloadForSignature: String = ""
    
    private var privateKey: String = ""
    private var issuer: String = ""
    private var aid: AIDVersion = .undefined
    private var finalSecret: Data?
    
    private var delegate: CardNFCServiceDelegate?
    
    private var session: NFCTagReaderSession?
    private var iso7816Tag: NFCISO7816Tag?
    private var tag: NFCTag?
    private var needPIN: Bool = true
    private var gatewaySignature: String = ""
    private let internalQueue = DispatchQueue(label: "smart.card.cardNFCService")
    
    //MARK: -
    public override init() {
        self.fullResponse = [UInt8]()
    }
    
    public convenience init(delegate: CardNFCServiceDelegate) {
        self.init()
        self.delegate = delegate
    }
    
    public convenience init(delegate: CardNFCServiceDelegate, command: Command) {
        self.init()
        self.command = command
        self.delegate = delegate
    }
    
    public convenience init(delegate: CardNFCServiceDelegate, command: Command, pincode: String, newPincode: String) {
        self.init()
        self.command = command
        self.newPincode = newPincode
        self.pincode = pincode
        self.delegate = delegate
    }
    
    public convenience init(delegate: CardNFCServiceDelegate, command: Command, pincode: String) {
        self.init()
        self.command = command
        self.pincode = pincode
        self.delegate = delegate
    }
    
    public convenience init(delegate: CardNFCServiceDelegate, command: Command, pincode: String, dataForSign: [(String, String)]) {
        self.init()
        self.command = command
        self.pincode = pincode
        self.dataForSign = dataForSign
        self.delegate = delegate
    }
    
    //MARK: - Commands Private
    private func getInvoiceCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_GET_STATE.rawValue, p1Parameter: 0, p2Parameter: 0, data: Data(), expectedResponseLength: -1)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            
            if let error = error {
                session.invalidate(errorMessage: "Some error occurred. Error \(code). \(error.localizedDescription). Please try again. ")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false, code)
                return
            }
            
            if let res = self.dataToJson(data) {
                let amount = res["amount"] as? String ?? "0"
                let assetId = res["assetID"] as? String ?? ""
                let address = res["address"] as? String ?? ""
                let transactionId = res["transactionID"] as? String ?? ""
                self.delegate?.cardService?(self, amount: amount, address: address, assetId: assetId, transactionId: transactionId)
                //session.invalidate()
            } else {
                session.invalidate(errorMessage: "Incorrect format. Error \(code). Please try again.")
            }
        }
        
    }
    
    private func getStateCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_GET_STATE.rawValue, p1Parameter: 0, p2Parameter: 0, data: Data(), expectedResponseLength: -1)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            
            if let error = error {
                session.invalidate(errorMessage: "\(error.localizedDescription). This card isn't a Ammer Wallet or it is blocked.")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false, code)
                return
            }
            
            let result = self.handlerTLVFormat(data: data)
            if let value = result.v.first {
                self.stateCard = MetaState(rawValue: value) ?? .UNDEFINED
                completionHandler(true, code)
            } else {
                completionHandler(false, code)
            }
            
        }
        
    }
    
    private func getIssuerCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_GET_CARD_ISSUER.rawValue, p1Parameter: 0, p2Parameter: 0, data: Data(), expectedResponseLength: 64)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            
            if let error = error {
                session.invalidate(errorMessage: "Some error occurred. Error \(code). \(error.localizedDescription). Please try again.")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false, code)
                return
            }
            
            let result = self.handlerTLVFormat(data: data)
            if result.v.count > 1 {
                let data = Data(result.v)
                let decimalValue = data.reduce(0) { v, byte in
                    return v << 8 | Int(byte)
                }
                self.issuer = String(decimalValue)
            }

            completionHandler(code == "9000", code)
        }
    }
    
    private func getPublicKeyCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_GET_PUBLIC_KEY.rawValue, p1Parameter: 0, p2Parameter: 0, data: Data(), expectedResponseLength: 64)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            
            if let error = error {
                session.invalidate(errorMessage: "Some error occurred. Error \(code). \(error.localizedDescription). Please try again.")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false, code)
                return
            }
            
            let result = self.handlerTLVFormat(data: data)
            let pubkey = Data(bytes: result.v, count: result.v.count).hexadecimal()
            self.publicKey = pubkey
            completionHandler(code == "9000", code)
        }
    }
    
    private func getPINAttemptsCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_GET_PIN_RETRIES.rawValue, p1Parameter: 0, p2Parameter: 0, data: Data(), expectedResponseLength: 64)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            
            if let error = error {
                session.invalidate(errorMessage: "Some error occurred. Error \(code). \(error.localizedDescription). Please try again.")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false, code)
                return
            }
            
            let result = self.handlerTLVFormat(data: data)
            if let first = result.v.first {
                self.attempts = Int(first)
            }
            completionHandler(code == "9000", code)
        }
    }
    
    private func handshakeCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        guard self.aid == .v6 else {
            completionHandler(true, "9000")
            return
        }
        
        let keyPair = SecureData.generateSecp256k1KeyPair()
        guard let keyPair = keyPair else {
            completionHandler(false, "Failed to generate key pair")
            return
        }
        
        guard let dataCommand = self.dataCommand(value: keyPair.publicKey) else {
            completionHandler(false, "Failed to prepare pub key")
            return
        }

        guard let privateKeyBytes = keyPair.privateKey.hexadecimal else {
            completionHandler(false, "Failed to prepare private key")
            return
        }
        
        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_ECDH_HANDSHAKE.rawValue, p1Parameter: 0, p2Parameter: 0, data: dataCommand, expectedResponseLength: -1)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            
            if let error = error {
                session.invalidate(errorMessage: "\(error.localizedDescription). Handshake error.")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false, code)
                return
            }
            
            let ecdhCardPublicKeyRange = Int(TLV.OFFSET_VALUE)..<Int((TLV.HEADER_BYTES_COUNT + Lenght.CARD_PUBLIC_KEY_MAX_LENGTH))
            let ecdhCardPublicKeyBytes = data.subdata(in: ecdhCardPublicKeyRange)

            let ecdhNonceStartIndex = Int(TLV.OFFSET_VALUE + TLV.HEADER_BYTES_COUNT + Lenght.CARD_PUBLIC_KEY_MAX_LENGTH)
            let ecdhNonceBytes = data.subdata(in: ecdhNonceStartIndex..<data.count)
            
            print("ecdhCardPublicKey: \(ecdhCardPublicKeyBytes.hexEncodedString())")
            print("ecdhNonceBytes: \(ecdhNonceBytes.hexEncodedString())")
                        
            if let finalSecret = SecureData.generateECDHSecret(hostPrivateKeyBytes: privateKeyBytes.copyBytes(), ecdhCardPublicKeyBytes: ecdhCardPublicKeyBytes.copyBytes(), ecdhNonceBytes: ecdhNonceBytes.copyBytes()) {
                self.finalSecret = finalSecret
            }
                
            completionHandler(self.finalSecret != nil, "")
        }
        
    }
    
    private func getEDPublicKeyCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_ED_GET_PUBLIC_KEY.rawValue, p1Parameter: 0, p2Parameter: 0, data: Data(), expectedResponseLength: 64)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            
            if let error = error {
                session.invalidate(errorMessage: "Some error occurred. Error \(code). \(error.localizedDescription). Please try again.")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false, code)
                return
            }
            
            let result = self.handlerTLVFormat(data: data)
            let pubkey = Data(bytes: result.v, count: result.v.count).hexadecimal()
            self.ed_publicKey = pubkey
            completionHandler(code == "9000", code)
        }
    }
    
    private func getPrivateKeyCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        guard let pincode = pincode else {
            completionHandler(false, "00")
            return
        }
        
        var dataCommand = self.dataCommandPin(pincode: pincode)
        if let finalSecret = self.finalSecret {
            dataCommand = SecureData.encryptCommandData(cmdData: dataCommand, secretKey: finalSecret) ?? dataCommand
        }

        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_EXPORT_PRIVATE_KEY.rawValue, p1Parameter: 0, p2Parameter: 0, data: dataCommand, expectedResponseLength: 64)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            
            if let error = error {
                session.invalidate(errorMessage: "Some error occurred. Error \(code). \(error.localizedDescription). Please try again.")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false, code)
                return
            }
            
            let result = self.handlerTLVFormat(data: data)
            let pk = Data(bytes: result.v, count: result.v.count).hexadecimal()
            self.privateKey = pk
            completionHandler(code == "9000", code)
        }
    }
    
    private func disableGetPrivateKeyCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        guard let pincode = pincode else {
            completionHandler(false, "00")
            return
        }
        
        var dataCommand = self.dataCommandPin(pincode: pincode)
        if let finalSecret = self.finalSecret {
            dataCommand = SecureData.encryptCommandData(cmdData: dataCommand, secretKey: finalSecret) ?? dataCommand
        }
        
        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_DISABLE_PRIVATE_KEY_EXPORT.rawValue, p1Parameter: 0, p2Parameter: 0, data: dataCommand, expectedResponseLength: 64)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            
            if let error = error {
                session.invalidate(errorMessage: "Some error occurred. Error \(code). \(error.localizedDescription). Please try again.")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false, code)
                return
            }
            
            completionHandler(code == "9000", code)
        }
    }
    
    private func getCardGUIDCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_GET_CARD_GUID.rawValue, p1Parameter: 0, p2Parameter: 0, data: Data(), expectedResponseLength: -1)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            
            if let error = error {
                session.invalidate(errorMessage: "Some error occurred. Error \(code). \(error.localizedDescription). Please try again.")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false, code)
                return
            }
            
            let result = self.handlerTLVFormat(data: data)
            self.cardGUID = self.generateGUID(bytes: result.v)
            completionHandler(true, code)
        }
        
    }
    
    private func activateCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        guard let pincode = pincode else {
            completionHandler(false, "00")
            return
        }
        
        var dataCommand = self.dataCommandPin(pincode: pincode)
        if let finalSecret = self.finalSecret {
            dataCommand = SecureData.encryptCommandData(cmdData: dataCommand, secretKey: finalSecret) ?? dataCommand
        }

        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_ACTIVATE.rawValue, p1Parameter: 0, p2Parameter: 0, data: dataCommand, expectedResponseLength: -1)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            if let error = error {
                session.invalidate(errorMessage: "Send command error \(code). \(error.localizedDescription). Please try again.")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false, code)
                return
            }
            
            completionHandler(code == "9000", code)
        }
    }
    
    private func setNewPincodeCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        guard let pincode = pincode else {
            completionHandler(false, "00")
            return
        }
        
        guard let newPincode = newPincode else {
            completionHandler(false, "00")
            return
        }
        
        var resultBytes = [UInt8]()
        resultBytes.append(contentsOf: self.dataCommandPin(pincode: pincode).copyBytes())
        resultBytes.append(contentsOf: self.dataCommandPin(pincode: newPincode).copyBytes())
        
        var dataCommand = Data(resultBytes)
        if let finalSecret = self.finalSecret {
            dataCommand = SecureData.encryptCommandData(cmdData: dataCommand, secretKey: finalSecret) ?? dataCommand
        }

        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_CHANGE_PIN.rawValue, p1Parameter: 0, p2Parameter: 0, data: dataCommand, expectedResponseLength: -1)
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            
            if let error = error {
                session.invalidate(errorMessage: "Set new PIN error \(code). \(error.localizedDescription). Please try again.")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false, code)
                return
            }
            completionHandler(code == "9000", code)
        }
        
    }
    
    private func unlockCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        guard let pincode = pincode else {
            completionHandler(false, "00")
            return
        }
        
        var dataCommand = self.dataCommandPin(pincode: pincode)
        if let finalSecret = self.finalSecret {
            dataCommand = SecureData.encryptCommandData(cmdData: dataCommand, secretKey: finalSecret) ?? dataCommand
        }

        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_UNLOCK.rawValue, p1Parameter: 0, p2Parameter: 0, data: dataCommand, expectedResponseLength: -1)
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            
            if let error = error {
                self.delegate?.cardService?(self, error: error)
                session.invalidate(errorMessage: "Unlock command error \(code). \(error.localizedDescription). Please try again.")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false, code)
                return
            }
            
            completionHandler(code == "9000", code)
        }
    }
    
    private func signCommandWithoutPin(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        guard let dataForSign = self.dataForSign else {
            session.invalidate(errorMessage: "Sign command error 9. Please try again.")
            completionHandler(false, "00")
            return
        }
        
        let group = DispatchGroup()
        var signedDataArray = [String]()
        for (_, item) in dataForSign.enumerated() {
            
            var instructionCode = InstructionCode.INS_SIGN_DATA.rawValue
            if item.0 == "EDDSA" {
                instructionCode = InstructionCode.INS_ED_SIGN_DATA.rawValue
            }
            
            var resultBytes = [UInt8]()
            //resultBytes.append(contentsOf: self.dataCommandPin(pincode: pincode).copyBytes())
            
            instructionCode = InstructionCode.INS_SIGN_PROCESSING_DATA.rawValue
            
            guard let hexadecimal = item.1.hexadecimal else {
                continue
            }
            
            guard let gatewaySignatureHexadecimal = self.gatewaySignature.hexadecimal else {
                continue
            }
            
            let payloadBytes: [UInt8] = [UInt8](hexadecimal)
            let gatewaySignatureBytes: [UInt8] = [UInt8](gatewaySignatureHexadecimal)
            
            resultBytes.append(Tag.DATA_FOR_SIGN)
            resultBytes.append(UInt8(payloadBytes.count))
            resultBytes.append(contentsOf: payloadBytes)
            
            resultBytes.append(Tag.DATA_SIGNATURE)
            resultBytes.append(UInt8(gatewaySignatureBytes.count))
            resultBytes.append(contentsOf: gatewaySignatureBytes)
            
            var dataCommand = Data(resultBytes)
            
            if let finalSecret = self.finalSecret {
                dataCommand = SecureData.encryptCommandData(cmdData: dataCommand, secretKey: finalSecret) ?? dataCommand
            }
            
            let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: instructionCode, p1Parameter: 0, p2Parameter: 0, data: dataCommand, expectedResponseLength: -1)
            
            group.enter()
            iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
                let st1 = String(format:"%02X", p1)
                let st2 = String(format:"%02X", p2)
                let code = st1+st2
                
                if let error = error {
                    session.invalidate(errorMessage: "Sign command error \(code). \(error.localizedDescription). Please try again.")
                    self.delegate?.cardService?(self, error: error)
                    completionHandler(false, code)
                    return
                }
                
                let result = self.handlerTLVFormat(data: data)
                signedDataArray.append(Data(bytes: result.v, count: result.v.count).hexadecimal())
                
                if code != "9000" {
                    completionHandler(false, code)
                }
                group.leave()
            }
        }
        
        group.notify(queue: self.internalQueue) {
            self.delegate?.cardService?(self, signed: signedDataArray)
            completionHandler(true, "9000")
        }
        
    }
    
    private func signCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        guard let pincode = pincode else {
            completionHandler(false, "00")
            return
        }
        
        guard let dataForSign = self.dataForSign else {
            session.invalidate(errorMessage: "Sign command error 9. Please try again.")
            completionHandler(false, "00")
            return
        }
        
        let group = DispatchGroup()
        var signedDataArray = [String]()
        for (_, item) in dataForSign.enumerated() {
            
            guard let hexadecimal = item.1.hexadecimal else {
                continue
            }
            
            var instructionCode = InstructionCode.INS_SIGN_DATA.rawValue
            if item.0 == "EDDSA" {
                instructionCode = InstructionCode.INS_ED_SIGN_DATA.rawValue
            }
            
            let payloadBytes: [UInt8] = [UInt8](hexadecimal)
            
            var resultBytes = [UInt8]()
            resultBytes.append(contentsOf: self.dataCommandPin(pincode: pincode).copyBytes())
            
            resultBytes.append(Tag.DATA_FOR_SIGN)
            resultBytes.append(UInt8(payloadBytes.count))
            resultBytes.append(contentsOf: payloadBytes)
            
            var dataCommand = Data(resultBytes)
            if let finalSecret = self.finalSecret {
                dataCommand = SecureData.encryptCommandData(cmdData: dataCommand, secretKey: finalSecret) ?? dataCommand
            }

            let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: instructionCode, p1Parameter: 0, p2Parameter: 0, data: dataCommand, expectedResponseLength: -1)
            
            group.enter()
            iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
                let st1 = String(format:"%02X", p1)
                let st2 = String(format:"%02X", p2)
                let code = st1+st2
                
                if let error = error {
                    session.invalidate(errorMessage: "Sign command error 8. Please try again. Error \(code). \(error.localizedDescription)")
                    self.delegate?.cardService?(self, error: error)
                    completionHandler(false, code)
                    return
                }
                
                let result = self.handlerTLVFormat(data: data)
                signedDataArray.append(Data(bytes: result.v, count: result.v.count).hexadecimal())
                
                if code != "9000" {
                    completionHandler(false, code)
                }
                group.leave()
            }
        }
        
        group.notify(queue: internalQueue) {
            self.delegate?.cardService?(self, signed: signedDataArray)
            completionHandler(true, "9000")
        }
        
    }
    
    private func signV4CommandWithoutPin(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        guard let dataForSign = self.dataForSign else {
            session.invalidate(errorMessage: "Sign command error 6. Please try again.")
            completionHandler(false, "00")
            return
        }
        
        guard let gatewaySignatureHexadecimal = self.gatewaySignature.hexadecimal else {
            session.invalidate(errorMessage: "Sign command error 7. Please try again.")
            completionHandler(false, "00")
            return
        }
        
        let gatewaySignatureBytes: [UInt8] = [UInt8](gatewaySignatureHexadecimal)
        
        let group = DispatchGroup()
        var signedDataArray = [String]()
        for (_, item) in dataForSign.enumerated() {
            
            guard let hexadecimal = item.1.hexadecimal else {
                continue
            }
            
            let payloadBytes: [UInt8] = [UInt8](hexadecimal)
            
            var resultBytes = [UInt8]()
            
            var instructionCode = InstructionCode.INS_SIGN_PROCESSING_DATA.rawValue
            
            switch item.0.uppercased() {
            case "EDDSA":
                instructionCode = InstructionCode.INS_ED_SIGN_PROCESSING_DATA.rawValue
                
                resultBytes.append(Tag.DATA_FOR_SIGN)
                resultBytes.append(UInt8(payloadBytes.count))
                resultBytes.append(contentsOf: payloadBytes)
                
                resultBytes.append(Tag.DATA_SIGNATURE)
                resultBytes.append(UInt8(gatewaySignatureBytes.count))
                resultBytes.append(contentsOf: gatewaySignatureBytes)
            default:
                instructionCode = InstructionCode.INS_SIGN_PROCESSING_DATA.rawValue
                
                resultBytes.append(Tag.DATA_FOR_SIGN)
                resultBytes.append(UInt8(payloadBytes.count))
                resultBytes.append(contentsOf: payloadBytes)
                
                resultBytes.append(Tag.DATA_SIGNATURE)
                resultBytes.append(UInt8(gatewaySignatureBytes.count))
                resultBytes.append(contentsOf: gatewaySignatureBytes)
                
            }
            
            var dataCommand = Data(resultBytes)
            if let finalSecret = self.finalSecret {
                dataCommand = SecureData.encryptCommandData(cmdData: dataCommand, secretKey: finalSecret) ?? dataCommand
            }

            let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: instructionCode, p1Parameter: 0, p2Parameter: 0, data: dataCommand, expectedResponseLength: -1)
            
            group.enter()
            iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
                let st1 = String(format:"%02X", p1)
                let st2 = String(format:"%02X", p2)
                let code = st1+st2
                
                if let error = error {
                    session.invalidate(errorMessage: "Sign command error \(code). \(error.localizedDescription). Please try again.")
                    self.delegate?.cardService?(self, error: error)
                    completionHandler(false, code)
                    return
                }
                
                let result = self.handlerTLVFormat(data: data)
                signedDataArray.append(Data(bytes: result.v, count: result.v.count).hexadecimal())
                
                if code != "9000" {
                    completionHandler(false, code)
                }
                group.leave()
            }
        }
        
        group.notify(queue: self.internalQueue) {
            self.delegate?.cardService?(self, signed: signedDataArray)
            completionHandler(true, "9000")
        }
        
    }
    
    
    private func signV4Command(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool, String) -> Void)) {
        
        guard let pincode = pincode else {
            completionHandler(false, "00")
            return
        }
        
        guard let dataForSign = self.dataForSign else {
            session.invalidate(errorMessage: "Sign command error 6. Please try again.")
            completionHandler(false, "00")
            return
        }
        
        let group = DispatchGroup()
        var signedDataArray = [String]()
        for (_, item) in dataForSign.enumerated() {
            
            let payloadBytes: [UInt8] = [UInt8](self.ed_payload.hexadecimal ?? Data())
            let publicKeyBytes: [UInt8] = [UInt8](self.ed_publicKey.hexadecimal ?? Data())
            let privateNonceBytes: [UInt8] = [UInt8](self.ed_privateNonce.hexadecimal ?? Data())
            let publicNonceBytes: [UInt8] = [UInt8](self.ed_publicNonce.hexadecimal ?? Data())
            let payloadForSignatureBytes: [UInt8] = self.ed_payloadForSignature.hexadecimal?.copyBytes() ?? [UInt8]()
            
            var resultBytes = [UInt8]()
            resultBytes.append(contentsOf: self.dataCommandPin(pincode: pincode).copyBytes())
            
            var instructionCode = InstructionCode.INS_SIGN_DATA.rawValue
            
            switch item.0.uppercased() {
            case "EDDSA":
                instructionCode = InstructionCode.INS_ED_SIGN_DATA.rawValue
                
                if payloadForSignatureBytes.count > 0 {
                    resultBytes.append(contentsOf: payloadForSignatureBytes)
                    print("resultBytes: \(Data(resultBytes).hexadecimal())")
                } else {
                    resultBytes.append(Tag.ED_CARD_PUBLIC_KEY_ENCODED)
                    resultBytes.append(UInt8(publicKeyBytes.count))
                    resultBytes.append(contentsOf: publicKeyBytes)
                    
                    //private nonce
                    resultBytes.append(Tag.ED_PRIVATE_NONCE)
                    resultBytes.append(UInt8(privateNonceBytes.count))
                    resultBytes.append(contentsOf: privateNonceBytes)
                    
                    //public nonce
                    resultBytes.append(Tag.ED_PUBLIC_NONCE)
                    resultBytes.append(UInt8(publicNonceBytes.count))
                    resultBytes.append(contentsOf: publicNonceBytes)
                    
                    resultBytes.append(Tag.DATA_FOR_SIGN)
                    resultBytes.append(UInt8(payloadBytes.count))
                    resultBytes.append(contentsOf: payloadBytes)
                    
                    print("resultBytes: \(Data(resultBytes).hexadecimal())")
                }
            default:
                instructionCode = InstructionCode.INS_SIGN_DATA.rawValue
                
                guard let hexadecimal = item.1.hexadecimal else {
                    continue
                }
                
                let payloadBytes: [UInt8] = [UInt8](hexadecimal)
                resultBytes.append(Tag.DATA_FOR_SIGN)
                resultBytes.append(UInt8(payloadBytes.count))
                resultBytes.append(contentsOf: payloadBytes)
            }
            
            var dataCommand = Data(resultBytes)
            if let finalSecret = self.finalSecret {
                dataCommand = SecureData.encryptCommandData(cmdData: dataCommand, secretKey: finalSecret) ?? dataCommand
            }

            let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: instructionCode, p1Parameter: 0, p2Parameter: 0, data: dataCommand, expectedResponseLength: -1)
            
            group.enter()
            iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
                let st1 = String(format:"%02X", p1)
                let st2 = String(format:"%02X", p2)
                let code = st1+st2
                
                if let error = error {
                    session.invalidate(errorMessage: "Sign command error \(code). Please try again. \(error.localizedDescription)")
                    self.delegate?.cardService?(self, error: error)
                    completionHandler(false, code)
                    return
                }
                                
                if code != "9000" {
                    completionHandler(false, code)
                } else {
                    let result = self.handlerTLVFormat(data: data)
                    signedDataArray.append(Data(bytes: result.v, count: result.v.count).hexadecimal())
                }
                group.leave()
            }
        }
        
        group.notify(queue: self.internalQueue) {
            self.delegate?.cardService?(self, signed: signedDataArray)
            completionHandler(true, "9000")
        }
        
    }
    
    //MARK: - Tools Private
    private func handlerTLVFormat(data: Data) -> (t: UInt8, l: UInt8, v: [UInt8]) {
        var data = data
        if let finalSecret = self.finalSecret, data.count > 16 {
            data = SecureData.decryptResponseData(responseData: data, secretKey: finalSecret, sw1: 90, sw2: 00) ?? data
        }

        var result: (t: UInt8, l: UInt8, v: [UInt8]) = (t: 0, l: 0, v: [UInt8]())
        let bytes = data.copyBytes()
        
        if bytes.count == 0 {
            return result
        }
        result.t = bytes[0]
        result.l = bytes[1]
        for (index, element) in bytes.enumerated() {
            if index == 0 || index == 1 {
                continue
            }
            result.v.append(element)
        }
        return result
    }

    private func handlerTLVFormat_deprecated(data: Data) -> (t: UInt8, l: UInt8, v: [UInt8]) {
        var result: (t: UInt8, l: UInt8, v: [UInt8]) = (t: 0, l: 0, v: [UInt8]())
        let bytes = data.copyBytes()
        
        if bytes.count == 0 {
            return result
        }
        result.t = bytes[0]
        result.l = bytes[1]
        for (index, element) in bytes.enumerated() {
            if index == 0 || index == 1 {
                continue
            }
            result.v.append(element)
        }
        return result
    }

    
    private func generateGUID(bytes: [UInt8]) -> String {
        var output = ""
        
        for (index, byte) in bytes.enumerated() {
            let nextCharacter = String(byte, radix: 16, uppercase: true)
            if nextCharacter.count == 2 {
                output += nextCharacter
            } else {
                output += "0" + nextCharacter
            }
            
            if [3, 5, 7, 9].firstIndex(of: index) != nil {
                output += "-"
            }
        }
        
        return output.lowercased()
        
    }
    
    private func value(bytes: [UInt8]) -> String {
        var output = ""
        for byte in bytes {
            let nextCharacter = String(byte, radix: 16, uppercase: false)
            output += nextCharacter
        }
        return output
    }
    
    private func pinGetBytes(pin: String) -> [UInt8] {
        var pinBytes: [UInt8] = Array(pin.utf8)
        for (index, value) in pinBytes.enumerated() {
            pinBytes[index] = value - 48
        }
        return pinBytes
    }
    
    private func dataCommandPin(pincode: String) -> Data {
        var resultBytes = [UInt8]()
        let pinBytes: [UInt8] = self.pinGetBytes(pin: pincode)
        resultBytes.append(Tag.CARD_PIN)
        
        switch aid {
        case .v1:
            resultBytes.append(Lenght.CARD_PIN_MIN_LENGTH)
        case .v2:
            resultBytes.append(Lenght.CARD_PIN_MAX_LENGTH)
        case .v3:
            resultBytes.append(Lenght.CARD_PIN_MAX_LENGTH)
        default:
            resultBytes.append(Lenght.CARD_PIN_MAX_LENGTH)
        }
        
        resultBytes.append(contentsOf: pinBytes)
        let dataCommand = Data(resultBytes)

        return dataCommand
    }

    private func dataCommand(value: String) -> Data? {
        var resultBytes = [UInt8]()
        guard let valueBytes: [UInt8] = value.hexadecimal?.copyBytes() else {
            return nil
        }
        resultBytes.append(Tag.CARD_PUBLIC_KEY)
        resultBytes.append(Lenght.CARD_PUBLIC_KEY_MAX_LENGTH)
        resultBytes.append(contentsOf: valueBytes)
        let dataCommand = Data(resultBytes)
        return dataCommand
    }

    private func sign(session: NFCTagReaderSession, tag: NFCTag, iso7816Tag: NFCISO7816Tag) {
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        self.delegate?.cardService?(self, progress: 0.3)
        
        session.connect(to: tag) { (error: Error?) in
            if let error = error {
                self.delegate?.cardService?(self, progress: 1)
                self.delegate?.cardService?(self, error: error)
                session.invalidate(errorMessage: "This card isn't a Ammer Wallet or it is blocked. \(error.localizedDescription).")
                return
            }
            if let _ = self.dataForSign, let _ = self.pincode {
                
                self.getPINAttemptsCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
                    self.delegate?.cardService?(self, progress: 0.5)
                    if !success {
                        self.delegate?.cardService?(self, progress: 1)
                        session.invalidate(errorMessage: "Get PIN attemts error \(code)")
                        return
                    }
                    
                    self.unlockCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
                        self.delegate?.cardService?(self, progress: 0.6)
                        if !success {
                            self.delegate?.cardService?(self, incorrectPIN: self.publicKey)
                            self.delegate?.cardService?(self, progress: 1)
                            session.invalidate(errorMessage: "Sign command meta data card error \(code)\nRemaining PIN attempts \(self.attempts - 1)/\(self.allAttempts)")
                            return
                        }
                        
                        switch self.aid {
                        case .v4, .v5, .v6:
                            self.signV4Command(session: session, iso7816Tag: iso7816Tag) { success, code in
                                self.delegate?.cardService?(self, progress: 1)
                                if !success {
                                    session.invalidate(errorMessage: "Sign command meta data card error \(code)")
                                    return
                                }
                                session.invalidate()
                            }
                        default:
                            self.signCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
                                self.delegate?.cardService?(self, progress: 1)
                                if !success {
                                    session.invalidate(errorMessage: "Sign command meta data card error \(code)")
                                    return
                                }
                                session.invalidate()
                            }
                        }
                    }
                }
                
            } else {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Data for sign error 23")
                return
                
            }
            
        }
    }
    
    private func pay(session: NFCTagReaderSession, tag: NFCTag, iso7816Tag: NFCISO7816Tag) {
        
        if needPIN {
            if let _ = self.dataForSign, let _ = self.pincode {
                switch self.aid {
                case .v4, .v5:
                    self.signV4Command(session: session, iso7816Tag: iso7816Tag) { success, code in
                        self.delegate?.cardService?(self, progress: 1)
                        if !success {
                            session.invalidate(errorMessage: "Sign command meta data card error \(code)")
                            return
                        }
                        session.alertMessage = "Transaction signed successfully"
                        session.invalidate()
                    }
                    
                default:
                    self.signCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
                        self.delegate?.cardService?(self, progress: 1)
                        if !success {
                            session.invalidate(errorMessage: "Sign command meta data card error \(code)")
                            return
                        }
                        session.alertMessage = "Transaction signed successfully"
                        session.invalidate()
                    }
                }
                
            } else {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Do data for sign error 26")
                return
            }
        } else {
            switch self.aid {
            case .v4, .v5:
                self.signV4CommandWithoutPin(session: session, iso7816Tag: iso7816Tag) { success, code in
                    self.delegate?.cardService?(self, progress: 1)
                    if !success {
                        session.invalidate(errorMessage: "Sign command meta data card error \(code)")
                        return
                    }
                    session.alertMessage = "Transaction signed successfully"
                    session.invalidate()
                }
                
            default:
                self.signCommandWithoutPin(session: session, iso7816Tag: iso7816Tag) { success, code in
                    self.delegate?.cardService?(self, progress: 1)
                    if !success {
                        session.invalidate(errorMessage: "Sign command meta data card error \(code)")
                        return
                    }
                    session.alertMessage = "Transaction signed successfully"
                    session.invalidate()
                }
            }
            
        }
        
    }
    
    private func getPKData(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag) {
        self.delegate?.cardService?(self, progress: 0.1)
        
        let group = DispatchGroup()
        
        group.enter()
        self.getIssuerCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
            self.delegate?.cardService?(self, progress: 0.5)
            if !success {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Get issuer data error \(code)")
                return
            }
            group.leave()
        }
        
        group.enter()
        self.getPrivateKeyCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
            self.delegate?.cardService?(self, progress: 0.5)
            if !success {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Get private key data error \(code)")
                return
            }
            group.leave()
        }
        
        group.notify(queue: self.internalQueue) {
            self.delegate?.cardService?(self, progress: 1)
            self.delegate?.cardService?(self, privateKey: self.privateKey, issuer: self.issuer)
            session.invalidate()
        }
        
    }
    
    private func getData(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping(() -> Void)) {
        
        let group = DispatchGroup()
        
        group.enter()
        self.getCardGUIDCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
            self.delegate?.cardService?(self, progress: 0.5)
            if !success {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Get card guid data error \(code)")
                return
            }
            group.leave()
        }
        
        group.enter()
        self.getPublicKeyCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
            self.delegate?.cardService?(self, progress: 0.5)
            if !success {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Get public key data error \(code)")
                return
            }
            group.leave()
        }
        
        group.enter()
        self.getPINAttemptsCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
            self.delegate?.cardService?(self, progress: 0.5)
            if !success {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Get PIN retries error \(code)")
                return
            }
            group.leave()
        }
        
        switch self.aid {
        case .v5, .v6:
            group.enter()
            self.getEDPublicKeyCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
                self.delegate?.cardService?(self, progress: 0.5)
                if !success {
                    self.delegate?.cardService?(self, progress: 1)
                    session.invalidate(errorMessage: "Get ed public key data error \(code)")
                    return
                }
                group.leave()
            }
        default:
            break
        }
        
        group.enter()
        self.getIssuerCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
            self.delegate?.cardService?(self, progress: 0.5)
            if !success {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Get issuer data error \(code)")
                return
            }
            group.leave()
        }
        
        group.notify(queue: self.internalQueue) {
            self.delegate?.cardService?(self, progress: 1)
            self.delegate?.cardService?(self, pubKey: self.publicKey, guid: self.cardGUID, issuer: self.issuer, state: self.stateCard, aid: self.aid)
            self.delegate?.cardService?(self, pubKey: self.publicKey, ed_pubKey: self.ed_publicKey, guid: self.cardGUID, issuer: self.issuer, state: self.stateCard, aid: self.aid)
            completionHandler()
            session.invalidate()
        }
        
    }
    
    private func getPublicKeyForPay(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag) {
        
        let group = DispatchGroup()
        
        group.enter()
        self.getCardGUIDCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
            self.delegate?.cardService?(self, progress: 0.5)
            if !success {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Get card guid data error \(code)")
                return
            }
            group.leave()
        }
        
        group.enter()
        self.getPublicKeyCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
            if !success {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Get public key data error \(code)")
                return
            }
            self.delegate?.cardService?(self, progress: 1)
            group.leave()
        }
        
        group.notify(queue: self.internalQueue) {
            self.delegate?.cardService?(self, progress: 1)
            self.delegate?.cardService?(self, pubKey: self.publicKey, guid: self.cardGUID, issuer: self.issuer, state: self.stateCard, aid: self.aid)
            self.delegate?.cardService?(self, pubKey: self.publicKey, ed_pubKey: self.ed_publicKey, guid: self.cardGUID, issuer: self.issuer, state: self.stateCard, aid: self.aid)
            //session.invalidate()
        }
        
    }
    
    private func getDataSlice(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag) {
        
        let group = DispatchGroup()
        
        group.enter()
        self.getCardGUIDCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
            self.delegate?.cardService?(self, progress: 0.5)
            if !success {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Get card guid data error \(code)")
                return
            }
            group.leave()
        }
        
        group.enter()
        self.getIssuerCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
            self.delegate?.cardService?(self, progress: 0.5)
            if !success {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Get issuer data error \(code)")
                return
            }
            group.leave()
        }
        
        group.notify(queue: self.internalQueue) {
            self.delegate?.cardService?(self, progress: 1)
            self.delegate?.cardService?(self, state: self.stateCard, guid: self.cardGUID, issuer: self.issuer, aid: self.aid)
            //session.invalidate()
        }
        
    }
    
    private func dataToJson(_ data: Data) -> [String: Any]? {
        do {
            let result = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [String: Any]()
            return result
        } catch {
            //print("Error handler data: \(error)")
        }
        return nil
    }
    
    
    //MARK: -
    private func connect(session: NFCTagReaderSession, tag: NFCTag, iso7816Tag: NFCISO7816Tag) {
        
        self.delegate?.cardService?(self, progress: 0.1)
        
        if self.command == .sign {
            self.handshakeCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
                if !success {
                    self.delegate?.cardService?(self, progress: 1)
                    session.invalidate(errorMessage: "Handshake error \(code)")
                    return
                }
                self.sign(session: session, tag: tag, iso7816Tag: iso7816Tag)
            }
            return
        }
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        session.connect(to: tag) { (error: Error?) in
            if let error = error {
                self.delegate?.cardService?(self, progress: 1)
                self.delegate?.cardService?(self, error: error)
                session.invalidate(errorMessage: "This card isn't a Ammer Wallet or it is blocked. \(error.localizedDescription).")
                return
            }
            
            self.getStateCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
                if !success {
                    self.delegate?.cardService?(self, progress: 1)
                    self.delegate?.cardService?(self, message: "This card isn't a Ammer Wallet or it is blocked.")
                    session.invalidate(errorMessage: "This card isn't a Ammer Wallet or it is blocked.")
                    return
                }
                self.handshakeCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
                    self.delegate?.cardService?(self, progress: 0.4)
                    if !success {
                        self.delegate?.cardService?(self, progress: 1)
                        session.invalidate(errorMessage: "Handshake error \(code)")
                        return
                    }
                    
                    switch self.stateCard {
                    case .UNDEFINED:
                        self.delegate?.cardService?(self, progress: 1)
                        self.delegate?.cardService?(self, state: self.stateCard, guid: self.cardGUID, issuer: self.issuer, aid: self.aid)
                        session.invalidate(errorMessage: "State card undefined error \(code)")
                        return
                    case .ACTIVATED_LOCKED:
                        if let _ = self.pincode {
                            self.getPINAttemptsCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
                                self.delegate?.cardService?(self, progress: 0.5)
                                if !success {
                                    self.delegate?.cardService?(self, progress: 1)
                                    session.invalidate(errorMessage: "Get PIN attemts error \(code)")
                                    return
                                }
                                self.unlockCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
                                    if !success {
                                        self.delegate?.cardService?(self, incorrectPIN: self.publicKey)
                                        self.delegate?.cardService?(self, progress: 1)
                                        session.invalidate(errorMessage: "Invalid PIN. Error \(code). You only have \(self.allAttempts) attempts\nRemaining PIN attempts \(self.attempts - 1)/\(self.allAttempts)")
                                        return
                                    }
                                    self.delegate?.cardService?(self, progress: 0.3)
                                    if self.command == .setNewPin {
                                        self.setNewPincodeCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
                                            self.delegate?.cardService?(self, progress: 1)
                                            if !success {
                                                session.invalidate(errorMessage: "Set new PIN error. Error \(code)")
                                                return
                                            }
                                            if let newPincode = self.newPincode {
                                                self.delegate?.cardService?(self, changePINSuccess: newPincode)
                                            }
                                            session.alertMessage = "Pin changed successfully"
                                            session.invalidate()
                                        }
                                    } else if self.command == .getPrivateKey {
                                        self.getPKData(session: session, iso7816Tag: iso7816Tag)
                                    } else if self.command == .pay {
                                        //self.getPublicKeyForPay(session: session, iso7816Tag: iso7816Tag)
                                        self.pay(session: session, tag: tag, iso7816Tag: iso7816Tag)
                                    } else {
                                        self.getData(session: session, iso7816Tag: iso7816Tag) {}
                                    }
                                }
                            }
                            
                        } else {
                            self.getDataSlice(session: session, iso7816Tag: iso7816Tag)
                        }
                    case .INITED:
                        if let pincode = self.pincode {
                            
                            self.activateCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
                                if !success {
                                    self.delegate?.cardService?(self, progress: 1)
                                    session.invalidate(errorMessage: "Activate card error \(code).")
                                    return
                                }
                                self.unlockCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
                                    if !success {
                                        self.delegate?.cardService?(self, incorrectPIN: self.publicKey)
                                        self.delegate?.cardService?(self, progress: 1)
                                        session.invalidate(errorMessage: "Invalid PIN. Error \(code). You only have \(self.allAttempts) attempts")
                                        return
                                    }
                                    self.getData(session: session, iso7816Tag: iso7816Tag) { [weak self] in
                                        guard let self = self else {return}
                                        self.delegate?.cardService?(self, inited: self.publicKey, pin: pincode)
                                    }
                                }
                            }
                        } else {
                            self.delegate?.cardService?(self, progress: 1)
                            self.delegate?.cardService?(self, state: self.stateCard, guid: self.cardGUID, issuer: self.issuer, aid: self.aid)
                            session.invalidate()
                        }
                        
                    case .NOT_INITED:
                        print("NOT_INITED")
                        break
                    case .ACTIVATED_UNLOCKED:
                        print("ACTIVATED_UNLOCKED")
                        break
                    }

                }
            }
            
        }
    }
    
    //MARK: - Public
    public func begin(alertMessage: String = "Please hold your card up against the rear side of your iPhone, next to the camera.") {
        guard NFCTagReaderSession.readingAvailable else {
            let alertController = UIAlertController(
                title: "Scanning Not Supported",
                message: "This device doesn't support tag scanning.",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            DispatchQueue.main.async {
                UIApplication.topViewController()?.present(alertController, animated: true, completion: nil)
            }
            return
        }
        
        let session = NFCTagReaderSession(pollingOption: NFCTagReaderSession.PollingOption.iso14443, delegate: self)
        session?.alertMessage = alertMessage
        session?.begin()
        
    }
    
    public func setPin(_ value: String) {
        self.pincode = value
    }
    
    public func setEDPayloadForSignature(_ value: String) {
        self.ed_payloadForSignature = value
    }
    
    public func setEDPayload(_ value: String) {
        self.ed_payload = value
    }
    
    public func setEDPrivateNonce(_ value: String) {
        self.ed_privateNonce = value
    }
    
    public func setEDPublicNonce(_ value: String) {
        self.ed_publicNonce = value
    }
    
    public func setEDPublicKey(_ value: String) {
        self.ed_publicKey = value
    }
    
    public func setNeedPIN(_ value: Bool) {
        self.needPIN = value
    }
    
    public func setGatewaySignature(_ value: String) {
        self.gatewaySignature = value
    }
    
    public func sign(_ dataForSign: [(String, String)]) {
        self.dataForSign = dataForSign
        guard let session = session else {return}
        guard let iso7816Tag = iso7816Tag else {return}
        guard let tag = tag else {return}
        self.sign(session: session, tag: tag, iso7816Tag: iso7816Tag)
        
    }
    
    public func pay(_ dataForSign: [(String, String)]) {
        self.dataForSign = dataForSign
        guard let session = session else {return}
        guard let iso7816Tag = iso7816Tag else {return}
        guard let tag = tag else {return}
        if session.isReady {
            self.pay(session: session, tag: tag, iso7816Tag: iso7816Tag)
        } else {
            self.begin()
        }
    }
    
    public func setAlertMessage(_ text: String) {
        guard let session = session else {return}
        session.alertMessage = text
    }
    
    public func invalidate(_ text: String) {
        self.session?.invalidate(errorMessage: text)
    }
    
    public func invalidate() {
        self.session?.invalidate()
    }
    
}

//MARK: - NFCTagReaderSessionDelegate
extension CardNFCService: NFCTagReaderSessionDelegate {
    
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("tagReaderSessionDidBecomeActive")
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print("didInvalidateWithError: \(error.localizedDescription)")
        self.delegate?.cardService?(self, error: error)
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("didDetect")
        for tag in tags {
            switch tag {
            case let .iso7816(iso7816Tag):
                print("iso7816Tag.identifier: \(iso7816Tag.identifier)")
                print("iso7816Tag.identifier bytes: \(iso7816Tag.identifier.copyBytes())")
                print("iso7816Tag.initialSelectedAID: \(iso7816Tag.initialSelectedAID)")
                print("iso7816Tag.applicationData: \(String(describing: iso7816Tag.applicationData))")
                self.session = session
                self.iso7816Tag = iso7816Tag
                self.tag = tag
                
                self.aid = AIDVersion(rawValue: iso7816Tag.initialSelectedAID) ?? .undefined
                switch self.aid {
                case .v5, .v6:
                    self.allAttempts = 10
                case .v1, .v2, .v3, .v4:
                    self.allAttempts = 3
                default:
                    self.allAttempts = 3
                }
                
                if self.aid == .terminal {
                    self.getInvoiceCommand(session: session, iso7816Tag: iso7816Tag) { success, code in
                        print("get invoice command: \(success)")
                    }
                } else {
                    self.connect(session: session, tag: tag, iso7816Tag: iso7816Tag)
                }
            default:
                session.invalidate(errorMessage: "Card not valid")
                return
            }
        }
    }
}
