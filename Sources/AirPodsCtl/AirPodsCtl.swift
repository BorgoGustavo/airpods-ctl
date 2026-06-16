import AirPodsCore
import ArgumentParser
import Foundation

@main
struct AirPodsCtl: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "airpods-ctl",
        abstract: "Experimental CLI for AirPods Pro noise modes — does NOT yet change the device (see README)",
        version: "0.0.1",
        subcommands: [Toggle.self, SetMode.self, GetMode.self, List.self],
        defaultSubcommand: Toggle.self
    )
}

/// `set`/`toggle` currently update local state but do not command the AirPods
/// firmware — the working IOBluetooth setup is still being reverse-engineered
/// (see README "Findings"). Printed once so nobody mistakes a 0 exit code for a
/// real mode change.
private func warnNotWired() {
    FileHandle.standardError.write(Data(
        "warning: this build does not change the AirPods mode yet — only local state was updated. See README.\n".utf8
    ))
}

struct Toggle: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "toggle",
        abstract: "Toggle ANC ↔ Transparency"
    )

    func run() throws {
        let mode = try mappingTransportErrors { try makeController().toggle() }
        print(mode.rawValue)
        warnNotWired()
    }
}

struct SetMode: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set specific noise mode"
    )

    @Argument(help: "off | anc | transparency | adaptive") var mode: ListeningMode

    func run() throws {
        try mappingTransportErrors { try makeController().setMode(mode) }
        warnNotWired()
    }
}

struct GetMode: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Print current noise mode (\"unknown\" when macOS won't say)"
    )

    func run() throws {
        let mode = try mappingTransportErrors { try makeController().currentMode() }
        print(mode?.rawValue ?? "unknown")
    }
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List connected AirPods reported by the system"
    )

    func run() throws {
        let devices = try mappingTransportErrors { try makeController().listDevices() }
        if devices.isEmpty {
            FileHandle.standardError.write(Data("No connected AirPods found.\n".utf8))
            throw ExitCode(2)
        }
        for device in devices {
            print("\(device.id)\t\(device.name)")
        }
    }
}

extension ListeningMode: ExpressibleByArgument {}

private func makeController() -> AirPodsController {
    AirPodsController(transport: IOBluetoothTransport(), store: FileModeStore.standard())
}

/// Translates TransportError into the documented exit codes:
/// 2 = AirPods not connected / Bluetooth off, 3 = TCC denied, 1 = anything else.
private func mappingTransportErrors<T>(_ body: () throws -> T) throws -> T {
    do {
        return try body()
    } catch let error as TransportError {
        FileHandle.standardError.write(Data("error: \(humanReadable(error))\n".utf8))
        throw ExitCode(exitCode(for: error))
    }
}

private func humanReadable(_ error: TransportError) -> String {
    switch error {
    case .airPodsNotConnected:
        "no AirPods currently connected to this Mac"
    case .permissionDenied:
        "Bluetooth permission denied — check System Settings ▸ Privacy & Security ▸ Bluetooth"
    case .bluetoothUnavailable:
        "Bluetooth is off or unsupported on this Mac"
    case let .privateAPIUnavailable(selector):
        "macOS no longer exposes '\(selector)' — a system update likely changed IOBluetooth; check for an airpods-ctl update"
    }
}

private func exitCode(for error: TransportError) -> Int32 {
    switch error {
    case .permissionDenied: 3
    case .airPodsNotConnected, .bluetoothUnavailable: 2
    case .privateAPIUnavailable: 1
    }
}
