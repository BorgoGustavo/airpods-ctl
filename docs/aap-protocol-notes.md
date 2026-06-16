# AAP protocol notes — empirical findings

These are observations made by capturing live `bluetoothd` traffic between
macOS Tahoe 26.4.1 and AirPods Pro 2 (firmware 8B39) on 2026-05-28 with
PacketLogger.app. They do **not** reproduce content from any other project's
documentation — for the upstream reverse-engineering effort that first
mapped this protocol, see [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).

Raw captures live in `docs/captures/`.

## Transport: L2CAP over BR/EDR — PSM still unknown, CIDs are per-session

The 2026-05-28 capture started **after** `bluetoothd` had already opened its
L2CAP channels, so the L2CAP_CONNECTION_REQ exchanges that negotiated PSM
and CIDs are missing from the trace. That means **the PSM AirPods Pro 2
listens on for AAP is still unknown** for this firmware on Tahoe — a
reconnect capture is required.

The four 16-bit values seen in the capture are **CIDs (Channel IDs)**, not
PSMs. CIDs are session-local handles a stack receives in the
`L2CAP_CONNECTION_RSP` from the peer; they are different on every
reconnection. They cannot be passed to
`IOBluetoothDevice.openL2CAPChannelAsync(_:withPSM:delegate:)` — that API
wants a PSM (a well-known service identifier, like a TCP port). Confusing
the two is a common trap.

| Session CID (2026-05-28) | Direction              | Observed payload                                                |
|--------------------------|------------------------|-----------------------------------------------------------------|
| `0x060A`                 | bluetoothd → AirPods   | Commands (incl. set-listening-mode) + ~500 ms heartbeats        |
| `0x2A0D`                 | AirPods → bluetoothd   | Status notifications and command echoes (acks)                  |
| `0x080C`                 | AirPods → bluetoothd   | Short 3-byte notifications, suspected touch / stem events       |
| `0x2C0F`                 | AirPods → bluetoothd   | Telemetry stream with IEEE-754 LE floats (spatial audio?)       |

When `airpods-ctl` opens its own L2CAP channel via `IOBluetooth`, it will
receive a **different** set of CIDs. The relevance of the CIDs above is
purely as a parsing aid for the reference capture.

## Set listening mode

Single 11-byte packet on CID `0x060A`:

```
04 00 04 00 09 00 0D <mode> 00 00 00
```

Mode byte values:

| Mode         | Byte |
|--------------|------|
| Off          | 0x01 |
| ANC          | 0x02 |
| Transparency | 0x03 |
| Adaptive     | 0x04 |

These bytes are recorded here as the captured ground truth. They are *not*
sent by `airpods-ctl` — see the Resolution below for why the L2CAP path was
abandoned.

## Command echo as ack

For each set-mode write on `0x060A`, the AirPods echo the **same 11 bytes**
back on `0x2A0D` 800–1200 ms later. This is usable as a confirmation
mechanism but is too slow to fit a sub-500 ms toggle path if waited on
synchronously. Phase 4 should send-and-return; optional async verification
can hang off the next invocation.

## What we didn't know at capture time (answered in the Resolution below)

- **The PSM.** The reference capture missed the `L2CAP_CONNECTION_REQ`. A
  reconnect capture (case-closed → case-opened) is queued; that trace will
  expose every PSM `bluetoothd` requests and the CIDs each one returns.
- **How many channels.** Could be one shared channel multiplexed via the
  inner `04 00 04 00 ...` framing, or several PSMs each carrying its own
  stream (the four CIDs hint at this).
- **Whether a second client can open the same PSM.** AirPods firmware may
  reject a second connection on the same PSM (no second writer). If so,
  `airpods-ctl` will have to coexist with `bluetoothd` somehow — possibly
  by injecting frames into `bluetoothd`'s channel via a private API, or by
  forcing `bluetoothd` off the device.

## Resolution part 1 — opening your own L2CAP/AAP channel is impossible on macOS

The L2CAP questions above are answered, and the answer kills the LibrePods port
strategy on macOS:

- **The PSM is `0x1001`** — confirmed not by capture but by SDP: the AirPods
  advertise an **"AAP Server"** record with `L2CAP PSM: 4097`
  (`IOBluetoothDevice.performSDPQuery`, or the private
  `appleAccessoryServerServiceRecord` getter). Matches LibrePods.
- **A second client cannot open it.** With Bluetooth TCC granted,
  `openL2CAPChannelSync(withPSM: 0x1001)` fails with `kIOReturnError`
  (`0xE00002BC`) after a ~3.1 s signaling timeout, and the async variant never
  fires its callback. Control PSMs (`0x0017` AVRCP, `0x001F` GATT) fail
  identically. While `bluetoothd` holds its AAP session — i.e. whenever the
  AirPods are connected and usable — no userland L2CAP connect to the device
  succeeds. This is why the LibrePods approach works on Android/Linux (those
  stacks never speak AAP) and cannot work on macOS.
