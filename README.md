# Rack Planner

Rack Planner is a native macOS SwiftUI application for sketching a small home
or office equipment installation and answering practical capacity questions:

- What equipment do I have, and where will it sit?
- How many LAN and Production LAN ports do I need?
- Are the available switch ports fast enough?
- How many ports are lost to switch uplinks?
- How many shelf positions and UPS outlets remain?
- What should I add while retaining 20% spare network capacity?

## Current status

This repository contains an early functional MVP. It supports document-based
projects, a reusable device library, shared-shelf accessory placement, explicit
USB/Thunderbolt/HDMI host connections, editable model identifiers and ports, a
network-oriented inventory view, clickable hostname/LAN/VPN access links,
switch and UPS capacity summaries, and CSV export. The planning engine deducts
inter-switch uplinks and applies a
configurable spare-port percentage.

Rack Planner follows the same straightforward native-macOS style as Finder
Colours: a compact About panel, topic-based in-app Help, standard document
behaviour, and support links that open only when selected.

It does **not** yet route individual graphical cables, calculate cable lengths,
model VLAN trunks/LACP, estimate UPS runtime, or position equipment in exact
rack units. See [the roadmap](Docs/ROADMAP.md) for planned work.

## Build

Requirements: macOS 15 or newer, Xcode 16 or newer, and XcodeGen.

```bash
xcodegen generate
xcodebuild -project RackPlanner.xcodeproj -scheme RackPlanner \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Run tests with:

```bash
xcodebuild -project RackPlanner.xcodeproj -scheme RackPlanner \
  -configuration Debug CODE_SIGNING_ALLOWED=NO test
```

The generated project uses the `ca.macvfx.RackPlanner` bundle identifier.
Developer signing teams, certificates, notarization credentials, local project
documents, and build outputs are intentionally not stored in this repository.

## Help and privacy

Choose **Help > Rack Planner Help** or press Command-Question Mark for concise
in-app guidance. Choose **Rack Planner > About Rack Planner** for the installed
version, privacy summary, User Guide, and [code.matx.ca](https://code.matx.ca).

Rack Planner works locally. It has no account, analytics, updater, cloud
service, or background service, and does not upload project contents,
hostnames, addresses, notes, usage information, or diagnostics. Support and
quick-access links contact their destinations only when you click them.

Saved `.rackplan` documents and exported CSV files can contain hostnames, IP
addresses, equipment notes, and topology details. Treat those files as
sensitive and review them before sharing.

## Documentation

- [Product specification](Docs/PRODUCT_SPEC.md)
- [User guide](Docs/USER_GUIDE.md)
- [Architecture](Docs/ARCHITECTURE.md)
- [Roadmap](Docs/ROADMAP.md)
- [QA checklist](Docs/QA_CHECKLIST.md)
- [Changelog](CHANGELOG.md)
- [code.matx.ca](https://code.matx.ca)
- [Source and issue tracker](https://github.com/macvfx/rackPlanner)

All sample names and values are fictional.

## License

Rack Planner is available under the [MIT License](LICENSE).
