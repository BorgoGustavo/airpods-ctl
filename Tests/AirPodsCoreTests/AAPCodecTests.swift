@testable import AirPodsCore
import Testing

@Suite("AAP codec")
struct AAPCodecTests {
    @Test("Set listening mode ANC encodes to the documented 11-byte packet")
    func encodeSetListeningModeAnc() {
        let codec = AAPCodec()
        let data = codec.encodeSetListeningMode(.anc)
        let expected: [UInt8] = [0x04, 0x00, 0x04, 0x00, 0x09, 0x00, 0x0D, 0x02, 0x00, 0x00, 0x00]
        #expect([UInt8](data) == expected)
    }

    @Test("Mode byte at offset 7 matches each ListeningMode's rawByte", arguments: ListeningMode.allCases)
    func modeByteAtOffsetSeven(_ mode: ListeningMode) {
        let codec = AAPCodec()
        let bytes = [UInt8](codec.encodeSetListeningMode(mode))
        #expect(bytes[7] == mode.rawByte)
    }

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
