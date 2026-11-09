import Foundation

extension RackPlanProject {
    /// Copies a device, as from the right-click menu in Rack view. Returns the copy's id.
    ///
    /// The copy gets new device and port identifiers and a " copy" name. Its hostname and
    /// addresses are cleared (two devices cannot share them) and so are its host connections
    /// (the copy has to be wired to its own host ports). Everything else is kept: model,
    /// ports, speeds, power, UPS settings, and notes.
    ///
    /// It lands on the nearest shelf below the original that holds nothing (then above it, in
    /// the same rack), or in Unassigned when the rack has no empty shelf.
    @discardableResult
    mutating func duplicateDevice(_ id: UUID) -> UUID? {
        guard let original = devices.first(where: { $0.id == id }) else { return nil }
        var copy = original
        copy.id = UUID()
        copy.name = original.name + " copy"
        copy.hostname = ""
        copy.hostnameAccessMethod = .none
        copy.networkAddresses = []
        copy.hostConnections = []
        copy.ports = original.ports.map { port in
            var fresh = port
            fresh.id = UUID()
            return fresh
        }

        copy.rackID = nil
        copy.shelfIndex = nil
        if let rackID = original.rackID, let shelf = original.shelfIndex,
           let rack = racks.first(where: { $0.id == rackID }) {
            let used = Set(devices.compactMap { $0.rackID == rackID ? $0.shelfIndex : nil })
            let below = (shelf + 1..<max(shelf + 1, rack.shelfCount)).first { !used.contains($0) }
            let above = (0..<shelf).reversed().first { !used.contains($0) }
            if let target = below ?? above {
                copy.rackID = rackID
                copy.shelfIndex = target
            }
        }
        devices.append(copy)
        return copy.id
    }

    /// Removes a device and every host connection that points at it.
    mutating func removeDevice(_ id: UUID) {
        for index in devices.indices {
            devices[index].hostConnections.removeAll { $0.hostDeviceID == id }
        }
        devices.removeAll { $0.id == id }
    }
}
