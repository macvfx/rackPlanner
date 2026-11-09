import Foundation

enum CSVExporter {
    static func export(project: RackPlanProject, to directory: URL) throws {
        let files = [
            "devices.csv": devices(project),
            "ports.csv": ports(project),
            "connections.csv": connections(project),
            "access.csv": access(project),
            "network-requirements.csv": networks(project),
            "power.csv": power(project)
        ]
        for (name, content) in files {
            try content.write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
    }

    static func devices(_ project: RackPlanProject) -> String {
        let header = "device,category,model_line,model_identifier,hostname,hostname_action,rack,shelf,shelf_use,ups_protected,estimated_watts,notes"
        let rows = project.devices.map { device in
            let rack = project.racks.first { $0.id == device.rackID }
            return [
                csv(device.name), csv(device.category.rawValue), csv(device.modelLine), csv(device.modelIdentifier),
                csv(device.hostname), csv(device.hostnameAccessMethod.rawValue), csv(rack?.name ?? "Unassigned"),
                device.shelfIndex.map { "\($0 + 1)" } ?? "",
                csv(device.shelfUsage.rawValue), device.requiresUPS ? "yes" : "no",
                device.estimatedWatts.map { "\($0)" } ?? "", csv(device.notes)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    static func access(_ project: RackPlanProject) -> String {
        let header = "device,label,address_type,address,action,url"
        let rows = project.devices.flatMap { device in
            var entries: [[String]] = []
            if !device.hostname.isEmpty {
                entries.append([
                    device.name, "Hostname", "Hostname", device.hostname,
                    device.hostnameAccessMethod.rawValue,
                    device.hostnameAccessMethod.url(for: device.hostname)?.absoluteString ?? ""
                ])
            }
            entries += device.networkAddresses.map { address in
                [
                    device.name, address.label, address.kind.rawValue, address.address,
                    address.accessMethod.rawValue,
                    address.accessMethod.url(for: address.address)?.absoluteString ?? ""
                ]
            }
            return entries.map { $0.map(csv).joined(separator: ",") }
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    static func connections(_ project: RackPlanProject) -> String {
        let header = "accessory,accessory_port,connector,host,host_port"
        let rows = project.devices.flatMap { device in
            device.hostConnections.map { connection in
                let local = device.ports.first { $0.id == connection.localPortID }
                let host = project.devices.first { $0.id == connection.hostDeviceID }
                let hostPort = host?.ports.first { $0.id == connection.hostPortID }
                return [
                    csv(device.name), csv(local?.name ?? ""), csv(local?.kind.rawValue ?? ""),
                    csv(host?.name ?? ""), csv(hostPort?.name ?? "")
                ].joined(separator: ",")
            }
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    static func ports(_ project: RackPlanProject) -> String {
        let header = "device,port,connector,role,network,selected_speed,maximum_speed"
        let rows = project.devices.flatMap { device in
            device.ports.map { port in
                [
                    csv(device.name), csv(port.name), csv(port.kind.rawValue), csv(port.role.rawValue),
                    csv(port.network.rawValue), csv(port.selectedSpeed?.label ?? ""),
                    csv(port.maximumSpeed?.label ?? "")
                ].joined(separator: ",")
            }
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    static func networks(_ project: RackPlanProject) -> String {
        let header = "network,endpoints,providers,gross_ports,uplink_ports,usable_ports,target_with_spare,shortage,recommendation"
        let rows = PlanningEngine.networkResults(for: project).map { result in
            [
                csv(result.network.rawValue), String(result.endpointDemand), String(result.providerCount),
                String(result.grossCapacity), String(result.reservedUplinkPorts), String(result.usableCapacity),
                String(result.targetCapacity), String(result.shortage), csv(result.recommendation)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    static func power(_ project: RackPlanProject) -> String {
        let result = PlanningEngine.powerResult(for: project)
        return "protected_devices,ups_outlets,outlet_shortage,planned_watts\n" +
            "\(result.protectedDevices),\(result.upsOutlets),\(result.outletShortage),\(result.plannedWatts)\n"
    }

    static let fileNames = [
        "devices.csv", "ports.csv", "connections.csv", "access.csv", "network-requirements.csv", "power.csv"
    ]

    /// Quotes a cell. A leading `=`, `+`, `-`, `@`, tab or return would be run as a formula by
    /// Excel and Numbers, so such text gets a leading apostrophe.
    static func csv(_ value: String) -> String {
        var text = value
        if let first = text.unicodeScalars.first, "=+-@\t\r".unicodeScalars.contains(first) {
            text = "'" + text
        }
        return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
