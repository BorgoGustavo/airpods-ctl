import Foundation

public final class IOBluetoothTransport: BluetoothTransport, @unchecked Sendable {
    public init() {}

    public func discoverConnectedAirPods() async throws -> [AirPodsDevice] {
        throw TransportError.notImplemented
    }

    public func send(_: Data) async throws {
        throw TransportError.notImplemented
    }

    public func receive() -> AsyncStream<Data> {
        AsyncStream { _ in }
    }

    public func close() async {}
}
