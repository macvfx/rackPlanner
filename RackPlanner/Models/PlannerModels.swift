import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let rackPlan = UTType(exportedAs: "ca.macvfx.rackplanner.project", conformingTo: .json)
}
enum RackFormat: String, Codable, CaseIterable, Identifiable {
    case rack19 = "19-inch Rack"
    case rack10 = "10-inch Rack"
    case openShelf = "Open Shelving"

    var id: String { rawValue }
}

enum DeviceCategory: String, Codable, CaseIterable, Identifiable {
    case computer = "Computers"
    case networking = "Networking"
    case storage = "Storage"
    case kvm = "KVM"
    case adapter = "Adapters & Docks"
    case iot = "IoT"
    case power = "Power"
    case peripheral = "Peripherals"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .computer: "desktopcomputer"
        case .networking: "network"
        case .storage: "externaldrive"
        case .kvm: "rectangle.connected.to.line.below"
        case .adapter: "cable.connector"
        case .iot: "sensor"
        case .power: "bolt.fill"
        case .peripheral: "printer"
        }
    }
}

enum ShelfUsage: String, Codable, CaseIterable, Identifiable {
    case dedicated = "Dedicated shelf position"
    case sharedAccessory = "Shares a shelf"

    var id: String { rawValue }
}

enum AddressKind: String, Codable, CaseIterable, Identifiable {
    case lan = "LAN IP"
    case vpn = "VPN / Tailscale"
    case other = "Other address"

    var id: String { rawValue }
}

enum RemoteAccessMethod: String, Codable, CaseIterable, Identifiable {
    case none = "No link"
    case http = "Web (HTTP)"
    case https = "Web (HTTPS)"
    case screenSharing = "Screen Sharing (VNC)"
    case ssh = "SSH"

    var id: String { rawValue }

    var scheme: String? {
        switch self {
        case .none: nil
        case .http: "http"
        case .https: "https"
        case .screenSharing: "vnc"
        case .ssh: "ssh"
        }
    }

    var actionLabel: String {
        switch self {
        case .none: "Open"
        case .http, .https: "Open in Browser"
        case .screenSharing: "Open Screen Sharing"
        case .ssh: "Open SSH"
        }
    }

    var symbol: String {
        switch self {
        case .none: "link"
        case .http, .https: "safari"
        case .screenSharing: "rectangle.connected.to.line.below"
        case .ssh: "terminal"
        }
    }

    func url(for rawValue: String) -> URL? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if let existing = URL(string: value), existing.scheme != nil { return existing }
        guard let scheme else { return nil }
        let colonCount = value.filter { $0 == ":" }.count
        let destination = colonCount > 1 && !value.hasPrefix("[") ? "[\(value)]" : value
        return URL(string: "\(scheme)://\(destination)")
    }
}

struct DeviceNetworkAddress: Codable, Identifiable, Hashable {
    var id = UUID()
    var label: String
    var kind: AddressKind
    var address: String
    var accessMethod: RemoteAccessMethod
}

enum PortKind: String, Codable, CaseIterable, Identifiable {
    case ethernet = "RJ45 Ethernet"
    case sfp = "SFP / Fibre"
    case wifi = "Wi-Fi"
    case usbA = "USB-A"
    case usbC = "USB-C"
    case thunderbolt = "Thunderbolt"
    case hdmi = "HDMI"
    case storage = "Storage"
    case acPower = "AC Power"
    case wan = "WAN Handoff"

    var id: String { rawValue }
    var isNetwork: Bool { self == .ethernet || self == .sfp || self == .wifi || self == .wan }
}

enum PortRole: String, Codable, CaseIterable, Identifiable {
    case endpoint = "Endpoint"
    case switchAccess = "Switch Access"
    case uplink = "Uplink"
    case peripheral = "Peripheral"
    case power = "Power"

    var id: String { rawValue }
    var providesCapacity: Bool { self == .switchAccess || self == .uplink }
}

enum NetworkPurpose: String, Codable, CaseIterable, Identifiable {
    case lan = "LAN"
    case production = "Production LAN"
    case wifi = "Wi-Fi"
    case wan = "WAN"
    case management = "Management"
    case none = "Not Assigned"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .lan: .blue
        case .production: .purple
        case .wifi: .mint
        case .wan: .orange
        case .management: .indigo
        case .none: .gray
        }
    }
}

enum EthernetSpeed: Double, Codable, CaseIterable, Identifiable, Comparable {
    case mb100 = 0.1
    case gb1 = 1
    case gb2_5 = 2.5
    case gb5 = 5
    case gb10 = 10
    case gb25 = 25

    var id: Double { rawValue }
    var label: String { rawValue < 1 ? "100 Mb" : "\(rawValue.formatted(.number.precision(.fractionLength(0...1)))) Gb" }
    static func < (lhs: EthernetSpeed, rhs: EthernetSpeed) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct DevicePort: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var kind: PortKind
    var role: PortRole
    var network: NetworkPurpose = .none
    var supportedSpeeds: [EthernetSpeed] = []
    var selectedSpeed: EthernetSpeed?

    var maximumSpeed: EthernetSpeed? { supportedSpeeds.max() }

