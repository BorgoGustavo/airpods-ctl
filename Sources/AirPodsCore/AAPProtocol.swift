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
    /// Empirically observed L2CAP CIDs on the AirPods Pro 2 connection (macOS
    /// Tahoe 26.4.1 + AirPods firmware 8B39, captured 2026-05-28 — see
    /// docs/captures/mode-transitions-2026-05-28.pklg).
    ///
    /// AAP does **not** use a fixed PSM. The system's `bluetoothd` opens an
    /// L2CAP connection during pairing and dispatches AAP traffic across
    /// several dynamic CIDs. The interesting ones for the toggle MVP are
    /// commandSend (host → AirPods) and statusReceive (AirPods → host).
    public enum L2CAPChannels {
        /// Host → AirPods commands and host-side heartbeats.
        public static let commandSend: UInt16 = 0x060A
        /// AirPods → host status notifications and command echoes (acks).
        public static let statusReceive: UInt16 = 0x2A0D
        /// AirPods → host short notifications, suspected touch events.
        public static let notifications: UInt16 = 0x080C
        /// AirPods → host telemetry stream with IEEE-754 little-endian floats,
        /// suspected spatial-audio orientation data.
        public static let telemetry: UInt16 = 0x2C0F
    }

    public static let header: [UInt8] = [0x04, 0x00, 0x04, 0x00]
    public static let setListeningModeOpcode: [UInt8] = [0x09, 0x00, 0x0D]
}
