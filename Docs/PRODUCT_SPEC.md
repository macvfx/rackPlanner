# Rack Planner Product Specification

Status: MVP specification, implemented where marked **Shipped in 0.1**.

## Purpose

Rack Planner helps a home builder or small office describe one or two racks,
place equipment on shelves, model the ports available on every device, and
understand which switches, shelf positions, cables, and power outlets are
required. It is capacity planning software, not a network configuration tool.

## Target environment

- Native macOS application, minimum macOS 15.
- Small installations, normally 5–20 computers and appliances.
- Standard 19-inch racks, compact 10-inch racks, and open shelving.
- Routed LAN, isolated Production LAN, Wi-Fi, WAN, and IP/KVM equipment.
- Copper Ethernet, SFP/fibre, USB, Thunderbolt, HDMI, storage, and AC power.

## Primary workflow

1. Create or open a Rack Planner project.
2. Add racks or open equipment areas.
3. Add devices from presets or create a generic device.
4. Place devices into shelf positions.
5. Inspect and adjust each device's ports, network purpose, and speed.
6. Review live network, shelf, and UPS capacity warnings.
7. Export CSV schedules for implementation or purchasing research.

## Shipped in 0.1

### Project documents

Projects are JSON-backed macOS documents. A new document contains a fictional
home-rack example so the interface and calculations are immediately visible.
The user can replace it with a blank plan.

### Rack planning

- Multiple 19-inch, 10-inch, and open-shelf areas.
- Configurable shelf-position count.
- One dedicated device plus any number of shared accessories per shelf position.
- Unassigned-device area.
- Drag a library preset onto a shelf, or move an existing device between
  shelves.
- Live occupied, free, and over-capacity counts.

Dedicated devices cannot share a shelf with another dedicated device. KVMs,
adapters, external drives, IoT hubs, and peripherals default to shared-accessory
placement and can be added to an occupied computer shelf. The choice is editable.

Exact rack units, equipment dimensions, multiple dedicated devices per shelf,
airflow, and weight are future scope.

### Device and port model

Each device contains editable typed ports. Port types include RJ45 Ethernet,
SFP/fibre, Wi-Fi, USB-A, USB-C, Thunderbolt, HDMI, storage, and AC power.
Ethernet ports record their network purpose and negotiated/planned speed.

Devices also contain optional model-line and model-identifier text. For example,
a Mac can record both `Mac mini (M4 Pro)` and `Mac16,11`. Version 0.1 stores and
displays this identity but does not infer hardware specifications from it.

Shared accessories can assign their local USB, Thunderbolt, or HDMI ports to
compatible ports on a Mac or other host. Multiple assignments support equipment
such as a KVM that uses both HDMI and USB. Rack cards show the host connection,
and selecting a host lists the accessories connected to it.

Each device can store a hostname plus any number of LAN, VPN/Tailscale, and
other addresses. Every entry independently selects HTTP, HTTPS, macOS Screen
Sharing/VNC, SSH, or no action. Valid entries appear as clickable links in the
inspector. Existing complete URLs are preserved; otherwise the selected scheme
is added to the entered hostname or address.

Initial presets include Mac mini, Raspberry Pi, Generic KVM (rename it to the model you use, for example JetKVM), external SSD,
Thunderbolt dock, 10 Gb Thunderbolt adapter, 2.5 Gb USB adapter, Time Machine
drive, five-port 1 Gb switch, four-port 2.5 Gb switch with two 10 Gb uplinks,
NAS, printer, IoT sensor hub, solar hub, WAN router, UPS, and a generic block in every category for equipment with no named preset.

### Network calculation

The planner distinguishes network purpose from connector and speed. A 10 Gb
port assigned to Production LAN does not satisfy ordinary LAN demand.

For each network, the engine reports:

- endpoint demand;
- gross provider capacity;
- ports reserved for provider-to-provider uplinks;
- usable capacity;
- target capacity after the spare-port percentage;
- total shortage;
- fastest endpoint requirement and fastest available provider port.

When two provider devices share a network, the engine assumes one inter-device
link and deducts one compatible port at each end. A connected set of `n`
providers therefore requires `n - 1` links and `2 × (n - 1)` ports. This is a
capacity estimate; explicit link topology is planned.

### Power calculation

The MVP counts devices requesting UPS protection and compares that count with
the total UPS outlet capacity. Optional watt fields are retained and summed,
but runtime and electrical safety calculations are not provided.

### Export

CSV export produces devices, ports, quick-access endpoints, host connections,
network requirements, and power summaries.
PDF and graphical image export remain planned.

### Help, support, and privacy

The app provides a compact About window, topic-based in-app Help, a complete
User Guide, public source and issue links, and a link to
[code.matx.ca](https://code.matx.ca). The planner works locally and does not
include an account, analytics, updater, cloud service, background service, or
automatic network scanning. External pages and device quick-access addresses
are contacted only when the user activates a link.

Project documents and CSV exports can contain sensitive topology, hostname,
and address data. The app warns users to review those files before sharing.

## Safety and capability boundaries

- Recommendations are vendor-neutral capacity guidance, not purchasing or
  electrical advice.
- Speed compatibility is based on declared port capability. Real hardware may
  not negotiate every intermediate speed.
- The MVP does not validate cable category, optical transceivers, PoE budgets,
  VLAN configuration, spanning tree, routing policy, or electrical circuits.
- A project should be checked against manufacturer specifications before
  equipment is purchased or connected.
