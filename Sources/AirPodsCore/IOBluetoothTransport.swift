import Foundation
import IOBluetooth

/// Drives noise modes through the private `listeningMode` / `setListeningMode:`
/// selectors on `IOBluetoothDevice`. The call crosses XPC into `bluetoothd`,
/// which owns the only AAP channel the AirPods will accept: opening our own
/// L2CAP channel on the AAP PSM (0x1001) is refused while bluetoothd's session
/// exists (verified 2026-06-09, `kIOReturnError` after a ~3 s signaling
/// timeout). Delegating to bluetoothd is the only working userland path on
/// Tahoe — see `docs/aap-protocol-notes.md`.
///
/// Both selectors return/accept primitive `Int`s, so they are called through
/// typed IMPs — `perform(_:)` would box the result incorrectly.
public struct IOBluetoothTransport: ListeningModeTransport {
    private enum Selectors {
        static let listeningMode = "listeningMode"
        static let setListeningMode = "setListeningMode:"
        static let isANCSupported = "isANCSupported"
    }

    public init() {}

    public func connectedAirPods() throws -> [AirPodsDevice] {
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        return paired
            .filter { $0.isConnected() && supportsListeningModes($0) }
            .compactMap { device in
                guard let address = device.addressString else { return nil }
                return AirPodsDevice(id: address, name: device.name ?? "AirPods")
            }
    }

    public func readListeningMode(of device: AirPodsDevice) throws -> ListeningMode? {
        let ioDevice = try ioDevice(for: device)
        guard let raw = callIntGetter(ioDevice, Selectors.listeningMode) else {
            return nil
        }
        return ListeningMode(deviceValue: raw)
    }

    public func setListeningMode(_ mode: ListeningMode, on device: AirPodsDevice) throws {
        let ioDevice = try ioDevice(for: device)
        try callIntSetter(ioDevice, Selectors.setListeningMode, value: mode.deviceValue)
    }

    // MARK: - Internals

    /// `isANCSupported` is the capability we actually need and survives device
    /// renames; the name check is the fallback if Apple drops the selector.
    private func supportsListeningModes(_ device: IOBluetoothDevice) -> Bool {
        callBoolGetter(device, Selectors.isANCSupported)
            ?? (device.name ?? "").localizedCaseInsensitiveContains("airpods")
    }

    private func ioDevice(for device: AirPodsDevice) throws -> IOBluetoothDevice {
        guard let ioDevice = IOBluetoothDevice(addressString: device.id), ioDevice.isConnected() else {
            throw TransportError.airPodsNotConnected
        }
        return ioDevice
    }

    private func callIntGetter(_ object: AnyObject, _ selectorName: String) -> Int? {
        let selector = NSSelectorFromString(selectorName)
        guard object.responds(to: selector) else { return nil }
        typealias Getter = @convention(c) (AnyObject, Selector) -> Int
        let imp = class_getMethodImplementation(type(of: object), selector)!
        return unsafeBitCast(imp, to: Getter.self)(object, selector)
    }

    private func callBoolGetter(_ object: AnyObject, _ selectorName: String) -> Bool? {
        let selector = NSSelectorFromString(selectorName)
        guard object.responds(to: selector) else { return nil }
        typealias Getter = @convention(c) (AnyObject, Selector) -> Bool
        let imp = class_getMethodImplementation(type(of: object), selector)!
        return unsafeBitCast(imp, to: Getter.self)(object, selector)
    }

    private func callIntSetter(_ object: AnyObject, _ selectorName: String, value: Int) throws {
        let selector = NSSelectorFromString(selectorName)
        guard object.responds(to: selector) else {
            throw TransportError.privateAPIUnavailable(selector: selectorName)
        }
        typealias Setter = @convention(c) (AnyObject, Selector, Int) -> Void
        let imp = class_getMethodImplementation(type(of: object), selector)!
        unsafeBitCast(imp, to: Setter.self)(object, selector, value)
    }
}
