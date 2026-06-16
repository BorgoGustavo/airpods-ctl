# airpods-ctl

An open reverse-engineering effort to control **AirPods Pro 2 noise modes**
(ANC, Transparency, Off, Adaptive) from the macOS command line — no UI
scripting, no menu flash, no Shortcuts dependency — for keyboard-driven
workflows.

> ### ⚠️ Status: investigation in progress — does **not** yet change the hardware
>
> This repo is an honest, in-progress teardown of how AirPods listening modes
> are actually controlled on macOS. **No approach here changes the mode on the
> device yet.** The CLI builds, runs, and `list` works, but `set`/`toggle`
> currently update local state without commanding the AirPods (the tool warns
> you when you run them). The value right now is the documented research, not a
> working binary. See **[Findings](#findings-so-far)** below.

## Why this exists

Switching ANC ↔ Transparency from a keyboard shortcut, silently, has no good
open-source path on macOS:

- [NoiseBuddy](https://github.com/insidegui/NoiseBuddy) is abandoned and does not
  work on recent macOS.
- macOS Shortcuts' "Set Noise Control Mode" action is unreliable on Tahoe 26 and
  has no read counterpart for clean toggling.
- AppleScript / UI scripting against the Sound menu flashes the popover for
  300–500 ms.
- [AirBuddy 2](https://v2.airbuddy.app/) solves it but is closed-source and paid.

The goal of this project is to find — and document — a reproducible, scriptable
way to do it.

## Findings so far

The interesting part. This started as a macOS port of the AAP-over-L2CAP work
from [LibrePods](https://github.com/kavishdevar/librepods) (Android/Linux), and
turned into a tour of every macOS path for this. Full detail in
[`docs/aap-protocol-notes.md`](docs/aap-protocol-notes.md); the short version:

**1. Opening your own L2CAP/AAP channel is a dead end on macOS.**
LibrePods works on Android/Linux because those stacks speak AAP directly. On
macOS, `bluetoothd` already holds the AAP session, and the AirPods firmware
**refuses a second L2CAP client**. Verified empirically:
`openL2CAPChannelSync(withPSM: 0x1001)` returns `kIOReturnError` after a ~3 s
timeout — and it fails the same way on the AVRCP/GATT PSMs. The AAP PSM `0x1001`
is real (confirmed via SDP, "AAP Server" record), but it's unreachable while the
system owns it. Apple even negotiates its own channels through a proprietary
Fast Connect L2CAP-echo handshake, so the AAP connection never appears in a
packet capture between two Apple devices.

**2. The private framework `listeningMode` properties are state mirrors, not
command channels.** `IOBluetoothDevice.setListeningMode:`, `CBDevice`
(an XPC DTO), and `AVOutputDevice.setCurrentBluetoothListeningMode:` all *look*
like setters, but in an unprivileged short-lived process they write a local
field and nothing reaches the hardware. `AVOutputContext.sharedSystemAudioContext`
(the old NoiseBuddy path) returns `nil` without a privileged entitlement — likely
why NoiseBuddy stopped working.

**3. AirBuddy proves the real path — and it's `IOBluetoothDevice`.** AirBuddy
(closed-source, works on Tahoe) ships a `BluetoothClassicService.xpc` with **no
special Apple entitlement** that links IOBluetooth and uses the exact same
`setListeningMode:` selector. So the right API *is* the cheap one — the missing
ingredient is the runtime setup AirBuddy's persistent helper has (IOKit
connection-notification machinery, a live device object, the GUI login session)
that a short-lived process does not. **Cracking that setup is the current open
problem.**

## What works today

| Command | State |
|---|---|
| `airpods-ctl list` | ✅ enumerates connected AirPods |
| `airpods-ctl set <mode>` | ⚠️ runs, persists state, **does not change the device yet** |
| `airpods-ctl get` | ⚠️ prints last mode this tool set (or `unknown`) |
| `airpods-ctl toggle` | ⚠️ same caveat as `set` |

## Architecture

The transport is abstracted behind a `ListeningModeTransport` protocol, so when
the working setup is found it slots in as a new conformer without touching the
CLI, the per-device mode store, or the tests. Swift 5.10 + SwiftPM; the `.app`
bundle exists to give the binary a stable code signature so Bluetooth TCC
permission persists across rebuilds.

## Build

```sh
make build      # universal binary (arm64 + x86_64) in release mode
make app        # assemble AirPodsToggle.app under .build/
make install    # copy to ~/Applications and symlink CLI to /opt/homebrew/bin/
make test       # run unit tests (no hardware needed)
```

### Testing locally

Tests use [Swift Testing](https://github.com/swiftlang/swift-testing). On a
machine with a full Xcode install, `make test` just works. On a Command Line
Tools-only install, the test bundle compiles but dyld may fail to locate
`Testing.framework` at runtime — install Xcode for local testing. CI uses
GitHub's `macos-15` runners which have Xcode pre-installed.

## Requirements

- macOS 15 (Sequoia) or newer. Developed against Tahoe 26.
- Swift 5.10+ (ships with Xcode 15.3+ / Command Line Tools).
- AirPods Pro 2 paired to this Mac.

## Contributing

If you know how AirBuddy (or any working tool) makes `IOBluetoothDevice`'s
listening-mode setter actually reach the firmware, that's the missing piece —
issues and PRs welcome. Captures and probe scripts that reproduce or refute the
findings above are especially useful.

## License

MIT. See `LICENSE`.

## Acknowledgments

See `THIRD_PARTY_NOTICES.md`. The AAP protocol layout that seeded this
investigation comes from the [LibrePods](https://github.com/kavishdevar/librepods)
reverse-engineering effort.
