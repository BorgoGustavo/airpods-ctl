import AirPodsCore
import ArgumentParser
import Foundation

@main
struct AirPodsCtl: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "airpods-ctl",
        abstract: "Control AirPods Pro 2 noise modes via AAP/L2CAP",
        version: "0.0.1",
        subcommands: [Toggle.self, SetMode.self, GetMode.self, List.self],
        defaultSubcommand: Toggle.self
    )
}

struct Toggle: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "toggle",
        abstract: "Toggle ANC ↔ Transparency"
    )

    func run() async throws {
        FileHandle.standardError.write(Data("toggle: not implemented yet (Phase 4)\n".utf8))
        throw ExitCode(1)
    }
}

struct SetMode: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set specific noise mode"
    )

    @Argument(help: "off | anc | transparency | adaptive") var mode: ListeningMode

    func run() async throws {
        FileHandle.standardError.write(Data("set \(mode.rawValue): not implemented yet (Phase 3)\n".utf8))
        throw ExitCode(1)
    }
}

struct GetMode: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Print current noise mode"
    )

    func run() async throws {
        FileHandle.standardError.write(Data("get: not implemented yet (Phase 4)\n".utf8))
        throw ExitCode(1)
    }
}

struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List connected AirPods reported by the system"
    )

    @Flag(name: .shortAndLong, help: "Dump raw discovery probe (which service UUIDs return what) to stderr")
    var verbose: Bool = false

    func run() async throws {
        let transport = CoreBluetoothTransport()
        let controller = AirPodsController(transport: transport)
        defer { Task { await controller.close() } }

        if verbose {
            do {
                let probe = try await transport.probeServiceUUIDs()
                for (label, peripherals) in probe {
                    FileHandle.standardError.write(Data("[probe] \(label): \(peripherals.count) peripheral(s)\n".utf8))
                    for (id, name) in peripherals {
                        FileHandle.standardError.write(Data("[probe]   - \(id.uuidString)  \(name)\n".utf8))
                    }
                }
            } catch let error as TransportError {
                FileHandle.standardError.write(Data("[probe] error: \(humanReadable(error))\n".utf8))
            }
        }

        let devices: [AirPodsDevice]
        do {
            devices = try await controller.listDevices()
        } catch let error as TransportError {
            FileHandle.standardError.write(Data("error: \(humanReadable(error))\n".utf8))
            throw ExitCode(transportExitCode(error))
        }

        if devices.isEmpty {
            FileHandle.standardError.write(Data("No connected AirPods found.\n".utf8))
            throw ExitCode(2)
        }
        for device in devices {
            print("\(device.id.uuidString)\t\(device.name)")
        }
    }
}

extension ListeningMode: ExpressibleByArgument {}

private func humanReadable(_ error: TransportError) -> String {
    switch error {
    case .notImplemented: "transport feature not implemented"
    case .airPodsNotConnected: "no AirPods currently connected to this Mac"
    case .channelClosed: "Bluetooth channel closed unexpectedly"
    case .permissionDenied: "Bluetooth permission denied — check System Settings ▸ Privacy & Security ▸ Bluetooth"
    case .bluetoothUnavailable: "Bluetooth is off or unsupported on this Mac"
    case .timeout: "timed out waiting for Bluetooth"
    }
}

private func transportExitCode(_ error: TransportError) -> Int32 {
    switch error {
    case .permissionDenied: 3
    case .airPodsNotConnected, .bluetoothUnavailable: 2
    default: 1
    }
}