- **Why no capture ever shows an AAP `L2CAP_CONNECTION_REQ`:** `bluetoothd`
  does not use one. The reconnect capture contains an
  `Echo Request: Fast Connect Discovery Request` whose payload carries the
  CIDs directly (`0x2E08` proposed by the Mac, `0x0A05` answered by the
  AirPods). Apple negotiates its channels through a proprietary L2CAP-echo
  handshake, not a standard PSM connect — so the AAP PSM never appears on the
  air between Apple devices.

So the only way is to ask `bluetoothd` to send the command for us, through some
private framework. The rest of the investigation maps those.

## Resolution part 2 — every `listeningMode` setter we can reach is a state mirror

Probed the private surface (`dyld_info -exports` + Swift demangle + Obj-C
runtime; **compile probes with `swiftc`, not the `swift` interpreter** — the JIT
SIGTRAPs when these frameworks pull in CloudKit; and probe classes by
`objc_getClass(name)`, not a full `objc_copyClassList` walk, which traps on some
class):

- **`IOBluetoothDevice.setListeningMode:`** is a synthesized `@property`
  (`property_getAttributes` = `TC,N,V_listeningMode`: a char, ivar-backed). A
  same-process read-back returns whatever you just set, which *looks* like it
  worked but only proves you read the ivar. Setting it in a short-lived process
  changes nothing audible (confirmed on hardware). The getter reads `0` from a
  fresh process — it's a cache populated by incoming notifications, not a live
  query.
- **`CBDevice`** (resolved via `objc_getClass` after loading HeadphoneManager/
  BluetoothAudio) has `setListeningMode:`, `setMicrophoneMode:`,
  `setSpatialAudioMode:` — but it's a **serializable XPC DTO**
  (`supportsSecureCoding`, `updateRemoteSendEvent:fromDeviceInfo:withDeviceKey:`).
  Mutating a field mutates the message, not the device.
- **`AVOutputDevice`** has the "intended" API
  `setCurrentBluetoothListeningMode:error:` and `currentBluetoothListeningMode`,
  but the current-output AirPods live in `AVOutputContext.sharedSystemAudioContext`,
  which returns **nil** without a privileged entitlement.
  `AVOutputDeviceDiscoverySession` *does* instantiate (`initWithDeviceFeatures:1`)
  but its `availableOutputDevices` is empty — the already-connected output isn't a
  "discoverable" device. This is the path NoiseBuddy used, and likely why it
  broke.

## Resolution part 3 — AirBuddy teardown: the right API is `IOBluetoothDevice` after all

[AirBuddy](https://v2.airbuddy.app/) is closed-source but works on Tahoe, so it's
a checkable existence proof. Static inspection of its app bundle
(`codesign -d --entitlements`, `otool -L`, `strings`):

- **No special Apple entitlement** — just team-id, app-groups, iCloud-kvstore,
  notifications. So the working path is not gated behind an entitlement we lack.
- Mode control lives in a LoginItem helper XPC
  (`AirBuddyHelper.app/.../BluetoothClassicService.xpc`) that links **IOBluetooth**
  and uses the **same** `setListeningMode:` selector we did
  (`safeSetListeningModeToMode:` wraps a KVC `setValue:forKey:` in a try/catch;
  it also observes `IOBluetoothDeviceListeningModeChanged` and calls
  `openConnection`). **No `openL2CAP`/PSM strings** — it does not open its own
  channel.

**Conclusion:** `IOBluetoothDevice.setListeningMode:` *is* the right call — it
works for AirBuddy. What we haven't reproduced is the runtime setup AirBuddy's
persistent helper has: the IOKit connection-notification machinery
(`IOServiceAddInterestNotification`), a device object bound to the live
connection rather than the cached `IOBluetoothDevice(addressString:)` singleton,
and a long-running process in the GUI login session. Calling the setter with
`openConnection` + a live `RunLoop` was **not** enough (confirmed: no audible
change).

## The open problem

Find the setup that makes `IOBluetoothDevice.setListeningMode:` actually reach
the firmware. Planned next step (capture-first): record `bluetoothd` traffic
while AirBuddy changes the mode, and diff it against a capture of our own
`setListeningMode:` call — the difference shows what bluetoothd does on the wire
when the command really lands.

## Hardware/software under test

The capture artifacts in `docs/captures/` were recorded on:

| Field          | Value                                                       |
|----------------|-------------------------------------------------------------|
| Mac            | Apple silicon, BCM4388C2 Bluetooth                          |
| macOS          | Tahoe 26                                                    |
| AirPods        | AirPods Pro 2 (PID 0x2024 / VID 0x004C), firmware 8B39      |
| Capture tool   | PacketLogger.app from Additional Tools for Xcode            |

> Device addresses and serial numbers in the raw captures are one person's
> hardware and carry no protocol meaning. Treat them as opaque.
