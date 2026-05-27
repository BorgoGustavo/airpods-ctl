import Foundation

public actor AirPodsController {
    let transport: BluetoothTransport
    let commands: AAPCommands

    public init(transport: BluetoothTransport, commands: AAPCommands = AAPCommands()) {
        self.transport = transport
        self.commands = commands
    }

    public func listDevices() async throws -> [AirPodsDevice] {
        try await transport.discoverConnectedAirPods()
    }

    public func setMode(_ mode: ListeningMode) async throws {
        let data = commands.setListeningMode(mode)
        try await transport.send(data)
    }

    public func toggle() async throws -> ListeningMode {
        try await setMode(.anc)
        return .anc
    }

    public func close() async {
        await transport.close()
    }
}
