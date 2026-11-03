# Architecture

## Structure

```text
RackPlannerApp / RackPlanDocument
               │
               ▼
         RackPlanProject
       ┌───────┼────────┐
       ▼       ▼        ▼
     Racks   Devices  Settings
               │
               ▼
             Ports
               │
               ▼
         PlanningEngine
       ┌───────┼────────┐
       ▼       ▼        ▼
    Network  Shelves   Power
    results  results   results
```

`RackPlanProject` and its child values are Codable value types. The document
wrapper reads and writes JSON through `FileDocument`. SwiftUI views mutate the
document binding, so Rack and Network views always represent the same inventory.

`PlannedDevice.hostConnections` stores explicit local-port, host-device, and
host-port identifiers for USB, Thunderbolt, and HDMI attachments. The accessory
owns the relationship; deleting a host removes inbound relationships. Shelf
occupancy counts unique rack/shelf coordinates, while placement validation allows
one `.dedicated` device plus multiple `.sharedAccessory` devices.

`DeviceNetworkAddress` stores a user label, LAN/VPN/other classification,
address, and access method. `RemoteAccessMethod` resolves a safe local URL for
SwiftUI `Link`: `http`, `https`, `vnc`, or `ssh`. A complete URL entered by the
user is preserved. No connection is made until the user activates the link.

`DeviceCatalog` is the single source for built-in presets. A preset creates a
new device instance with fresh identifiers.

`PlanningEngine` is UI-independent and covered by unit tests. It treats endpoint
ports as demand and switch-access/uplink ports as capacity, grouped by network.
It deducts the minimum ports needed to connect multiple provider devices and
then applies the project's spare-capacity percentage.

`CSVExporter` serializes six inspectable schedules. It does not mutate the
project.

## Persistence compatibility

The root document contains a schema version. Future migrations should decode
older schemas into the current value model and preserve unknown future data
where practical.
