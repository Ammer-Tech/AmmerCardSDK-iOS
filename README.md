# AmmerCardSDK

The AmmerCardSDK enables your iOS application to use a Ammer smart-card as a cryptographic interface which is used
to:
1. Generate a Secp256k1 Keypair
2. Set/Modify the PIN code used to trigger cryptographic operations (set at key generation time, used to invoke signature function)
3. Extract the public key to generate an address for a blockchain which leverage Secp256k1 keys (e.g. Bitcoin, Ethereum)
4. Perform a NONE_WITH_ECDSA signature scheme on a 64-byte payload

## Install

### Using SPM package-manager

```
.package(name: "AmmerSmartCards", url: "https://github.com/Ammer-Tech/AmmerSmartCards", .branchItem("master")),
```

## General Usage

### Info.plist definitions

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

### AmmerCardSDK Card State Machine

NOT_INITED - card has no public-keu

| State       | Description |Eligible next states |
| ----------- | ----------- |----------- |
| NOT_INITED      | The card has no keypair and PIN       | INITED       |
| INITED   | The card has a keypair and PIN set  |ACTIVATED_LOCKED        |
| ACTIVATED_LOCKED   | The card requires a PIN code to use the sign function  |ACTIVATED_UNLOCKED        |

The state could also be ``UNDEFINED`` under certain unique circumstances. This can be either a hardware malfunction or a problem with the NFC connection to the host device.


### Examples

##### Get the card state

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

##### Activate a new card and set PIN code

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

##### Extract public key and metadata

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

##### Sign a 64-byte string using ECDSA

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

##### Modify card PIN code

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

##### Extract private key

:warning: You can only extract the private key once for offline backup such as a paper wallet, a USB stick, or optical media which is never read on a device which is or will be connected to the internet :warning:

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
