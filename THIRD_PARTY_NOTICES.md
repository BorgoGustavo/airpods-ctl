# Third-party notices

## LibrePods — Apple Accessory Protocol (AAP) reverse engineering

This project re-implements parts of the Apple Accessory Protocol in Swift
for macOS based on the reverse-engineering work documented by the
[LibrePods](https://github.com/kavishdevar/librepods) project (formerly
OpenPods4Mac variants, primarily targeting Android and Linux).

### Important — license boundary

LibrePods is licensed under **GNU General Public License v3.0**. This
project is licensed under MIT. To avoid creating a GPL-derivative work,
**no LibrePods source code or documentation is copied into this repository**.
We only reference the upstream document and independently observe the same
bytes against our own hardware (see `docs/captures/`) and describe the
factual protocol layout in our own words (see `docs/aap-protocol-notes.md`).

Facts about a third party's binary protocol are not themselves
copyrightable; the LibrePods authors did the painstaking reverse-engineering
that made those facts knowable.

### Pinned reference

To make the upstream reference reproducible, we pin the exact LibrePods
commit and blob hashes used while building Phase 2:

```
Project:        github.com/kavishdevar/librepods
Repo commit:    29a914c2ff93c8472442cefc855f14ba6c16ad1c   (2026-05-18)
Document:      docs/AAP Definitions.md
Blob SHA:       87b23d9053c85bd0d3b8dbc5bb468f4d29c200fe
Permalink:      https://github.com/kavishdevar/librepods/blob/29a914c2ff93c8472442cefc855f14ba6c16ad1c/docs/AAP%20Definitions.md
License:        GPL-3.0
Retrieved:      2026-05-28
```

### Verification against our hardware

The four `setListeningMode` test cases in
`Tests/AirPodsCoreTests/AAPCodecTests.swift` carry the literal bytes
captured from `bluetoothd` on macOS Tahoe 26.4.1 with AirPods Pro 2
firmware 8B39 (see `docs/captures/mode-transitions-2026-05-28.pklg`).
Those bytes happen to match the LibrePods description exactly — meaning
that as of this firmware Apple has not deviated from the documented layout.
If a future macOS or AirPods firmware update changes the wire format, the
captured-bytes fixtures will fail first and point at the right place.
