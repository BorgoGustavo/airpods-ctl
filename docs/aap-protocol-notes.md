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

All four are anchored as fixtures in `Tests/AirPodsCoreTests/AAPCodecTests.swift`.

## Command echo as ack

For each set-mode write on `0x060A`, the AirPods echo the **same 11 bytes**
back on `0x2A0D` 800–1200 ms later. This is usable as a confirmation
mechanism but is too slow to fit a sub-500 ms toggle path if waited on
synchronously. Phase 4 should send-and-return; optional async verification
can hang off the next invocation.

## What we still don't know (open for Phase 2)

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

## Hardware/software under test

| Field          | Value                                                       |
|----------------|-------------------------------------------------------------|
| Mac            | Mac16,12, BCM4388C2, BT firmware 23.5.224.1476              |
| macOS          | 26.4.1 (build 25E253)                                       |
| AirPods        | AirPods Pro 2 (PID 0x2024 / VID 0x004C), firmware 8B39      |
| AirPods MAC    | `40:B3:FA:2F:D2:9E`                                         |
| Capture date   | 2026-05-28                                                  |
| Capture tool   | PacketLogger.app from Additional Tools for Xcode 26.5       |
