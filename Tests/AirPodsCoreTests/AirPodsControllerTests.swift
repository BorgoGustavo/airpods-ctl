@testable import AirPodsCore
import Testing

@Suite("AirPodsController")
struct AirPodsControllerTests {
    let airpods = AirPodsDevice(id: "aa-bb-cc-dd-ee-ff", name: "AirPods Pro")
    let otherAirpods = AirPodsDevice(id: "11-22-33-44-55-66", name: "AirPods Max")

    // MARK: - listDevices

    @Test("listDevices delegates to the transport and returns its result")
    func listDevicesDelegates() throws {
        let transport = FakeTransport(devices: [airpods, otherAirpods])
        let controller = AirPodsController(transport: transport)

        let result = try controller.listDevices()

        #expect(result == [airpods, otherAirpods])
    }

    @Test("listDevices propagates transport errors")
    func listDevicesPropagatesErrors() {
        let transport = FakeTransport(discoveryError: .permissionDenied)
        let controller = AirPodsController(transport: transport)

        #expect(throws: TransportError.permissionDenied) {
            try controller.listDevices()
        }
    }

    // MARK: - setMode

    @Test("setMode targets the first connected AirPods")
    func setModeTargetsFirstDevice() throws {
        let transport = FakeTransport(devices: [airpods, otherAirpods])
        let controller = AirPodsController(transport: transport)

        try controller.setMode(.transparency)

        #expect(transport.setCalls.count == 1)
        #expect(transport.setCalls[0].mode == .transparency)
        #expect(transport.setCalls[0].device == airpods)
    }

    @Test("setMode throws airPodsNotConnected when nothing is connected")
    func setModeThrowsWhenDisconnected() {
        let transport = FakeTransport(devices: [])
        let controller = AirPodsController(transport: transport)

        #expect(throws: TransportError.airPodsNotConnected) {
            try controller.setMode(.anc)
        }
        #expect(transport.setCalls.isEmpty)
    }

    // MARK: - currentMode

    @Test("currentMode reads the first connected AirPods")
    func currentModeReadsFirstDevice() throws {
        let transport = FakeTransport(devices: [airpods])
        transport.modeByDevice[airpods.id] = .adaptive
        let controller = AirPodsController(transport: transport)

        #expect(try controller.currentMode() == .adaptive)
    }

    @Test("currentMode is nil when the transport cannot read the mode")
    func currentModeNilWhenUnknown() throws {
        let transport = FakeTransport(devices: [airpods])
        let controller = AirPodsController(transport: transport)

        #expect(try controller.currentMode() == nil)
    }

    @Test("currentMode throws airPodsNotConnected when nothing is connected")
    func currentModeThrowsWhenDisconnected() {
        let transport = FakeTransport(devices: [])
        let controller = AirPodsController(transport: transport)

        #expect(throws: TransportError.airPodsNotConnected) {
            try controller.currentMode()
        }
    }

    // MARK: - toggle

    @Test("toggle switches ANC to Transparency")
    func toggleFromANC() throws {
        let transport = FakeTransport(devices: [airpods])
        transport.modeByDevice[airpods.id] = .anc
        let controller = AirPodsController(transport: transport)

        let result = try controller.toggle()

        #expect(result == .transparency)
        #expect(transport.setCalls.map(\.mode) == [.transparency])
    }

    @Test("toggle switches Transparency to ANC")
    func toggleFromTransparency() throws {
        let transport = FakeTransport(devices: [airpods])
        transport.modeByDevice[airpods.id] = .transparency
        let controller = AirPodsController(transport: transport)

        let result = try controller.toggle()

        #expect(result == .anc)
        #expect(transport.setCalls.map(\.mode) == [.anc])
    }

    @Test(
        "toggle defaults to ANC when the mode is unknown or neither ANC/Transparency",
        arguments: [ListeningMode?.none, .off, .adaptive]
    )
    func toggleDefaultsToANC(initial: ListeningMode?) throws {
        let transport = FakeTransport(devices: [airpods])
        transport.modeByDevice[airpods.id] = initial
        let controller = AirPodsController(transport: transport)

        let result = try controller.toggle()

        #expect(result == .anc)
        #expect(transport.setCalls.map(\.mode) == [.anc])
    }
}

final class FakeTransport: ListeningModeTransport {
    struct SetCall {
        let mode: ListeningMode
        let device: AirPodsDevice
    }

    var devices: [AirPodsDevice]
    var discoveryError: TransportError?
    var modeByDevice: [String: ListeningMode?] = [:]
    private(set) var setCalls: [SetCall] = []

    init(devices: [AirPodsDevice] = [], discoveryError: TransportError? = nil) {
        self.devices = devices
        self.discoveryError = discoveryError
    }

    func connectedAirPods() throws -> [AirPodsDevice] {
        if let discoveryError { throw discoveryError }
        return devices
    }

    func readListeningMode(of device: AirPodsDevice) throws -> ListeningMode? {
        modeByDevice[device.id] ?? nil
    }

    func setListeningMode(_ mode: ListeningMode, on device: AirPodsDevice) throws {
        setCalls.append(SetCall(mode: mode, device: device))
        modeByDevice[device.id] = mode
    }
}
