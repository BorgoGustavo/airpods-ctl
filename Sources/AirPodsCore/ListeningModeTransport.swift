import Foundation

/// Abstraction over whatever macOS mechanism reads and writes the AirPods
/// listening mode. `readListeningMode(of:)` returns `nil` when the current
/// mode cannot be determined — callers must treat that as "unknown", not as
/// an error (the IOBluetooth private getter only has a value in processes
/// that have set a mode themselves).
public protocol ListeningModeTransport {
    func connectedAirPods() throws -> [AirPodsDevice]
    func readListeningMode(of device: AirPodsDevice) throws -> ListeningMode?
    func setListeningMode(_ mode: ListeningMode, on device: AirPodsDevice) throws
}

public enum TransportError: Error, Equatable {
    case airPodsNotConnected
    case permissionDenied
    case bluetoothUnavailable
    /// The private IOBluetooth selector this build relies on is gone —
    /// typically after a macOS update. The selector name is included so the
    /// failure points at exactly what Apple changed.
    case privateAPIUnavailable(selector: String)
}
