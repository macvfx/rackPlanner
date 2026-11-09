# Rack Planner User Guide

This is the canonical operating guide for version 0.2.

## Requirements

Rack Planner requires macOS 15 or newer. It is a native document-based app and
does not require an account or network connection for planning.

## Start a plan

Choose **File > New**. A new document opens with a fictional home-rack example.
Use the **Blank Plan** toolbar button when starting from an empty inventory.
Save normally; Rack Planner projects use the `.rackplan` document type.

## Add and place equipment

Right-click a card in Rack view for **Show in Inspector**, **Duplicate**, and
**Delete…**. A duplicate is named "… copy" and lands on the nearest empty shelf below
the original (then above), or in Unassigned if the rack is full. It keeps the model,
ports, speeds, power, and notes, but its hostname, addresses, and host connections are
cleared so you can set them for the new device. Delete asks first and also removes
connections that used the device.

Each device is either **primary** (it owns its shelf) or **shared** (it rides on a
primary device's shelf, like a KVM, dock, or drive). Only shared devices are marked
on their cards; change the setting under **Shelf use** in the inspector.

The left sidebar contains the device library. Click the plus button to add a
device to the unassigned inventory, or drag a preset directly onto an empty
shelf. In Rack view, drag an existing device card to another empty shelf or to
the Unassigned area.

To reorder the rack, drag a primary device onto a shelf that already holds
another primary device: the two shelves swap places, and each device's shared
accessories (KVM, dock, drive) move with it. This works between racks too. To insert
instead of swap, drop the device in the thin gap between two shelves (a blue bar
shows where it will land): the shelves below slide down by one, up to the nearest
empty shelf, or the shelves above slide up if there is none below. Drag a
shared accessory by itself to move only that accessory. A primary device dragged
from Unassigned will not displace one that is already on a shelf.

Each device card summarises its data ports by type, for example
"5 network · 2 Thunderbolt · 1 HDMI". Network counts Ethernet, SFP, and WAN ports.
Wi-Fi radios and power inlets are not counted as ports.

Every category ends with a **Generic** block (for example Generic Storage or
Generic KVM) for equipment that has no named preset. Add one, rename it, set the
model line, and edit its ports, speeds, and notes. For a JetKVM, add Generic KVM
and name it JetKVM.

A shelf accepts one primary device and multiple shared accessories. Computers,
switches, and UPS units default to primary placement. KVMs, adapters, external
drives, IoT hubs, and peripherals default to shared placement. Use **Shelf use**
in the inspector to override that choice.

## Edit a device

Select a device card. The inspector lets you:

- rename it;
- record a model line and model identifier;
- assign a rack and shelf;
- request UPS protection;
- enter optional estimated watts;
- change the network and planned speed for applicable ports.

Switch access and uplink ports contribute capacity. Endpoint ports contribute
demand. USB, Thunderbolt, HDMI, storage, and power ports are inventoried but do
not contribute Ethernet capacity.

## Connect an accessory to a host

Select the KVM, drive, dock, or adapter and open **Host connections**. Add a
connection, then choose:

1. the accessory's local port;
2. the Mac or other host device;
3. the compatible host port.

Add separate connections for separate cables. A KVM such as a JetKVM normally has one HDMI
connection and one USB control connection to the same host. The accessory's Rack
card shows its destination; selecting the host shows every attached accessory.

## Add clickable remote access

Select a device and open **Quick access**. Enter an optional hostname and choose
its action. Add as many address entries as needed and classify each as **LAN IP**,
**VPN / Tailscale**, or **Other address**. Available actions are:

- Web (HTTP)
- Web (HTTPS)
- Screen Sharing (VNC)
- SSH
- No link

When the value is valid, an **Open** link appears directly below it. For example,
Screen Sharing turns `mac-1.example.invalid` into
`vnc://mac-1.example.invalid`; HTTPS turns the fictional documentation address
`192.0.2.50` into `https://192.0.2.50`. A complete URL with its own scheme, port,
or path is preserved.

Activating a link leaves Rack Planner and asks macOS to open the registered app:
normally the default browser for HTTP/HTTPS, Screen Sharing for VNC, or a
registered SSH handler. Rack Planner does not test reachability or authenticate.

## Read the network summary

Open **Network** view. Each network card shows endpoint demand, usable capacity,
uplink reservation, 20% target, and shortage. A green result has enough total
capacity at every speed; an amber result requires attention. Speed is checked
per tier: four 10 Gb endpoints need four usable ports that reach 10 Gb, however
many slower ports the switches have.

The recommendation is deliberately abstract—for example, “add 3 ports capable
of at least 2.5 Gb.” Confirm that real switch ports support the required media,
negotiation speeds, and network design.

## Read shelf and UPS summaries

Open **Overview** for total devices, shelf use, network shortages, UPS-protected
devices, UPS outlets, and optional planned watts.

## Export CSV

Choose the **Export CSVs** toolbar button, select a folder, and Rack Planner writes:

- `devices.csv`
- `ports.csv`
- `connections.csv`
- `access.csv`
- `network-requirements.csv`
- `power.csv`

If the folder already holds files with those names, Rack Planner asks before
replacing them. Text beginning with `=`, `+`, `-`, or `@` is prefixed with an
apostrophe so spreadsheets show it as text instead of running it as a formula.

## In-app Help and About

- Choose **Help > Rack Planner Help** or press Command-Question Mark for the
  topic-based quick guide.
- Choose **Help > Full User Guide** to open this guide in the default browser.
- Choose **Rack Planner > About Rack Planner** for the installed version, build,
  privacy summary, User Guide, and [code.matx.ca](https://code.matx.ca) link.
- Choose **Help > Report an Issue** to open the public issue tracker.

External support pages are contacted only when you choose one of these links.

## Privacy

Rack Planner works locally. It does not:

- require or create an account;
- upload projects, hostnames, addresses, notes, or equipment details;
- collect analytics, usage information, or diagnostics;
- include an automatic updater, cloud service, or background service; or
- scan the local network or test whether entered devices are reachable.

Quick-access links for HTTP, HTTPS, Screen Sharing/VNC, and SSH contact the
entered destination only when you click **Open**. Only http, https, vnc, and ssh
links are opened; any other scheme in a plan file is ignored. The links to
[code.matx.ca](https://code.matx.ca), the User Guide, repository, and issue
tracker likewise open only when selected.

Saved `.rackplan` documents and exported CSV files may contain sensitive
network information, including hostnames, IP addresses, VPN addresses,
equipment notes, and topology details. Review these files before sharing them
or attaching them to an issue. The examples shipped in the app and
documentation use fictional names and documentation-only IP address ranges.

## Troubleshooting

- If a device does not affect network demand, confirm that its port role is an
  endpoint and that it is assigned to the intended network.
- If a switch has less usable capacity than expected, check the inferred uplink
  reservation and the spare-port percentage.
- If an accessory connection cannot select a host port, confirm that the local
  and host ports use the same connection type.
- If a quick-access link does not open, confirm the address and action, then
  verify that macOS has an app registered for that URL scheme.
- If a CSV does not appear, choose a writable destination folder and check for
  existing files with the same export names.

## Known limitations

- USB, Thunderbolt, and HDMI host connections have explicit endpoints. Ethernet,
  power, and arbitrary graphical cable routing remain capacity assignments.
- General cable quantities and lengths are not yet exported.
- Model identifiers are stored as entered; automatic specification lookup is not
  yet provided.
- Hostnames and addresses are stored locally in the project. Link availability
  does not prove that the device is reachable or that its service is secure.
- Switch uplinks are inferred from the number of providers on a network.
- VLAN trunks, LACP, redundant fabrics, PoE, UPS runtime, and exact rack units
  are not modelled.
- PDF and image exports are planned but not shipped.

## More information

- [Rack Planner source](https://github.com/macvfx/rackPlanner)
- [Report an issue](https://github.com/macvfx/rackPlanner/issues)
- [code.matx.ca](https://code.matx.ca)
