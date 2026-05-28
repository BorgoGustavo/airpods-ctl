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
    /// L2CAP **CIDs** (Channel IDs) observed during a single `bluetoothd ↔
    /// AirPods` session on 2026-05-28 — see
    /// `docs/captures/mode-transitions-2026-05-28.pklg`.
    ///
    /// These are **session-specific** values negotiated when `bluetoothd`
    /// opened its L2CAP channels. They are **not** part of the AAP protocol
    /// and will be different on every reconnection. They have **no value for
    /// opening a new L2CAP channel** — that needs a PSM, which is the well-
    /// known "port" the AirPods firmware listens on. The PSM is still TBD
    /// (Phase 2 reconnect capture).
    ///
    /// This enum is kept only as a parsing aid for the reference capture: if
    /// you replay that `.pklg`, these are the CIDs that carry the four
    /// observed AAP streams.
    public enum ObservedSessionCIDs {
        /// Bluetoothd → AirPods commands and ~500 ms host heartbeats.
        public static let bluetoothdCommandSend: UInt16 = 0x060A
        /// AirPods → bluetoothd status notifications and command echoes.
        public static let bluetoothdStatusReceive: UInt16 = 0x2A0D
        /// AirPods → bluetoothd short notifications, suspected touch / stem.
        public static let bluetoothdNotifications: UInt16 = 0x080C
        /// AirPods → bluetoothd telemetry, IEEE-754 LE floats (spatial audio?).
        public static let bluetoothdTelemetry: UInt16 = 0x2C0F
    }

    public static let header: [UInt8] = [0x04, 0x00, 0x04, 0x00]
    public static let setListeningModeOpcode: [UInt8] = [0x09, 0x00, 0x0D]
}
