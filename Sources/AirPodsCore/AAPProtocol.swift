import Foundation

public enum ListeningMode: String, CaseIterable, Sendable {
    case off
    case anc
    case transparency
    case adaptive

    public var rawByte: UInt8 {
        switch self {
        case .off: 0x01
        case .anc: 0x02
        case .transparency: 0x03
        case .adaptive: 0x04
        }
    }

    public init?(rawByte: UInt8) {
        switch rawByte {
        case 0x01: self = .off
        case 0x02: self = .anc
        case 0x03: self = .transparency
        case 0x04: self = .adaptive
        default: return nil
        }
    }
}

public enum AAPProtocolConstants {
    public static let l2capPSM: UInt16 = 0x1001
    public static let header: [UInt8] = [0x04, 0x00, 0x04, 0x00]
    public static let setListeningModeOpcode: [UInt8] = [0x09, 0x00, 0x0D]
}
