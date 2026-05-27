import CoreBluetooth
import Foundation

public final class CoreBluetoothTransport: BluetoothTransport, @unchecked Sendable {
    /// `retrieveConnectedPeripherals(withServices:)` rejects an empty array.
    /// Empirically on macOS Tahoe 26, AirPods Pro 2 connected over Classic
    /// Bluetooth expose only **Device Information (0x180A)** to the Core
    /// Bluetooth side — neither Generic Access (0x1800) nor Battery (0x180F)
    /// match. (`airpods-ctl list --verbose` was used to confirm this.) Other
    /// peripherals that also expose 0x180A still come back in the raw result,
    /// so we narrow further by name in `discoverConnectedAirPods()`. The actual
    /// AAP control channel (L2CAP PSM 0x1001) is opened separately in Phase 2.
    public static let knownAirPodsServiceUUIDs: [CBUUID] = [
        CBUUID(string: "180A"),
    ]

    private let queue: DispatchQueue
    private let coordinator: BluetoothCoordinator
    private let manager: CBCentralManager

    public init() {
        queue = DispatchQueue(label: "dev.borgo.airpods-ctl.bt", qos: .userInitiated)
        coordinator = BluetoothCoordinator()
        manager = CBCentralManager(delegate: coordinator, queue: queue)
    }

    public func discoverConnectedAirPods() async throws -> [AirPodsDevice] {
        try await waitForPoweredOn()
        let peripherals = await runOnQueue {
            self.manager.retrieveConnectedPeripherals(withServices: Self.knownAirPodsServiceUUIDs)
        }
        return peripherals
            .filter { ($0.name ?? "").localizedCaseInsensitiveContains("airpods") }
            .map { AirPodsDevice(id: $0.identifier, name: $0.name ?? "AirPods") }
    }

    /// Diagnostic helper: queries `retrieveConnectedPeripherals` with several
    /// candidate service-UUID sets and returns the raw lists each one yields.
    /// Used by `airpods-ctl list --verbose` to figure out which GATT services
    /// (if any) AirPods Pro 2 expose on the running macOS version. Throws if
    /// Bluetooth never reaches `.poweredOn`.
    public func probeServiceUUIDs() async throws -> [(label: String, peripherals: [(id: UUID, name: String)])] {
        try await waitForPoweredOn()
        let candidates: [(String, [CBUUID])] = [
            ("Generic Access (1800) + Battery (180F)", [CBUUID(string: "1800"), CBUUID(string: "180F")]),
            ("Generic Access (1800)", [CBUUID(string: "1800")]),
            ("Battery (180F)", [CBUUID(string: "180F")]),
            ("Apple Continuity (9FA480E0-...)", [CBUUID(string: "9FA480E0-4967-4542-9390-D343DC5D04AE")]),
            ("Apple Nearby Info (D0611E78-...)", [CBUUID(string: "D0611E78-BBB4-4591-A5F8-487910AE4366")]),
            ("Device Info (180A)", [CBUUID(string: "180A")]),
        ]
        var results: [(String, [(UUID, String)])] = []
        for (label, uuids) in candidates {
            let peripherals = await runOnQueue {
                self.manager.retrieveConnectedPeripherals(withServices: uuids)
            }
            results.append((label, peripherals.map { ($0.identifier, $0.name ?? "<unnamed>") }))
        }
        return results
    }

    public func send(_: Data) async throws {
        throw TransportError.notImplemented
    }

    public func receive() -> AsyncStream<Data> {
        AsyncStream { _ in }
    }

    public func close() async {
        coordinator.finish()
    }

    // MARK: - Internals

    private func waitForPoweredOn() async throws {
        let immediate = await runOnQueue { self.manager.state }
        if try resolveState(immediate) { return }
        for await state in coordinator.stateUpdates {
            if try resolveState(state) { return }
        }
        throw TransportError.channelClosed
    }

    /// Returns true when the state means we can proceed (`poweredOn`), throws
    /// for terminal states, returns false for transient ones we keep waiting on.
    private func resolveState(_ state: CBManagerState) throws -> Bool {
        switch state {
        case .poweredOn:
            return true
        case .unauthorized:
            throw TransportError.permissionDenied
        case .unsupported, .poweredOff:
            throw TransportError.bluetoothUnavailable
        case .unknown, .resetting:
            return false
        @unknown default:
            return false
        }
    }

    private func runOnQueue<T>(_ block: @escaping () -> T) async -> T {
        await withCheckedContinuation { cont in
            queue.async {
                cont.resume(returning: block())
            }
        }
    }
}
