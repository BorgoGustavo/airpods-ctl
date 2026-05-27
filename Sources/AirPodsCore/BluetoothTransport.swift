import Foundation

public protocol BluetoothTransport: AnyObject {
    func discoverConnectedAirPods() async throws -> [AirPodsDevice]
    func send(_ data: Data) async throws
    func receive() -> AsyncStream<Data>
    func close() async
}

public enum TransportError: Error, Equatable {
    case notImplemented
    case airPodsNotConnected
    case channelClosed
    case permissionDenied
    case bluetoothUnavailable
    case timeout
}
