import Foundation

public struct AirPodsController {
    let transport: any ListeningModeTransport
    let store: (any ListeningModeStore)?

    public init(transport: any ListeningModeTransport, store: (any ListeningModeStore)? = nil) {
        self.transport = transport
        self.store = store
    }

    public func listDevices() throws -> [AirPodsDevice] {
        try transport.connectedAirPods()
    }

    /// Live reading when the transport has one, otherwise the last mode this
    /// tool set (when a store is configured), otherwise `nil`.
    public func currentMode() throws -> ListeningMode? {
        try effectiveMode(of: firstAirPods())
    }

    public func setMode(_ mode: ListeningMode) throws {
        let device = try firstAirPods()
        try transport.setListeningMode(mode, on: device)
        store?.recordMode(mode, for: device.id)
    }

    /// ANC ↔ Transparency. Any other state — including "unknown", when
    /// neither the transport nor the store knows — lands on ANC.
    @discardableResult
    public func toggle() throws -> ListeningMode {
        let device = try firstAirPods()
        let target: ListeningMode = switch try effectiveMode(of: device) {
        case .anc: .transparency
        default: .anc
        }
        try transport.setListeningMode(target, on: device)
        store?.recordMode(target, for: device.id)
        return target
    }

    private func effectiveMode(of device: AirPodsDevice) throws -> ListeningMode? {
        if let live = try transport.readListeningMode(of: device) {
            return live
        }
        return store?.lastSetMode(for: device.id)
    }

    private func firstAirPods() throws -> AirPodsDevice {
        guard let device = try transport.connectedAirPods().first else {
            throw TransportError.airPodsNotConnected
        }
        return device
    }
}
