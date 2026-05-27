import Foundation

public final class CoreBluetoothTransport: BluetoothTransport {
    public init() {}

    public func send(_: Data) async throws {
        throw TransportError.notImplemented
    }

    public func receive() -> AsyncStream<Data> {
        AsyncStream { _ in }
    }

    public func close() async {}
}
