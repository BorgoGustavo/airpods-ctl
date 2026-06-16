import Foundation

public struct AirPodsDevice: Identifiable, Sendable, Hashable {
    /// Bluetooth MAC address in IOBluetooth format (`"aa-bb-cc-dd-ee-ff"`).
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
