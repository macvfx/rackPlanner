import Foundation

struct NetworkPlanResult: Identifiable, Equatable {
    var id: NetworkPurpose { network }
    let network: NetworkPurpose
    let endpointDemand: Int
    let providerCount: Int
    let grossCapacity: Int
    let reservedUplinkPorts: Int
    let usableCapacity: Int
    let targetCapacity: Int
    let shortage: Int
    let fastestEndpoint: EthernetSpeed?
    let fastestProvider: EthernetSpeed?

    var isAdequate: Bool {
        shortage == 0 && (fastestEndpoint == nil || (fastestProvider ?? .mb100) >= fastestEndpoint!)
    }

    var recommendation: String {
        if endpointDemand == 0 { return "No wired endpoints assigned." }
        if let endpoint = fastestEndpoint, let provider = fastestProvider, provider < endpoint {
            return "Add ports capable of at least \(endpoint.label); current providers top out at \(provider.label)."
        }
        if shortage > 0 {
            let speed = fastestEndpoint?.label ?? "the required speed"
            return "Add at least \(shortage) usable \(speed) port\(shortage == 1 ? "" : "s") after uplinks."
        }
        return "Capacity meets the configured spare-port target."
    }
}
struct ShelfPlanResult: Equatable {
    let total: Int
    let occupied: Int
    let unassigned: Int
    var free: Int { max(0, total - occupied) }
    var overflow: Int { max(0, occupied - total) }
}

struct PowerPlanResult: Equatable {
    let protectedDevices: Int
    let upsOutlets: Int
    let plannedWatts: Double
    var outletShortage: Int { max(0, protectedDevices - upsOutlets) }
}

enum PlanningEngine {
    static func networkResults(for project: RackPlanProject) -> [NetworkPlanResult] {
        NetworkPurpose.allCases
            .filter { $0 != .none && $0 != .wan && $0 != .wifi }
            .map { networkResult(for: $0, project: project) }
            .filter { $0.endpointDemand > 0 || $0.grossCapacity > 0 }
    }

    static func networkResult(for network: NetworkPurpose, project: RackPlanProject) -> NetworkPlanResult {
        let matchingPorts = project.devices.flatMap(\.ports).filter {
            $0.network == network && ($0.kind == .ethernet || $0.kind == .sfp)
        }
        let endpoints = matchingPorts.filter { $0.role == .endpoint }
        let capacityPorts = matchingPorts.filter { $0.role.providesCapacity }
        let providerIDs = project.devices.filter { device in
            device.ports.contains { port in
                port.network == network && port.role.providesCapacity &&
                    (port.kind == .ethernet || port.kind == .sfp)
            }
        }.map(\.id)
        let providerCount = Set(providerIDs).count
        let reserved = min(capacityPorts.count, max(0, providerCount - 1) * 2)
        let usable = max(0, capacityPorts.count - reserved)
        let spareMultiplier = 1 + Double(project.settings.sparePortPercentage) / 100
        let target = Int(ceil(Double(endpoints.count) * spareMultiplier))

        return NetworkPlanResult(
            network: network,
            endpointDemand: endpoints.count,
            providerCount: providerCount,
            grossCapacity: capacityPorts.count,
            reservedUplinkPorts: reserved,
            usableCapacity: usable,
            targetCapacity: target,
            shortage: max(0, target - usable),
            fastestEndpoint: endpoints.compactMap { $0.selectedSpeed ?? $0.maximumSpeed }.max(),
            fastestProvider: capacityPorts.compactMap(\.maximumSpeed).max()
        )
    }

    static func shelfResult(for project: RackPlanProject) -> ShelfPlanResult {
        let occupiedPositions = Set(project.devices.compactMap { device -> String? in
            guard let rack = device.rackID, let shelf = device.shelfIndex else { return nil }
            return "\(rack.uuidString):\(shelf)"
        })
        return ShelfPlanResult(
            total: project.racks.reduce(0) { $0 + $1.shelfCount },
            occupied: occupiedPositions.count,
            unassigned: project.devices.filter { $0.rackID == nil || $0.shelfIndex == nil }.count
        )
    }

    static func powerResult(for project: RackPlanProject) -> PowerPlanResult {
        PowerPlanResult(
            protectedDevices: project.devices.filter(\.requiresUPS).count,
            upsOutlets: project.devices.reduce(0) { $0 + $1.upsOutletCount },
            plannedWatts: project.devices.compactMap(\.estimatedWatts).reduce(0, +)
        )
    }
}
