# Third-party notices

## LibrePods — Apple Accessory Protocol (AAP) definitions

This project's AAP packet layouts and L2CAP PSM (`0x1001`) were derived from
the reverse engineering documented in the [LibrePods](https://github.com/kavishdevar/librepods)
project (formerly OpenPods4Mac variants).

LibrePods is licensed under the GNU General Public License v3.0. This project
does **not** copy LibrePods source code; it independently re-implements the
protocol in Swift for macOS, based on the public protocol description in
`AAP Definitions.md`.

### Pinned reference

To keep the protocol description used here reproducible, the specific commit
of `AAP Definitions.md` that this port targets will be recorded here once
Phase 2 (handshake) is implemented. Until then, the current `main` branch of
LibrePods is the working reference.

**Status:** Phase 0 — no protocol code merged yet. Pin to be added in Phase 2.

```
Reference URL: https://github.com/kavishdevar/librepods
Reference file: AAP Definitions.md
Reference commit: TBD (pinned in Phase 2)
```
