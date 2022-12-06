# AmmerSmartCards

Ammer Smart Cards. Use it to activate and get public key from phisical card.

## Install
### SPM

```
.package(name: "AmmerSmartCards", url: "https://github.com/Ammer-Tech/AmmerSmartCards", .branchItem("master")),
```

## General Usage

### Info.plist.

```
<key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
<array>
  <string>706f727465425443</string>
  <string>63989600FF0001</string>
  <string>A0000008820001</string>
</array>
```

```
<key>NFCReaderUsageDescription</key>
<string>
  <string>Use NFC to read data</string>
</string>
```

### Get state card.

States
- NOT_INITED - The card was not inited
- INITED - The card was inited
- ACTIVATED_LOCKED - The card was inited and now locked for any operations with public/private key
- ACTIVATED_UNLOCKED - The card was inited and right now unlocked for any operations with public/private key
- UNDEFINED - Sate no undefined

Example
```swift
import AmmerSmartCards

class MyClass: UIViewController, CardNFCServiceDelegate {
    
    private var cardNFCService: CardNFCService?

    override func viewDidLoad() {
        super.viewDidLoad()                
        self.cardNFCService = CardNFCService(delegate: self)
        self.cardNFCService?.begin()
    }

    //MARK: - CardNFCServiceDelegate
    public func cardService(_ cardService: CardNFCService, error: Error) {
        print("error: \(error.localizedDescription)")
    }

    public func cardService(_ cardService: CardNFCService, state: MetaState, guid: String, issuer: String) {
        print("state: \(state.rawValue)")
    }
}
```

### Init a new card and set PIN for it.

Example
```swift
import AmmerSmartCards

class MyClass: UIViewController, CardNFCServiceDelegate {
    
    private var cardNFCService: CardNFCService?

    override func viewDidLoad() {
        super.viewDidLoad()                
        self.cardNFCService = CardNFCService(delegate: self)
        self.cardNFCService?.begin()
    }

    //MARK: - CardNFCServiceDelegate
    public func cardService(_ cardService: CardNFCService, error: Error) {
        print("error: \(error.localizedDescription)")
    }

    public func cardService(_ cardService: CardNFCService, state: MetaState, guid: String, issuer: String, aid: AIDVersion) {
        print("state: \(state.rawValue)")
        let newPin = "123456"
        if state == .INITED {
            self.cardNFCService?.setPin(newPin)
            self.cardNFCService?.begin()
        }
    }

    public func cardService(_ cardService: CardNFCService, pubKey: String, guid: String, issuer: String) {
        print("pubKey: \(pubKey), guid: \(guid), issuer: \(issuer)")
    }
}
```

### Get public key, guid and issuer card.

Example
```swift
import AmmerSmartCards

class MyClass: UIViewController, CardNFCServiceDelegate {
    
    private var cardNFCService: CardNFCService?

    override func viewDidLoad() {
        super.viewDidLoad()                
        self.cardNFCService = CardNFCService(delegate: self)
        self.cardNFCService?.begin()
    }

    //MARK: - CardNFCServiceDelegate
    public func cardService(_ cardService: CardNFCService, error: Error) {
        print("error: \(error.localizedDescription)")
    }

    public func cardService(_ cardService: CardNFCService, state: MetaState, guid: String, issuer: String) {
        print("state: \(state.rawValue)")
        let pin = "123456"
        if state == .ACTIVATED_LOCKED {
            self.cardNFCService?.setPin(pin)
            self.cardNFCService?.begin()
        }
    }

    public func cardService(_ cardService: CardNFCService, pubKey: String, guid: String, issuer: String) {
        print("pubKey: \(pubKey), guid: \(guid), issuer: \(issuer)")
    }
}
```

### Sign data.

Example
```swift
import AmmerSmartCards

class MyClass: UIViewController, CardNFCServiceDelegate {
    
    private var cardNFCService: CardNFCService?

    override func viewDidLoad() {
        super.viewDidLoad()                
        
        let pin = "123456"
        let dataForSign: [String] = ["404bb9388061d1002a93ed62d24ba7f1e1e4863f467dc180f1b1b4b872453908"]
        self.cardNFCService = CardNFCService(delegate: self, 
                                            command: .sign, 
                                            pincode: pin, 
                                            dataForSignArray: dataForSign)
        self.cardNFCService?.begin()
    }

    //MARK: - CardNFCServiceDelegate
    public func cardService(_ cardService: CardNFCService, error: Error) {
        print("error: \(error.localizedDescription)")
    }
    
    public func cardService(_ cardService: CardNFCService, signed data: [String]) {
        print("signed data: \(data)")
    }
}
```

### Change card PIN.

Example
```swift
import AmmerSmartCards

class MyClass: UIViewController, CardNFCServiceDelegate {
    
    private var cardNFCService: CardNFCService?

    override func viewDidLoad() {
        super.viewDidLoad()                
        
        let pin = "123456"
        let newPin = "654321"
        self.cardNFCService = CardNFCService(delegate: self, 
                                             command: .setNewPin, 
                                             pincode: pin, 
                                             newPincode: newPin)
        self.cardNFCService?.begin()
    }

    //MARK: - CardNFCServiceDelegate
    public func cardService(_ cardService: CardNFCService, error: Error) {
        print("error: \(error.localizedDescription)")
    }
}
```

### Extract private key.
important note: Extraction of the private key is available only once!

Example
```swift
import AmmerSmartCards

class MyClass: UIViewController, CardNFCServiceDelegate {
    
    private var cardNFCService: CardNFCService?

    override func viewDidLoad() {
        super.viewDidLoad()                
        
        let pin = "123456"
        self.cardNFCService = CardNFCService(delegate: self, 
                                             command: .getPrivateKey, 
                                             pincode: pin)
        self.cardNFCService?.begin()
    }

    //MARK: - CardNFCServiceDelegate
    func cardService(_ cardService: CardNFCService, privateKey: String) {
        print("privateKy: \(privateKey)")
    }
}
```
