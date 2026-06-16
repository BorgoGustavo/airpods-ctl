import Foundation

public enum ListeningMode: String, CaseIterable, Sendable {
    case off
    case anc
    case transparency
    case adaptive

    /// Value used by `bluetoothd` for the listening-mode device property,
    /// reachable through the private `IOBluetoothDevice` selectors
    /// `listeningMode` / `setListeningMode:`. Identical to the AAP mode byte
    /// captured from live traffic (`docs/captures/mode-transitions-2026-05-28.pklg`),
    /// so the mapping survives a future transport change.
    public var deviceValue: Int {
        switch self {
        case .off: 1
        case .anc: 2
        case .transparency: 3
        case .adaptive: 4
        }
    }

    public init?(deviceValue: Int) {
        switch deviceValue {
        case 1: self = .off
        case 2: self = .anc
        case 3: self = .transparency
        case 4: self = .adaptive
        default: return nil
        }
    }
}
