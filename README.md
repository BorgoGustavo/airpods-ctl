# airpods-ctl

Open-source macOS CLI / `.app` bundle that controls **AirPods Pro 2 noise modes** (ANC, Transparency, Off, Adaptive) by speaking the **Apple Accessory Protocol (AAP)** directly over L2CAP — no UI scripting, no menu flash, no Shortcuts dependency.

This is a port to macOS of the protocol work done by [LibrePods](https://github.com/kavishdevar/librepods) (Android/Linux). LibrePods reverse-engineered AAP; this project re-implements just enough of it in Swift to expose a fast CLI for keyboard-shortcut workflows.

## Why this exists

- [NoiseBuddy](https://github.com/insidegui/NoiseBuddy) is abandoned and explicitly does not work on recent macOS.
- macOS Shortcuts' "Set Noise Control Mode" action is unreliable on Tahoe 26 and has no read counterpart for clean toggling.
- AppleScript / UI scripting against the Sound menu flashes the popover for 300–500 ms.
- [AirBuddy 2](https://v2.airbuddy.app/) solves this but is closed-source and paid (~$10).

There was no open-source path on macOS. This fills that gap.

## Status

**Phase 0** — project scaffolding only. The CLI commands print stubs.

## Requirements

- macOS 15 (Sequoia) or newer. Tested on Tahoe 26.4.1.
- Swift 5.10+ (ships with Xcode 15.3+ / Command Line Tools).
- AirPods Pro 2 paired to this Mac.

## Build

```sh
make build      # universal binary (arm64 + x86_64) in release mode
make app        # assemble AirPodsToggle.app under .build/
make install    # copy to ~/Applications and symlink CLI to /opt/homebrew/bin/
make test       # run protocol codec tests (no hardware needed)
```

### Testing locally

Tests use [Swift Testing](https://github.com/swiftlang/swift-testing). On a machine
with a full Xcode install, `make test` just works. On a Command Line Tools-only
install, the test bundle compiles but dyld may fail to locate `Testing.framework`
at runtime — install Xcode if you want to run tests locally. CI uses GitHub's
`macos-15` runners which have Xcode pre-installed.

## Usage (post-MVP)

```sh
airpods-ctl toggle               # ANC ↔ Transparency
airpods-ctl set anc|transparency|off|adaptive
airpods-ctl get
airpods-ctl list
```

For keyboard-driven workflows on macOS, map a key in Logi Options+ (or your launcher of choice) to **"Open Application"** → `~/Applications/AirPodsToggle.app`. The bundle has `LSUIElement=true`, so no Dock bounce.

## Troubleshooting

**Gatekeeper blocks the `.app` on first launch**

Because this isn't notarized, macOS may quarantine it:

```sh
xattr -d com.apple.quarantine ~/Applications/AirPodsToggle.app
```

**TCC Bluetooth prompt doesn't appear**

The bundle ID is `dev.borgo.airpods-ctl`, and codesigning is ad-hoc but consistent. If `swift build` was invoked outside `make app`, the binary may have a fresh signature each time, invalidating TCC. Always go through `make app` / `make install`.

## License

MIT. See `LICENSE`.

## Acknowledgments

See `THIRD_PARTY_NOTICES.md`. The AAP protocol layout used here comes from the [LibrePods](https://github.com/kavishdevar/librepods) reverse engineering effort — without that work this port would have been months longer.
