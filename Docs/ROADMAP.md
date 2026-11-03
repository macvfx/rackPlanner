# Roadmap

Everything in this document is planned, not shipped.

## Next: explicit connections and cable planning

- Draw the existing host connections and future network/power links on the canvas.
- Hybrid port assignment: automatic compatible selection with manual override.
- Count RJ45, fibre, DAC, HDMI, USB, Thunderbolt, storage, and power cables.
- Optional cable lengths based on equipment-area and shelf position.
- Validate cable category, SFP/transceiver compatibility, and oversubscribed
  uplinks.

Acceptance gate: every exported cable has two explicit endpoints and changing a
link updates both devices, capacity, and the cable schedule.

## Rack layout refinement

- Exact rack-unit placement and standard rack heights.
- Multiple dedicated devices per shelf and purpose-built Mac mini mounts.
- Device dimensions, rack depth, weight, ventilation, and reserved gaps.
- Patch panels, cable managers, and equipment outside the rack.
- Printable rack elevations.

## Network refinement

- Custom user-defined networks and colours.
- Explicit switch-to-switch topology instead of inferred uplinks.
- VLAN access/trunk ports, routed boundaries, firewalls, and management planes.
- LACP, NAS bonding, redundant A/B fabrics, and failure-domain warnings.
- PoE standards, budgets, and access-point/client representation.
- A vendor-neutral optimizer that compares alternative switch combinations.

## Power refinement

- PDU connections, redundant A/B power, circuit limits, and plug types.
- UPS VA/watt capacity, battery characteristics, and estimated runtime.
- Power cable schedule and warnings for unsupported electrical assumptions.

## Deliverables and library

- PDF report and image export.
- Saved user device presets and import/exportable preset libraries.
- Optional real-product catalogue without requiring pricing.
- Templates for home lab, small studio, and small office installations.
- Verified model-identifier catalogue that can populate processor, memory limits,
  built-in networking, dimensions, and power guidance without guessing.
