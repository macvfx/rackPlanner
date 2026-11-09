import Foundation

struct DeviceTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let category: DeviceCategory
    let ports: [DevicePort]
    let estimatedWatts: Double?
    let upsOutletCount: Int
    let shelfUsage: ShelfUsage

    init(
        id: String,
        name: String,
        category: DeviceCategory,
        ports: [DevicePort],
        estimatedWatts: Double?,
        upsOutletCount: Int,
        shelfUsage: ShelfUsage? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.ports = ports
        self.estimatedWatts = estimatedWatts
        self.upsOutletCount = upsOutletCount
        self.shelfUsage = shelfUsage ?? Self.defaultShelfUsage(for: category)
    }

    private static func defaultShelfUsage(for category: DeviceCategory) -> ShelfUsage {
        switch category {
        case .kvm, .adapter, .storage, .iot, .peripheral: .sharedAccessory
        case .computer, .networking, .power: .dedicated
        }
    }

    func instantiate(named customName: String? = nil) -> PlannedDevice {
        PlannedDevice(
            name: customName ?? name,
            category: category,
            templateID: id,
            shelfUsage: shelfUsage,
            ports: ports.map {
                var port = $0
                port.id = UUID()
                return port
            },
            estimatedWatts: estimatedWatts,
            upsOutletCount: upsOutletCount
        )
    }
}

enum DeviceCatalog {
    private static let allEthernet: [EthernetSpeed] = [.mb100, .gb1, .gb2_5, .gb5, .gb10]

