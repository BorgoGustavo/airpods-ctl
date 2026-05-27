import Foundation

public struct AAPCommands {
    let codec: AAPCodec

    public init(codec: AAPCodec = AAPCodec()) {
        self.codec = codec
    }

    public func setListeningMode(_ mode: ListeningMode) -> Data {
        codec.encodeSetListeningMode(mode)
    }
}
