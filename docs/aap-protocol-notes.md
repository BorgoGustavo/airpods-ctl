# AAP protocol notes — empirical findings

These are observations made by capturing live `bluetoothd` traffic between
macOS Tahoe 26.4.1 and AirPods Pro 2 (firmware 8B39) on 2026-05-28 with
PacketLogger.app. They do **not** reproduce content from any other project's
documentation — for the upstream reverse-engineering effort that first
mapped this protocol, see [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).

Raw captures live in `docs/captures/`.

## Transport: L2CAP over BR/EDR, dynamic CIDs

Contrary to the common assumption that AAP rides PSM `0x1001`, no fixed PSM
was observed in `openL2CAPChannel_Result` traffic. The system's `bluetoothd`
appears to open an L2CAP connection during pairing/connect and then
multiplexes AAP traffic across several **dynamic Channel IDs** assigned per
session. CIDs observed in our capture:

| CID      | Direction        | Observed payload                                                |
|----------|------------------|-----------------------------------------------------------------|
| `0x060A` | host → AirPods   | Commands (incl. set-listening-mode) and ~500 ms heartbeats      |
| `0x2A0D` | AirPods → host   | Status notifications and command echoes (acks)                  |
| `0x080C` | AirPods → host   | Short 3-byte notifications, suspected touch / stem events       |
| `0x2C0F` | AirPods → host   | Telemetry stream with IEEE-754 LE floats (spatial audio?)       |

For the toggle MVP only `0x060A` (write) and `0x2A0D` (read for ack/state)
matter.

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

All four are anchored as fixtures in `Tests/AirPodsCoreTests/AAPCodecTests.swift`.

## Command echo as ack

For each set-mode write on `0x060A`, the AirPods echo the **same 11 bytes**
back on `0x2A0D` 800–1200 ms later. This is usable as a confirmation
mechanism but is too slow to fit a sub-500 ms toggle path if waited on
synchronously. Phase 4 should send-and-return; optional async verification
can hang off the next invocation.

## What we still don't know (open for Phase 2/3)

- Whether a third-party process can hijack CID `0x060A` while `bluetoothd`
  is also writing (heartbeats every ~500 ms). Likely needs `IOBluetooth` and
  may require stopping or coexisting with the system writer.
- The handshake/setup sequence used by `bluetoothd` when AirPods first
  connect. We have not yet captured a clean reconnect from a cold state.
- Whether `IOBluetoothL2CAPChannel.openL2CAPChannelAsync(_:withPSM:_:)` can
  attach to an already-multiplexed connection or needs a brand-new one.

## Hardware/software under test

| Field          | Value                                                       |
|----------------|-------------------------------------------------------------|
| Mac            | Mac16,12, BCM4388C2, BT firmware 23.5.224.1476              |
| macOS          | 26.4.1 (build 25E253)                                       |
| AirPods        | AirPods Pro 2 (PID 0x2024 / VID 0x004C), firmware 8B39      |
| AirPods MAC    | `40:B3:FA:2F:D2:9E`                                         |
| Capture date   | 2026-05-28                                                  |
| Capture tool   | PacketLogger.app from Additional Tools for Xcode 26.5       |
