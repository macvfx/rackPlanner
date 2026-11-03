# QA Checklist

## Automated

- [x] Project generates with XcodeGen.
- [x] Debug app builds with code signing disabled.
- [x] Unit tests pass.
- [x] Documentation validation and privacy scan pass.
- [x] `git diff --check` or an equivalent whitespace check passes.

## Manual macOS acceptance

- [ ] New document displays the fictional sample project.
- [ ] Blank-plan command removes sample equipment safely.
- [ ] A preset can be added from the library.
- [ ] A preset can be dragged to an empty shelf.
- [ ] A device can be moved between shelves and to Unassigned.
- [ ] A shared JetKVM can be placed on a shelf occupied by a dedicated Mac.
- [ ] A second dedicated device is rejected from that occupied shelf.
- [ ] HDMI and USB connections can target compatible ports on the same host.
- [ ] Selecting the host lists its attached accessories.
- [ ] Model line and model identifier persist after saving and reopening.
- [ ] Hostname, LAN, VPN/Tailscale, and other addresses persist after reopening.
- [ ] HTTPS quick access resolves to the expected browser URL.
- [ ] Screen Sharing quick access resolves to the expected `vnc://` URL.
- [ ] Explicit URLs retain their port and path.
- [ ] Inspector changes persist after saving and reopening.
- [ ] Adding a second switch deducts two inter-switch ports.
- [ ] LAN and Production LAN capacity remain independent.
- [ ] A faster declared switch port can satisfy a slower endpoint.
- [ ] UPS shortage updates when protection is toggled.
- [ ] CSV export creates six readable schedules.
- [ ] **Rack Planner > About Rack Planner** shows the icon, version/build,
  privacy summary, Help, User Guide, and code.matx.ca link.
- [ ] **Help > Rack Planner Help** and Command-Question Mark open the segmented
  Help window.
- [ ] Help topic switching and the Done button work without opening a browser.
- [ ] VoiceOver labels identify add buttons, device cards, and warnings.

Automated success is not evidence that drag-and-drop, document reopening, CSV
folder selection, About/Help presentation, or accessibility has passed manual
acceptance.