    static func network(
        _ name: String,
        kind: PortKind = .ethernet,
        role: PortRole = .endpoint,
        purpose: NetworkPurpose,
        speeds: [EthernetSpeed],
        selected: EthernetSpeed? = nil
    ) -> DevicePort {
        DevicePort(
            name: name,
            kind: kind,
            role: role,
            network: purpose,
            supportedSpeeds: speeds,
            selectedSpeed: selected ?? speeds.max()
        )
    }

    static func peripheral(_ name: String, kind: PortKind) -> DevicePort {
        DevicePort(name: name, kind: kind, role: kind == .acPower ? .power : .peripheral)
    }
}

struct HostConnection: Codable, Identifiable, Hashable {
    var id = UUID()
    var localPortID: UUID?
    var hostDeviceID: UUID?
    var hostPortID: UUID?
}

struct PlannedDevice: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var category: DeviceCategory
    var templateID: String?
    var modelLine: String
    var modelIdentifier: String
    var hostname: String
    var hostnameAccessMethod: RemoteAccessMethod
    var networkAddresses: [DeviceNetworkAddress]
    var rackID: UUID?
    var shelfIndex: Int?
    var shelfUsage: ShelfUsage
    var ports: [DevicePort]
    var hostConnections: [HostConnection]
    var estimatedWatts: Double?
    var requiresUPS = false
    var upsOutletCount = 0
    var notes = ""

    var providesNetworkCapacity: Bool { ports.contains { $0.role.providesCapacity } }

    init(
        id: UUID = UUID(),
        name: String,
        category: DeviceCategory,
        templateID: String? = nil,
        modelLine: String = "",
        modelIdentifier: String = "",
        hostname: String = "",
        hostnameAccessMethod: RemoteAccessMethod = .none,
        networkAddresses: [DeviceNetworkAddress] = [],
        rackID: UUID? = nil,
        shelfIndex: Int? = nil,
        shelfUsage: ShelfUsage = .dedicated,
        ports: [DevicePort],
        hostConnections: [HostConnection] = [],
        estimatedWatts: Double? = nil,
        requiresUPS: Bool = false,
        upsOutletCount: Int = 0,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.templateID = templateID
        self.modelLine = modelLine
        self.modelIdentifier = modelIdentifier
        self.hostname = hostname
        self.hostnameAccessMethod = hostnameAccessMethod
        self.networkAddresses = networkAddresses
        self.rackID = rackID
        self.shelfIndex = shelfIndex
        self.shelfUsage = shelfUsage
        self.ports = ports
        self.hostConnections = hostConnections
        self.estimatedWatts = estimatedWatts
        self.requiresUPS = requiresUPS
        self.upsOutletCount = upsOutletCount
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, category, templateID, modelLine, modelIdentifier, hostname
        case hostnameAccessMethod, networkAddresses, rackID, shelfIndex
        case shelfUsage, ports, hostConnections, estimatedWatts, requiresUPS, upsOutletCount, notes
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try values.decode(String.self, forKey: .name)
        category = try values.decode(DeviceCategory.self, forKey: .category)
        templateID = try values.decodeIfPresent(String.self, forKey: .templateID)
        modelLine = try values.decodeIfPresent(String.self, forKey: .modelLine) ?? ""
        modelIdentifier = try values.decodeIfPresent(String.self, forKey: .modelIdentifier) ?? ""
        hostname = try values.decodeIfPresent(String.self, forKey: .hostname) ?? ""
        hostnameAccessMethod = try values.decodeIfPresent(RemoteAccessMethod.self, forKey: .hostnameAccessMethod) ?? .none
        networkAddresses = try values.decodeIfPresent([DeviceNetworkAddress].self, forKey: .networkAddresses) ?? []
        rackID = try values.decodeIfPresent(UUID.self, forKey: .rackID)
        shelfIndex = try values.decodeIfPresent(Int.self, forKey: .shelfIndex)
        shelfUsage = try values.decodeIfPresent(ShelfUsage.self, forKey: .shelfUsage) ?? .dedicated
        ports = try values.decode([DevicePort].self, forKey: .ports)
        hostConnections = try values.decodeIfPresent([HostConnection].self, forKey: .hostConnections) ?? []
        estimatedWatts = try values.decodeIfPresent(Double.self, forKey: .estimatedWatts)
        requiresUPS = try values.decodeIfPresent(Bool.self, forKey: .requiresUPS) ?? false
        upsOutletCount = try values.decodeIfPresent(Int.self, forKey: .upsOutletCount) ?? 0
        notes = try values.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

struct EquipmentRack: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var format: RackFormat
    var shelfCount: Int
    var notes = ""
}

struct PlannerSettings: Codable, Hashable {
    var sparePortPercentage = 20
}

struct RackPlanProject: Codable, Hashable {
    var schemaVersion = 3
    var name: String
    var racks: [EquipmentRack]
    var devices: [PlannedDevice]
    var settings = PlannerSettings()

    static var blank: RackPlanProject {
        RackPlanProject(
            name: "Untitled Rack Plan",
            racks: [EquipmentRack(name: "Main Rack", format: .rack19, shelfCount: 15)],
            devices: []
        )
    }

    static var sample: RackPlanProject { DeviceCatalog.sampleProject() }
}

struct RackPlanDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.rackPlan, .json] }
    var project: RackPlanProject

    init(project: RackPlanProject = .sample) {
        self.project = project
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        project = try JSONDecoder().decode(RackPlanProject.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(project))
    }
}
