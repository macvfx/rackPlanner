# Changelog

## 0.2.0 (build 8) — Unreleased

Builds on the 0.1.0 MVP, which was never released; its notes follow under Added.

### Changed

- Rack view: right-click a card for Show in Inspector, Duplicate, and Delete…. Duplicates
  get new identifiers, a " copy" name, and no hostname, addresses, or host connections.

- "Dedicated" is now called **primary** in the app, and the Shelf use picker reads
  "Primary — owns its shelf" / "Shared — rides on a primary device's shelf". Rack cards
  now show only "shared" where it applies instead of tagging every card. Saved files and
  CSV values are unchanged.

- Rack view cards list ports by type (for example "5 network · 2 Thunderbolt · 1 HDMI")
  instead of one total. Wi-Fi radios and power inlets (AC, and the USB-C power input on
  the Raspberry Pi and Generic KVM) are no longer counted. Cause: the card used
  `ports.count`, which counted every entry in the port list, so a router's Wi-Fi radio and
  AC inlet inflated its "ports".

- Rack view: drop a device in the gap between two shelves to insert it there; neighbouring
  shelves slide to the nearest empty shelf instead of swapping.

- Rack view: drag a dedicated device onto an occupied shelf to swap the two shelves
  (shared accessories travel with their host, also across racks). Previously a drop
  on an occupied shelf was refused.

- The JetKVM preset is now **Generic KVM**; rename the device (or set its model
  line) to JetKVM or any other KVM when adding it.
- Every category now has a generic block (computer, network device, switch,
  storage, adapter/dock, IoT, power, peripheral, KVM) for equipment with no named
  preset.
- Capacity checks are speed-aware: endpoints that need 10 Gb are counted against
  ports that actually reach 10 Gb, not against every port. Cause: the engine
  compared only the fastest endpoint with the fastest port, so a switch with one
  10 Gb port looked adequate for several 10 Gb machines.

### Fixed

- Rack view card detail text wraps to a second line instead of being cut off
  (a long port summary ended in "1 HD"). Cause: the line was limited to one line
  at a fixed card width.

- Quick-access links only open http, https, vnc, and ssh. Cause: any URL with a
  scheme was passed through, so a shared plan could hold a `file:` or other
  app-scheme link.
- Plans saved by a newer schema are refused instead of being opened and re-saved
  without the newer data; plans missing optional top-level keys now open.
- Removing a port or device now removes host connections that used it, and
  placement in a removed rack is cleared. Cause: references were cleaned only for
  deleted devices, leaving blank cells in the connections CSV.
- CSV cells beginning with `=`, `+`, `-`, or `@` are prefixed so Excel and Numbers
  do not run them as formulas; export now asks before replacing existing CSVs.

### Added

- Native SwiftUI document-based macOS application.
- Sample home-rack project and blank-project command.
- Generic and named starting presets for computers, networking, KVM, storage,
  adapters, IoT equipment, and power.
- Drag-and-drop placement into shelf positions.
- Editable device names, shelf assignments, port networks, and port speeds.
- LAN, Production LAN, Wi-Fi, WAN, and custom network-purpose modelling.
- Live switch capacity calculation with 20% spare capacity and uplink deduction.
- Shelf and UPS outlet summaries.
- CSV export for devices, ports, switch requirements, and power.
- Shared shelves containing one dedicated device plus multiple accessories.
- Explicit accessory-to-host port assignments for USB, Thunderbolt, and HDMI.
- Attached-accessory summaries on host devices and connection labels in Rack view.
- Editable model-line and model-identifier fields for computers and other devices.
- Connection CSV export and backward-compatible document migration support.
- Hostname plus reusable LAN, VPN/Tailscale, and other-address entries.
- Clickable HTTP, HTTPS, Screen Sharing/VNC, and SSH quick-access links.
- Quick-access CSV export and backward-compatible schema version 3 documents.
- Original rack-and-home themed macOS app icon with a complete 16–1024px asset set.
- Finder Colours-inspired About and topic-based Help windows.
- Public User Guide, issue tracker, source repository, and code.matx.ca links.
- Local-first privacy documentation and warnings for potentially sensitive plan
  and CSV contents.
- `ca.macvfx.RackPlanner` application and document-type identifiers.
- Regression tests for public support links.
- MIT License and consistent copyright metadata.
- Hardened-runtime Release configuration with string-valued version and build
  metadata for Developer ID distribution and Apple notarization.
