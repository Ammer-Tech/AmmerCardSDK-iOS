
import Foundation
import CoreNFC
import UIKit

public final class CardNFCService: NSObject {
    
    private var fullResponse: [UInt8]
    private var pincode: String?
    private var newPincode: String?
    private var dataForSign: String?
    private var dataForSignArray: [String]?
    private var stateCard: MetaState = .UNDEFINED
    
    private var command: Command = .undefined
    private var cardGUID: String = ""
    private var publicKey: String = ""
    private var privateKey: String = ""
    private var issuer: String = ""
    private var aid: AIDVersion = .undefined
    
    private var delegate: CardNFCServiceDelegate?
    
    private var session: NFCTagReaderSession?
    private var iso7816Tag: NFCISO7816Tag?
    private var tag: NFCTag?
    
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
    
    public convenience init(delegate: CardNFCServiceDelegate, command: Command, pincode: String, dataForSignArray: [String]) {
        self.init()
        self.command = command
        self.pincode = pincode
        self.dataForSignArray = dataForSignArray
        self.delegate = delegate
    }
    
    //MARK: - Commands Private
    private func getInvoiceCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool) -> Void)) {
        
        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_GET_STATE.rawValue, p1Parameter: 0, p2Parameter: 0, data: Data(), expectedResponseLength: -1)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            if let error = error {
                session.invalidate(errorMessage: "Some error occurred. Please try again. \(error.localizedDescription)")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false)
                return
            }
            
            #if Debug
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            print("\(#function) code: \(code)")
            #endif
            
            if let res = self.dataToJson(data) {
                let amount = res["amount"] as? String ?? "0"
                let assetId = res["assetID"] as? String ?? ""
                let address = res["address"] as? String ?? ""
                let transactionId = res["transactionID"] as? String ?? ""
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
                    self.delegate?.cardService?(self, amount: amount, address: address, assetId: assetId, transactionId: transactionId)
                }
                //session.invalidate()
            } else {
                session.invalidate(errorMessage: "Incorrect format. Please try again.")
            }
                
            
        }
        
    }

    private func getStateCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool) -> Void)) {
        
        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_GET_STATE.rawValue, p1Parameter: 0, p2Parameter: 0, data: Data(), expectedResponseLength: -1)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            if let error = error {
                session.invalidate(errorMessage: "Some error occurred. Please try again. \(error.localizedDescription)")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false)
                return
            }
            
            #if Debug
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            print("\(#function) code: \(code)")
            #endif

            let result = self.handlerTLVFormat(data: data)
            if let value = result.v.first {
                self.stateCard = MetaState(rawValue: value) ?? .UNDEFINED
                completionHandler(true)
            } else {
                completionHandler(false)
            }

        }
        
    }
    
    private func getIssuerCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool) -> Void)) {
        
        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_GET_CARD_ISSUER.rawValue, p1Parameter: 0, p2Parameter: 0, data: Data(), expectedResponseLength: 64)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            if let error = error {
                session.invalidate(errorMessage: "Some error occurred. Please try again. \(error.localizedDescription)")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false)
                return
            }
            
            let result = self.handlerTLVFormat(data: data)
            if result.v.count > 1 {
                self.issuer = String(result.v[1])
            }
            
            let code = String(format:"%02X", p1)+String(format:"%02X", p2)
            completionHandler(code == "9000")
        }
    }
    
    private func getPublicKeyCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool) -> Void)) {
        
        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_GET_PUBLIC_KEY.rawValue, p1Parameter: 0, p2Parameter: 0, data: Data(), expectedResponseLength: 64)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            if let error = error {
                session.invalidate(errorMessage: "Some error occurred. Please try again. \(error.localizedDescription)")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false)
                return
            }
            
            let result = self.handlerTLVFormat(data: data)
            let pubkey = Data(bytes: result.v, count: result.v.count).hexadecimal()
            self.publicKey = pubkey
            let code = String(format:"%02X", p1)+String(format:"%02X", p2)
            completionHandler(code == "9000")
        }
    }

    private func getPrivateKeyCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool) -> Void)) {
        
        guard let pincode = pincode else {
            completionHandler(false)
            return
        }
        
        let dataCommand = self.dataCommandPin(pincode: pincode)

        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_EXPORT_PRIVATE_KEY.rawValue, p1Parameter: 0, p2Parameter: 0, data: dataCommand, expectedResponseLength: 64)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            if let error = error {
                session.invalidate(errorMessage: "Some error occurred. Please try again. \(error.localizedDescription)")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false)
                return
            }
            
            let result = self.handlerTLVFormat(data: data)
            let pk = Data(bytes: result.v, count: result.v.count).hexadecimal()
            self.privateKey = pk
            let code = String(format:"%02X", p1)+String(format:"%02X", p2)
            completionHandler(code == "9000")
        }
    }
    
    private func disableGetPrivateKeyCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool) -> Void)) {
        
        guard let pincode = pincode else {
            completionHandler(false)
            return
        }

        let dataCommand = self.dataCommandPin(pincode: pincode)

        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_DISABLE_PRIVATE_KEY_EXPORT.rawValue, p1Parameter: 0, p2Parameter: 0, data: dataCommand, expectedResponseLength: 64)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            if let error = error {
                session.invalidate(errorMessage: "Some error occurred. Please try again. \(error.localizedDescription)")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false)
                return
            }
            
            let code = String(format:"%02X", p1)+String(format:"%02X", p2)
            completionHandler(code == "9000")
        }
    }
    
    private func getCardGUIDCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool) -> Void)) {
        
        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_GET_CARD_GUID.rawValue, p1Parameter: 0, p2Parameter: 0, data: Data(), expectedResponseLength: -1)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            if let error = error {
                session.invalidate(errorMessage: "Some error occurred. Please try again. \(error.localizedDescription)")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false)
                return
            }
            
            #if Debug
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            print("\(#function) code: \(code)")
            print("cardGUID: \(self.cardGUID)")
            #endif
            
            let result = self.handlerTLVFormat(data: data)
            self.cardGUID = self.generateGUID(bytes: result.v)
            completionHandler(true)
        }
        
    }
    
    private func activateCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool) -> Void)) {
        
        guard let pincode = pincode else {
            completionHandler(false)
            return
        }

        let dataCommand = self.dataCommandPin(pincode: pincode)

        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_ACTIVATE.rawValue, p1Parameter: 0, p2Parameter: 0, data: dataCommand, expectedResponseLength: -1)
        
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            if let error = error {
                session.invalidate(errorMessage: "Send command error. Please try again. \(error.localizedDescription)")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false)
                return
            }
            
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            
            #if Debug
            print("unlock data: \(data.hexEncodedString())")
            print("activate command result: \(code)")
            #endif
            completionHandler(code == "9000")
        }
    }
    
    private func setNewPincodeCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool) -> Void)) {
        
        guard let pincode = pincode else {
            completionHandler(false)
            return
        }
        
        guard let newPincode = newPincode else {
            completionHandler(false)
            return
        }
        
        var resultBytes = [UInt8]()
        resultBytes.append(contentsOf: self.dataCommandPin(pincode: pincode).copyBytes())
        resultBytes.append(contentsOf: self.dataCommandPin(pincode: newPincode).copyBytes())
        
        let dataCommand = Data(resultBytes)
        
        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_CHANGE_PIN.rawValue, p1Parameter: 0, p2Parameter: 0, data: dataCommand, expectedResponseLength: -1)
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            if let error = error {
                session.invalidate(errorMessage: "Set new PIN error. Please try again. \(error.localizedDescription)")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false)
                return
            }
            //print("data: \(data.hexEncodedString())")
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            #if Debug
            print("set pincode command result: \(code)")
            #endif
            completionHandler(code == "9000")
        }
        
    }
    
    private func unlockCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool) -> Void)) {
        
        guard let pincode = pincode else {
            completionHandler(false)
            return
        }
        
        let dataCommand = self.dataCommandPin(pincode: pincode)

        let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_UNLOCK.rawValue, p1Parameter: 0, p2Parameter: 0, data: dataCommand, expectedResponseLength: -1)
        iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
            if let error = error {
                self.delegate?.cardService?(self, error: error)
                session.invalidate(errorMessage: "Unlock command error. Please try again. \(error.localizedDescription)")
                self.delegate?.cardService?(self, error: error)
                completionHandler(false)
                return
            }
            
            let st1 = String(format:"%02X", p1)
            let st2 = String(format:"%02X", p2)
            let code = st1+st2
            #if Debug
            print("unlock data: \(data.hexEncodedString())")
            print("pincode command result: \(code)")
            #endif
            completionHandler(code == "9000")
        }
    }
    
    private func signCommand(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag, _ completionHandler: @escaping((Bool) -> Void)) {
        
        guard let pincode = pincode else {
            completionHandler(false)
            return
        }
        
        guard let dataArray = self.dataForSignArray else {
            session.invalidate(errorMessage: "Sign command error. Please try again.")
            completionHandler(false)
            return
        }
        
        let group = DispatchGroup()
        var signedDataArray = [String]()
        for (index, data) in dataArray.enumerated() {
            
            guard let hexadecimal = data.hexadecimal else {
                continue
            }
            
            let payloadBytes: [UInt8] = [UInt8](hexadecimal)
            
            var resultBytes = [UInt8]()
            resultBytes.append(contentsOf: self.dataCommandPin(pincode: pincode).copyBytes())
            
            resultBytes.append(Tag.DATA_FOR_SIGN)
            resultBytes.append(UInt8(payloadBytes.count))
            resultBytes.append(contentsOf: payloadBytes)
            
            let dataCommand = Data(resultBytes)
            
            let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: InstructionCode.INS_SIGN_DATA.rawValue, p1Parameter: 0, p2Parameter: 0, data: dataCommand, expectedResponseLength: -1)
            
            group.enter()
            iso7816Tag.sendCommand(apdu: apdu) { data, p1, p2, error in
                if let error = error {
                    session.invalidate(errorMessage: "Sign command error. Please try again. \(error.localizedDescription)")
                    self.delegate?.cardService?(self, error: error)
                    completionHandler(false)
                    return
                }
                
                let st1 = String(format:"%02X", p1)
                let st2 = String(format:"%02X", p2)
                let code = st1+st2
                let result = self.handlerTLVFormat(data: data)
                signedDataArray.append(Data(bytes: result.v, count: result.v.count).hexadecimal())
                
                #if Debug
                print("meta command result: \(code) of \(index+1)/\(dataArray.count)")
                #endif
                
                if code != "9000" {
                    completionHandler(false)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .global()) {
            self.delegate?.cardService?(self, signed: signedDataArray)
            completionHandler(true)
        }
        
    }
    
    //MARK: - Tools Private
    private func handlerTLVFormat(data: Data) -> (t: UInt8, l: UInt8, v: [UInt8]) {
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
    
    private func sign(session: NFCTagReaderSession, tag: NFCTag, iso7816Tag: NFCISO7816Tag) {
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        self.delegate?.cardService?(self, progress: 0.3)
        session.connect(to: tag) { (error: Error?) in
            if let error = error {
                self.delegate?.cardService?(self, progress: 1)
                self.delegate?.cardService?(self, error: error)
                session.invalidate(errorMessage: "Connection error. Please try again. \(error.localizedDescription)")
                self.delegate?.cardService?(self, error: error)
                return
            }
            if let _ = self.dataForSignArray, let _ = self.pincode {
                self.unlockCommand(session: session, iso7816Tag: iso7816Tag) { success in
                    self.delegate?.cardService?(self, progress: 0.6)
                    if !success {
                        self.delegate?.cardService?(self, progress: 1)
                        session.invalidate(errorMessage: "Sign command meta data card error")
                        return
                    }
                    
                    self.signCommand(session: session, iso7816Tag: iso7816Tag) { success in
                        self.delegate?.cardService?(self, progress: 1)
                        if !success {
                            session.invalidate(errorMessage: "Sign command meta data card error")
                            return
                        }
                        session.invalidate()
                    }
                    
                }
            } else {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Do data for sign error")
                return
                
            }
            
        }
    }

    private func pay(session: NFCTagReaderSession, tag: NFCTag, iso7816Tag: NFCISO7816Tag) {
        
        if let _ = self.dataForSignArray, let _ = self.pincode {
            self.signCommand(session: session, iso7816Tag: iso7816Tag) { success in
                self.delegate?.cardService?(self, progress: 1)
                if !success {
                    session.invalidate(errorMessage: "Sign command meta data card error")
                    return
                }
                session.invalidate()
            }

        } else {
            self.delegate?.cardService?(self, progress: 1)
            session.invalidate(errorMessage: "Do data for sign error")
            return
        }

    }

    private func getPKData(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag) {
        self.delegate?.cardService?(self, progress: 0.5)
        
        self.getPrivateKeyCommand(session: session, iso7816Tag: iso7816Tag) { success in
            self.delegate?.cardService?(self, progress: 1)
            if !success {
                session.invalidate(errorMessage: "Get private key data error")
                return
            }
            
            self.disableGetPrivateKeyCommand(session: session, iso7816Tag: iso7816Tag) { success in
                session.invalidate()
            }
            self.delegate?.cardService?(self, privateKey: self.privateKey)
        }
        
    }
  
    private func getData(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag) {
        
        let group = DispatchGroup()
        
        group.enter()
        self.getCardGUIDCommand(session: session, iso7816Tag: iso7816Tag) { success in
            self.delegate?.cardService?(self, progress: 0.5)
            if !success {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Get card guid data error")
                return
            }
            group.leave()
        }
        
        group.enter()
        self.getPublicKeyCommand(session: session, iso7816Tag: iso7816Tag) { success in
            self.delegate?.cardService?(self, progress: 0.5)
            if !success {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Get public key data error")
                return
            }
            group.leave()
        }
        
        group.enter()
        self.getIssuerCommand(session: session, iso7816Tag: iso7816Tag) { success in
            self.delegate?.cardService?(self, progress: 0.5)
            if !success {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Get issuer data error")
                return
            }
            group.leave()
        }
        
        group.notify(queue: .global()) {
            self.delegate?.cardService?(self, progress: 1)
            self.delegate?.cardService?(self, pubKey: self.publicKey, guid: self.cardGUID, issuer: self.issuer, state: self.stateCard, aid: self.aid)
            session.invalidate()
        }
        
    }
    
    private func getPublicKeyForPay(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag) {
        
        self.delegate?.cardService?(self, progress: 0.5)
        self.getPublicKeyCommand(session: session, iso7816Tag: iso7816Tag) { success in
            if !success {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Get public key data error")
                return
            }
            self.delegate?.cardService?(self, progress: 1)
            self.delegate?.cardService?(self, pubKey: self.publicKey, guid: self.cardGUID, issuer: self.issuer, state: self.stateCard, aid: self.aid)
        }
    }
    
    private func getDataSlice(session: NFCTagReaderSession, iso7816Tag: NFCISO7816Tag) {
        
        let group = DispatchGroup()
        
        group.enter()
        self.getCardGUIDCommand(session: session, iso7816Tag: iso7816Tag) { success in
            self.delegate?.cardService?(self, progress: 0.5)
            if !success {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Get card guid data error")
                return
            }
            group.leave()
        }
        
        group.enter()
        self.getIssuerCommand(session: session, iso7816Tag: iso7816Tag) { success in
            self.delegate?.cardService?(self, progress: 0.5)
            if !success {
                self.delegate?.cardService?(self, progress: 1)
                session.invalidate(errorMessage: "Get issuer data error")
                return
            }
            group.leave()
        }
        
        group.notify(queue: .global()) {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
                self.delegate?.cardService?(self, progress: 1)
                self.delegate?.cardService?(self, state: self.stateCard, guid: self.cardGUID, issuer: self.issuer, aid: self.aid)
            }
            session.invalidate()
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
            self.sign(session: session, tag: tag, iso7816Tag: iso7816Tag)
            return
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        session.connect(to: tag) { (error: Error?) in
            if let error = error {
                self.delegate?.cardService?(self, progress: 1)
                self.delegate?.cardService?(self, error: error)
                session.invalidate(errorMessage: "Connection error. Please try again. \(error.localizedDescription)")
                print("Connection error. Please try again. \(error.localizedDescription)")
                return
            }
            self.getStateCommand(session: session, iso7816Tag: iso7816Tag) { success in
                if !success {
                    self.delegate?.cardService?(self, progress: 1)
                    session.invalidate(errorMessage: "Fetch get state data card error")
                    return
                }
                if self.stateCard == .UNDEFINED {
                    self.delegate?.cardService?(self, progress: 1)
                    self.delegate?.cardService?(self, state: self.stateCard, guid: self.cardGUID, issuer: self.issuer, aid: self.aid)
                    session.invalidate(errorMessage: "State card undefined")
                    return
                } else if self.stateCard == .ACTIVATED_LOCKED {
                    if let _ = self.pincode {
                        self.unlockCommand(session: session, iso7816Tag: iso7816Tag) { success in
                            if !success {
                                self.delegate?.cardService?(self, progress: 1)
                                session.invalidate(errorMessage: "Invalid PIN. You only have 3 attempts")
                                return
                            }
                            self.delegate?.cardService?(self, progress: 0.3)
                            if self.command == .setNewPin {
                                self.setNewPincodeCommand(session: session, iso7816Tag: iso7816Tag) { success in
                                  self.delegate?.cardService?(self, progress: 1)
                                  if !success {
                                        session.invalidate(errorMessage: "Set new PIN error")
                                        return
                                    }
                                    session.alertMessage = "Pin changed successfully"
                                    session.invalidate()
                                }
                            } else if self.command == .getPrivateKey {
                                self.getPKData(session: session, iso7816Tag: iso7816Tag)
                            } else if self.command == .pay {
                                self.getPublicKeyForPay(session: session, iso7816Tag: iso7816Tag)
                            } else {
                                self.getData(session: session, iso7816Tag: iso7816Tag)
                            }
                        }
                    } else {
                        self.getDataSlice(session: session, iso7816Tag: iso7816Tag)
                    }
                } else if self.stateCard == .INITED {
                    if let _ = self.pincode {
                        
                        self.activateCommand(session: session, iso7816Tag: iso7816Tag) { success in
                            if !success {
                                self.delegate?.cardService?(self, progress: 1)
                                session.invalidate(errorMessage: "Activate card error")
                                return
                            }
                            self.unlockCommand(session: session, iso7816Tag: iso7816Tag) { success in
                                if !success {
                                    self.delegate?.cardService?(self, progress: 1)
                                    session.invalidate(errorMessage: "Invalid PIN. You only have 3 attempts")
                                    return
                                }
                                self.getData(session: session, iso7816Tag: iso7816Tag)
                            }
                            
                        }
                    } else {
                        self.delegate?.cardService?(self, progress: 1)
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
                            self.delegate?.cardService?(self, state: self.stateCard, guid: self.cardGUID, issuer: self.issuer, aid: self.aid)
                        }
                        session.invalidate()
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

    public func sign(_ dataForSignArray: [String]) {
        self.dataForSignArray = dataForSignArray
        guard let session = session else {return}
        guard let iso7816Tag = iso7816Tag else {return}
        guard let tag = tag else {return}
        self.sign(session: session, tag: tag, iso7816Tag: iso7816Tag)
        
    }

    public func pay(_ dataForSignArray: [String]) {
        self.dataForSignArray = dataForSignArray
        guard let session = session else {return}
        guard let iso7816Tag = iso7816Tag else {return}
        guard let tag = tag else {return}
        self.pay(session: session, tag: tag, iso7816Tag: iso7816Tag)
    }

    public func invalidate(_ text: String) {
        self.session?.invalidate(errorMessage: text)
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
                if self.aid == .terminal {
                    self.getInvoiceCommand(session: session, iso7816Tag: iso7816Tag) { success in
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
