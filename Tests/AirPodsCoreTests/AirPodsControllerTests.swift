@testable import AirPodsCore
import Foundation
import Testing

@Suite("AirPodsController")
struct AirPodsControllerTests {
    @Test("listDevices delegates to the transport and returns its result")
    func listDevicesDelegates() async throws {
        let devices = [
            AirPodsDevice(id: UUID(), name: "AirPods Pro de Gustavo"),
            AirPodsDevice(id: UUID(), name: "AirPods Pro 2"),
        ]
        let transport = MockTransport(discoveryResult: devices)
        let controller = AirPodsController(transport: transport)

        let result = try await controller.listDevices()

        #expect(result == devices)
    }

    @Test("listDevices propagates transport errors")
    func listDevicesPropagatesErrors() async {
        let transport = MockTransport(discoveryError: TransportError.permissionDenied)
        let controller = AirPodsController(transport: transport)

        do {
            _ = try await controller.listDevices()
            Issue.record("Expected listDevices to throw")
        } catch let error as TransportError {
            #expect(error == .permissionDenied)
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test("setMode encodes the documented packet and forwards it to send")
    func setModeForwardsEncodedPacket() async throws {
        let transport = MockTransport()
        let controller = AirPodsController(transport: transport)

        try await controller.setMode(.transparency)

        let sent = transport.sentData
        #expect(sent.count == 1)
        let expected: [UInt8] = [0x04, 0x00, 0x04, 0x00, 0x09, 0x00, 0x0D, 0x03, 0x00, 0x00, 0x00]
        #expect([UInt8](sent[0]) == expected)
    }

    @Test("close forwards to the transport")
    func closeForwards() async {
        let transport = MockTransport()
        let controller = AirPodsController(transport: transport)

        await controller.close()

        #expect(transport.closeCallCount == 1)
    }
}

final class MockTransport: BluetoothTransport, @unchecked Sendable {
    let discoveryResult: [AirPodsDevice]
    let discoveryError: Error?
    private(set) var sentData: [Data] = []
    private(set) var closeCallCount = 0

    init(discoveryResult: [AirPodsDevice] = [], discoveryError: Error? = nil) {
        self.discoveryResult = discoveryResult
        self.discoveryError = discoveryError
    }

    func discoverConnectedAirPods() async throws -> [AirPodsDevice] {
        if let error = discoveryError { throw error }
        return discoveryResult
    }

    func send(_ data: Data) async throws {
        sentData.append(data)
    }

    func receive() -> AsyncStream<Data> {
        AsyncStream { _ in }
    }

    func close() async {
        closeCallCount += 1
    }
}
