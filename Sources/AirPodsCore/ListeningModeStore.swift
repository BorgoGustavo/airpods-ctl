import Foundation

/// Remembers the last mode this tool set per device, so one-shot processes
/// can toggle even though the live mode is unreadable cross-process (see
/// `ListeningModeTransport.readListeningMode(of:)`). If the user changes the
/// mode elsewhere (Control Center), the memory goes stale — but since setting
/// a mode is an absolute write, a toggle from stale state costs at most one
/// extra keypress before converging.
public protocol ListeningModeStore {
    func lastSetMode(for deviceID: String) -> ListeningMode?
    func recordMode(_ mode: ListeningMode, for deviceID: String)
}

/// JSON-file-backed store. Best effort by design: persistence failures are
/// swallowed — remembering the mode is never worth failing a mode change over.
public struct FileModeStore: ListeningModeStore {
    private let fileURL: URL

    /// `~/Library/Application Support/airpods-ctl/last-modes.json`
    public static func standard() -> FileModeStore {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return FileModeStore(fileURL: base.appendingPathComponent("airpods-ctl/last-modes.json"))
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func lastSetMode(for deviceID: String) -> ListeningMode? {
        guard let raw = readModes()[deviceID] else { return nil }
        return ListeningMode(rawValue: raw)
    }

    public func recordMode(_ mode: ListeningMode, for deviceID: String) {
        var modes = readModes()
        modes[deviceID] = mode.rawValue
        guard let data = try? JSONEncoder().encode(modes) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    private func readModes() -> [String: String] {
        guard let data = try? Data(contentsOf: fileURL),
              let modes = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return modes
    }
}
