@testable import AirPodsCore
import Testing

@Suite("ListeningMode")
struct ListeningModeTests {
    @Test("deviceValue matches bluetoothd's listening-mode property values")
    func deviceValues() {
        #expect(ListeningMode.off.deviceValue == 1)
        #expect(ListeningMode.anc.deviceValue == 2)
        #expect(ListeningMode.transparency.deviceValue == 3)
        #expect(ListeningMode.adaptive.deviceValue == 4)
    }

    @Test("init(deviceValue:) round-trips every mode")
    func roundTripsEveryMode() {
        for mode in ListeningMode.allCases {
            #expect(ListeningMode(deviceValue: mode.deviceValue) == mode)
        }
    }

    @Test("init(deviceValue:) rejects out-of-range values", arguments: [0, 5, -1, 255])
    func rejectsOutOfRange(value: Int) {
        #expect(ListeningMode(deviceValue: value) == nil)
    }
}
