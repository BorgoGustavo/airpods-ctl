import Foundation

public protocol BluetoothTransport: AnyObject {
    func send(_ data: Data) async throws
    func receive() -> AsyncStream<Data>
    func close() async
}

public enum TransportError: Error {
    case notImplemented
    case airPodsNotConnected
    case channelClosed
    case permissionDenied
}
