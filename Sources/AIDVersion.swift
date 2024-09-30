import Foundation

@objc public enum AIDVersion: Int, RawRepresentable {
    case v1
    case v2
    case v3
    case v4
    case v5
    case v6
    case terminal
    case undefined
    public typealias RawValue = String
    
    public var rawValue: RawValue {
        switch self {
        case .v1:
            return "706F727465425443"
        case .v2:
            return "63989600FF0001"
        case .v3:
            return "A0000008820001"
        case .v4:
            return "A000000882ED01"
        case .v5:
            return "A0000008820002"
        case .v6:
            return "A0000008820003"
        case .terminal:
            return "77777777777777"
        case .undefined:
            return ""
        }
    }
    
    public init?(rawValue: RawValue) {
        switch rawValue {
        case "706F727465425443":
            self = .v1
        case "63989600FF0001":
            self = .v2
        case "A0000008820001":
            self = .v3
        case "A000000882ED01":
            self = .v4
        case "A0000008820002":
            self = .v5
        case "A0000008820003":
            self = .v6
        case "77777777777777":
            self = .terminal
        case "":
            self = .undefined
        default:
            return nil
        }
    }
}