    static let templates: [DeviceTemplate] = [
        DeviceTemplate(id: "mac-mini", name: "Mac mini", category: .computer, ports: [
            .network("Built-in Ethernet", purpose: .lan, speeds: [.mb100, .gb1]),
            .peripheral("Thunderbolt 1", kind: .thunderbolt),
            .peripheral("Thunderbolt 2", kind: .thunderbolt),
            .peripheral("HDMI", kind: .hdmi),
            .peripheral("AC", kind: .acPower)
        ], estimatedWatts: 65, upsOutletCount: 0),
        DeviceTemplate(id: "raspberry-pi", name: "Raspberry Pi", category: .computer, ports: [
            .network("Ethernet", purpose: .lan, speeds: [.mb100, .gb1]),
            .peripheral("USB", kind: .usbA),
            .peripheral("HDMI", kind: .hdmi),
            DevicePort(name: "USB-C Power", kind: .usbC, role: .power)
        ], estimatedWatts: 15, upsOutletCount: 0),
        DeviceTemplate(id: "generic-kvm", name: "Generic KVM", category: .kvm, ports: [
            .network("LAN", purpose: .lan, speeds: [.mb100, .gb1]),
            .peripheral("HDMI Input", kind: .hdmi),
            .peripheral("USB Control", kind: .usbC),
            DevicePort(name: "Power", kind: .usbC, role: .power)
        ], estimatedWatts: 5, upsOutletCount: 0),
        DeviceTemplate(id: "ssd", name: "External SSD", category: .storage, ports: [
            .peripheral("USB-C", kind: .usbC)
        ], estimatedWatts: 8, upsOutletCount: 0),
        DeviceTemplate(id: "time-machine", name: "Time Machine Drive", category: .storage, ports: [
            .peripheral("USB", kind: .usbC), .peripheral("AC", kind: .acPower)
        ], estimatedWatts: 18, upsOutletCount: 0),
        DeviceTemplate(id: "tb-dock", name: "Thunderbolt Dock", category: .adapter, ports: [
            .peripheral("Host", kind: .thunderbolt),
            .peripheral("Thunderbolt Out", kind: .thunderbolt),
            .peripheral("USB-A 1", kind: .usbA),
            .peripheral("USB-A 2", kind: .usbA),
            .network("Ethernet", purpose: .lan, speeds: [.mb100, .gb1]),
            .peripheral("AC", kind: .acPower)
        ], estimatedWatts: 80, upsOutletCount: 0),
        DeviceTemplate(id: "tb-10g", name: "Thunderbolt 10 Gb Adapter", category: .adapter, ports: [
            .peripheral("Thunderbolt", kind: .thunderbolt),
            .network("10 Gb Ethernet", purpose: .production, speeds: allEthernet, selected: .gb10)
        ], estimatedWatts: 8, upsOutletCount: 0),
        DeviceTemplate(id: "usb-2-5g", name: "USB 2.5 Gb Adapter", category: .adapter, ports: [
            .peripheral("USB", kind: .usbC),
            .network("2.5 Gb Ethernet", purpose: .production, speeds: [.mb100, .gb1, .gb2_5], selected: .gb2_5)
        ], estimatedWatts: 4, upsOutletCount: 0),
        DeviceTemplate(id: "switch-5-1g", name: "5-port 1 Gb Switch", category: .networking, ports:
            (1...5).map { .network("Port \($0)", role: .switchAccess, purpose: .lan, speeds: [.mb100, .gb1]) } +
            [.peripheral("AC", kind: .acPower)], estimatedWatts: 12, upsOutletCount: 0),
        DeviceTemplate(id: "switch-4-2-5g-2-10g", name: "4-port 2.5 Gb + 2-port 10 Gb Switch", category: .networking, ports:
            (1...4).map { .network("2.5G Port \($0)", role: .switchAccess, purpose: .production, speeds: [.mb100, .gb1, .gb2_5]) } +
            (1...2).map { .network("10G Uplink \($0)", kind: .sfp, role: .uplink, purpose: .production, speeds: [.gb1, .gb10]) } +
            [.peripheral("AC", kind: .acPower)], estimatedWatts: 35, upsOutletCount: 0),
        DeviceTemplate(id: "nas", name: "NAS", category: .storage, ports: [
            .network("Management LAN", purpose: .lan, speeds: [.mb100, .gb1]),
            .network("Production", purpose: .production, speeds: allEthernet, selected: .gb10),
            .peripheral("USB Expansion", kind: .usbC),
            .peripheral("AC", kind: .acPower)
        ], estimatedWatts: 90, upsOutletCount: 0, shelfUsage: .dedicated),
        DeviceTemplate(id: "printer", name: "Printer", category: .peripheral, ports: [
            .network("LAN", purpose: .lan, speeds: [.mb100, .gb1]),
            .network("Wi-Fi", kind: .wifi, purpose: .wifi, speeds: [.mb100]),
            .peripheral("USB", kind: .usbA), .peripheral("AC", kind: .acPower)
        ], estimatedWatts: 45, upsOutletCount: 0),
        DeviceTemplate(id: "iot-hub", name: "IoT Sensor Hub", category: .iot, ports: [
            .network("LAN", purpose: .lan, speeds: [.mb100, .gb1]), .peripheral("AC", kind: .acPower)
        ], estimatedWatts: 8, upsOutletCount: 0),
        DeviceTemplate(id: "solar-hub", name: "Solar Hub", category: .iot, ports: [
            .network("LAN", purpose: .lan, speeds: [.mb100, .gb1]), .peripheral("AC", kind: .acPower)
        ], estimatedWatts: 8, upsOutletCount: 0),
        DeviceTemplate(id: "router", name: "WAN Modem / Router", category: .networking, ports: [
            .network("WAN", kind: .wan, purpose: .wan, speeds: [.gb1, .gb2_5]),
            .network("LAN 1", role: .switchAccess, purpose: .lan, speeds: [.mb100, .gb1]),
            .network("LAN 2", role: .switchAccess, purpose: .lan, speeds: [.mb100, .gb1]),
            .network("LAN 3", role: .switchAccess, purpose: .lan, speeds: [.mb100, .gb1]),
            .network("LAN 4", role: .switchAccess, purpose: .lan, speeds: [.mb100, .gb1]),
            .network("Wi-Fi", kind: .wifi, role: .switchAccess, purpose: .wifi, speeds: [.gb1]),
            .peripheral("AC", kind: .acPower)
        ], estimatedWatts: 25, upsOutletCount: 0),
        DeviceTemplate(id: "ups", name: "UPS", category: .power, ports: [
            .peripheral("AC Input", kind: .acPower)
        ], estimatedWatts: nil, upsOutletCount: 8),
        DeviceTemplate(id: "generic-computer", name: "Generic Computer", category: .computer, ports: [
            .network("Ethernet", purpose: .lan, speeds: [.mb100, .gb1]),
            .peripheral("USB", kind: .usbC), .peripheral("AC", kind: .acPower)
        ], estimatedWatts: nil, upsOutletCount: 0),
        DeviceTemplate(id: "generic-switch", name: "Generic Switch", category: .networking, ports:
            (1...8).map { .network("Port \($0)", role: .switchAccess, purpose: .lan, speeds: [.mb100, .gb1]) } +
            [.peripheral("AC", kind: .acPower)], estimatedWatts: nil, upsOutletCount: 0),
        // Generic blocks: one per category, for equipment with no named preset.
        // Rename the device and edit its ports, speeds, and notes after adding it.
        DeviceTemplate(id: "generic-network-device", name: "Generic Network Device", category: .networking, ports: [
            .network("Ethernet", purpose: .lan, speeds: [.mb100, .gb1]),
            .peripheral("AC", kind: .acPower)
        ], estimatedWatts: nil, upsOutletCount: 0),
        DeviceTemplate(id: "generic-storage", name: "Generic Storage", category: .storage, ports: [
            .peripheral("USB-C", kind: .usbC), .peripheral("AC", kind: .acPower)
        ], estimatedWatts: nil, upsOutletCount: 0),
        DeviceTemplate(id: "generic-adapter", name: "Generic Adapter / Dock", category: .adapter, ports: [
            .peripheral("Host", kind: .usbC), .peripheral("Port", kind: .usbA)
        ], estimatedWatts: nil, upsOutletCount: 0),
        DeviceTemplate(id: "generic-iot", name: "Generic IoT Device", category: .iot, ports: [
            .network("LAN", purpose: .lan, speeds: [.mb100, .gb1]), .peripheral("Power", kind: .acPower)
        ], estimatedWatts: nil, upsOutletCount: 0),
        DeviceTemplate(id: "generic-power", name: "Generic Power Device", category: .power, ports: [
            .peripheral("AC Input", kind: .acPower)
        ], estimatedWatts: nil, upsOutletCount: 0),
        DeviceTemplate(id: "generic-peripheral", name: "Generic Peripheral", category: .peripheral, ports: [
            .peripheral("USB", kind: .usbA), .peripheral("AC", kind: .acPower)
        ], estimatedWatts: nil, upsOutletCount: 0)
    ]

