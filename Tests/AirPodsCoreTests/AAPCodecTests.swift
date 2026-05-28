@testable import AirPodsCore
import Testing

@Suite("AAP codec")
struct AAPCodecTests {
    // MARK: - Captured-bytes fixtures

    //
    // These tests anchor the encoder to bytes captured live from the macOS
    // Control Center alternating noise modes on AirPods Pro 2 (firmware 8B39)
    // on 2026-05-28. Raw frames are in
    // docs/captures/mode-transitions-2026-05-28.pklg. If Apple changes the
    // protocol in a firmware update, these break first and tell us where.

    @Test("set off — matches Control Center capture (2026-05-28)")
    func setOff_matchesCapturedBytes() {
        let captured: [UInt8] = [0x04, 0x00, 0x04, 0x00, 0x09, 0x00, 0x0D, 0x01, 0x00, 0x00, 0x00]
        #expect([UInt8](AAPCodec().encodeSetListeningMode(.off)) == captured)
    }

    @Test("set ANC — matches Control Center capture (2026-05-28)")
    func setAnc_matchesCapturedBytes() {
        let captured: [UInt8] = [0x04, 0x00, 0x04, 0x00, 0x09, 0x00, 0x0D, 0x02, 0x00, 0x00, 0x00]
        #expect([UInt8](AAPCodec().encodeSetListeningMode(.anc)) == captured)
    }

    @Test("set transparency — matches Control Center capture (2026-05-28)")
    func setTransparency_matchesCapturedBytes() {
        let captured: [UInt8] = [0x04, 0x00, 0x04, 0x00, 0x09, 0x00, 0x0D, 0x03, 0x00, 0x00, 0x00]
        #expect([UInt8](AAPCodec().encodeSetListeningMode(.transparency)) == captured)
    }

    @Test("set adaptive — matches Control Center capture (2026-05-28)")
    func setAdaptive_matchesCapturedBytes() {
        let captured: [UInt8] = [0x04, 0x00, 0x04, 0x00, 0x09, 0x00, 0x0D, 0x04, 0x00, 0x00, 0x00]
        #expect([UInt8](AAPCodec().encodeSetListeningMode(.adaptive)) == captured)
    }

    // MARK: - Structural invariants

    @Test("Every encoded packet is exactly 11 bytes")
    func packetLengthIsAlwaysEleven() {
        let codec = AAPCodec()
        for mode in ListeningMode.allCases {
            #expect(codec.encodeSetListeningMode(mode).count == 11)
        }
    }

    @Test("ListeningMode round-trips through rawByte")
    func listeningModeRoundTrip() {
        for mode in ListeningMode.allCases {
            #expect(ListeningMode(rawByte: mode.rawByte) == mode)
        }
    }

    @Test("Unknown bytes do not map to a ListeningMode", arguments: [UInt8(0x00), UInt8(0x05), UInt8(0xFF)])
    func unknownByteReturnsNil(_ byte: UInt8) {
        #expect(ListeningMode(rawByte: byte) == nil)
    }
}
