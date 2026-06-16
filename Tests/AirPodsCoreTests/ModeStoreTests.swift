@testable import AirPodsCore
import Foundation
import Testing

@Suite("AirPodsController + ListeningModeStore")
struct ControllerStoreTests {
    let airpods = AirPodsDevice(id: "aa-bb-cc-dd-ee-ff", name: "AirPods Pro")

    @Test("toggle alternates across controller instances sharing a store")
    func toggleAlternatesAcrossInstances() throws {
        let store = FakeStore()
        var observed: [ListeningMode] = []

        // Each iteration simulates a fresh one-shot process: new transport
        // (whose getter reads nothing) and new controller, same store on disk.
        for _ in 0 ..< 4 {
            let transport = FakeTransport(devices: [airpods])
            let controller = AirPodsController(transport: transport, store: store)
            try observed.append(controller.toggle())
        }

        #expect(observed == [.anc, .transparency, .anc, .transparency])
    }

    @Test("setMode records the mode in the store")
    func setModeRecords() throws {
        let store = FakeStore()
        let transport = FakeTransport(devices: [airpods])
        let controller = AirPodsController(transport: transport, store: store)

        try controller.setMode(.adaptive)

        #expect(store.modes[airpods.id] == .adaptive)
    }

    @Test("currentMode falls back to the store when the transport cannot read")
    func currentModeFallsBackToStore() throws {
        let store = FakeStore()
        store.modes[airpods.id] = .transparency
        let transport = FakeTransport(devices: [airpods])
        let controller = AirPodsController(transport: transport, store: store)

        #expect(try controller.currentMode() == .transparency)
    }

    @Test("a live transport reading wins over the store")
    func transportReadingWins() throws {
        let store = FakeStore()
        store.modes[airpods.id] = .transparency
        let transport = FakeTransport(devices: [airpods])
        transport.modeByDevice[airpods.id] = .anc
        let controller = AirPodsController(transport: transport, store: store)

        #expect(try controller.currentMode() == .anc)

        try controller.toggle()
        #expect(transport.setCalls.map(\.mode) == [.transparency])
    }
}

@Suite("FileModeStore")
struct FileModeStoreTests {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("airpods-ctl-tests-\(UUID().uuidString)")
            .appendingPathComponent("last-modes.json")
    }

    @Test("records and reads back per device")
    func roundTrips() {
        let store = FileModeStore(fileURL: temporaryFile())

        store.recordMode(.transparency, for: "aa-bb-cc-dd-ee-ff")
        store.recordMode(.anc, for: "11-22-33-44-55-66")

        #expect(store.lastSetMode(for: "aa-bb-cc-dd-ee-ff") == .transparency)
        #expect(store.lastSetMode(for: "11-22-33-44-55-66") == .anc)
    }

    @Test("persists across store instances")
    func persistsAcrossInstances() {
        let file = temporaryFile()

        FileModeStore(fileURL: file).recordMode(.adaptive, for: "aa-bb-cc-dd-ee-ff")

        #expect(FileModeStore(fileURL: file).lastSetMode(for: "aa-bb-cc-dd-ee-ff") == .adaptive)
    }

    @Test("returns nil for an unknown device or missing file")
    func unknownIsNil() {
        let store = FileModeStore(fileURL: temporaryFile())

        #expect(store.lastSetMode(for: "aa-bb-cc-dd-ee-ff") == nil)
    }

    @Test("tolerates a corrupt file and recovers on the next write")
    func toleratesCorruption() throws {
        let file = temporaryFile()
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json{{".utf8).write(to: file)
        let store = FileModeStore(fileURL: file)

        #expect(store.lastSetMode(for: "aa-bb-cc-dd-ee-ff") == nil)

        store.recordMode(.anc, for: "aa-bb-cc-dd-ee-ff")
        #expect(store.lastSetMode(for: "aa-bb-cc-dd-ee-ff") == .anc)
    }
}

final class FakeStore: ListeningModeStore {
    var modes: [String: ListeningMode] = [:]

    func lastSetMode(for deviceID: String) -> ListeningMode? {
        modes[deviceID]
    }

    func recordMode(_ mode: ListeningMode, for deviceID: String) {
        modes[deviceID] = mode
    }
}