    static func template(id: String) -> DeviceTemplate? { templates.first { $0.id == id } }

    static func sampleProject() -> RackPlanProject {
        let rack = EquipmentRack(name: "Example Home Rack", format: .rack19, shelfCount: 15)
        var devices: [PlannedDevice] = []

        for number in 1...6 {
            var mac = template(id: "mac-mini")!.instantiate(named: "Mac mini \(number)")
            mac.modelLine = "Mac mini"
            mac.modelIdentifier = "Macmini9,1"
            mac.hostname = "mac-mini-\(number).example.invalid"
            mac.hostnameAccessMethod = .screenSharing
            mac.networkAddresses = [
                DeviceNetworkAddress(
                    label: "Example LAN",
                    kind: .lan,
                    address: "192.0.2.\(10 + number)",
                    accessMethod: .screenSharing
                )
            ]
            mac.rackID = rack.id
            mac.shelfIndex = number - 1
            mac.requiresUPS = true
            devices.append(mac)
        }

        if let firstMac = devices.first {
            var kvm = template(id: "generic-kvm")!.instantiate(named: "JetKVM for Mac mini 1")
            kvm.modelLine = "JetKVM"
            kvm.hostname = "jetkvm-1.example.invalid"
            kvm.hostnameAccessMethod = .https
            kvm.networkAddresses = [
                DeviceNetworkAddress(
                    label: "Example LAN",
                    kind: .lan,
                    address: "192.0.2.50",
                    accessMethod: .https
                ),
                DeviceNetworkAddress(
                    label: "Example VPN / Tailscale",
                    kind: .vpn,
                    address: "198.51.100.50",
                    accessMethod: .https
                )
            ]
            kvm.rackID = rack.id
            kvm.shelfIndex = 0
            kvm.hostConnections = [
                HostConnection(
                    localPortID: kvm.ports.first { $0.kind == .hdmi }?.id,
                    hostDeviceID: firstMac.id,
                    hostPortID: firstMac.ports.first { $0.kind == .hdmi }?.id
                ),
                HostConnection(
                    localPortID: kvm.ports.first { $0.name == "USB Control" }?.id,
                    hostDeviceID: firstMac.id,
                    hostPortID: firstMac.ports.first { $0.kind == .thunderbolt }?.id
                )
            ]
            devices.append(kvm)

            var drive = template(id: "ssd")!.instantiate(named: "Example Work SSD")
            drive.rackID = rack.id
            drive.shelfIndex = 1
            drive.hostConnections = [
                HostConnection(
                    localPortID: drive.ports.first?.id,
                    hostDeviceID: devices[1].id,
                    hostPortID: devices[1].ports.first { $0.kind == .thunderbolt }?.id
                )
            ]
            devices.append(drive)
        }

        let placements: [(String, String, Int, Bool)] = [
            ("router", "Router", 6, true),
            ("switch-5-1g", "LAN Switch", 7, true),
            ("switch-4-2-5g-2-10g", "Production Switch", 8, true),
            ("nas", "Example NAS", 9, true),
            ("ups", "Main UPS", 10, false)
        ]
        for (templateID, name, shelf, protected) in placements {
            var device = template(id: templateID)!.instantiate(named: name)
            device.rackID = rack.id
            device.shelfIndex = shelf
            device.requiresUPS = protected
            devices.append(device)
        }

        return RackPlanProject(name: "Example Home Rack", racks: [rack], devices: devices)
    }
}
