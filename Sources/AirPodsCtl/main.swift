import AirPodsCore
import ArgumentParser
import Foundation

struct AirPodsCtl: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "airpods-ctl",
        abstract: "Control AirPods Pro 2 noise modes via AAP/L2CAP",
        version: "0.0.1",
        subcommands: [Toggle.self, SetMode.self, GetMode.self, List.self],
        defaultSubcommand: Toggle.self
    )
}

struct Toggle: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "toggle",
        abstract: "Toggle ANC ↔ Transparency"
    )

    func run() throws {
        FileHandle.standardError.write(Data("toggle: not implemented in Phase 0 (stub)\n".utf8))
    }
}

struct SetMode: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set specific noise mode"
    )

    @Argument(help: "off | anc | transparency | adaptive") var mode: ListeningMode

    func run() throws {
        FileHandle.standardError.write(Data("set \(mode.rawValue): not implemented in Phase 0 (stub)\n".utf8))
    }
}

struct GetMode: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Print current noise mode"
    )

    func run() throws {
        FileHandle.standardError.write(Data("get: not implemented in Phase 0 (stub)\n".utf8))
    }
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List paired AirPods"
    )

    func run() throws {
        FileHandle.standardError.write(Data("list: not implemented in Phase 0 (stub)\n".utf8))
    }
}

extension ListeningMode: ExpressibleByArgument {}

AirPodsCtl.main()
