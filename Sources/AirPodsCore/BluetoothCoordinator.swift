import CoreBluetooth
import Foundation

/// NSObject adapter between Core Bluetooth's callback-based delegate world and
/// the async/await Transport actor. Core Bluetooth delivers `delegate` callbacks
/// on the dispatch queue passed to `CBCentralManager`, not inside an actor's
/// serial executor, so the actor itself cannot conform to the delegate
/// protocols. This class converts the only callback we need today
/// (`centralManagerDidUpdateState`) into an AsyncStream the transport can await.
final class BluetoothCoordinator: NSObject, CBCentralManagerDelegate {
    let stateUpdates: AsyncStream<CBManagerState>
    private let stateContinuation: AsyncStream<CBManagerState>.Continuation

    override init() {
        var continuation: AsyncStream<CBManagerState>.Continuation!
        stateUpdates = AsyncStream(
            CBManagerState.self,
            bufferingPolicy: .bufferingNewest(1)
        ) { c in
            continuation = c
        }
        stateContinuation = continuation
        super.init()
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        stateContinuation.yield(central.state)
    }

    func finish() {
        stateContinuation.finish()
    }
}
