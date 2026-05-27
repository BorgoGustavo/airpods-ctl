import Foundation

public enum AAPCodecError: Error, Equatable {
    case shortPacket(expected: Int, got: Int)
    case invalidHeader
    case unknownMode(UInt8)
}

public struct AAPCodec {
    public init() {}

    public func encodeSetListeningMode(_ mode: ListeningMode) -> Data {
        var bytes = AAPProtocolConstants.header + AAPProtocolConstants.setListeningModeOpcode
        bytes.append(mode.rawByte)
        bytes.append(contentsOf: [0x00, 0x00, 0x00])
        return Data(bytes)
    }
}
