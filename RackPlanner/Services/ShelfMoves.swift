import Foundation

extension RackPlanProject {
    /// Moves a device to a shelf, as when it is dragged in Rack view.
    ///
    /// - A shared accessory (KVM, dock, drive) moves by itself and may land on any shelf.
    /// - A dedicated device that is already on a shelf moves together with the accessories
    ///   sharing that shelf. If the target shelf holds another dedicated device, the two
    ///   shelves swap places, accessories included.
    /// - A dedicated device coming from Unassigned only goes onto a shelf with no dedicated
    ///   device, so nothing is displaced silently.
    ///
    /// Returns false, changing nothing, when the move is not allowed.
    @discardableResult
    mutating func moveDevice(_ id: UUID, toRack rackID: UUID, shelf: Int) -> Bool {
        guard racks.contains(where: { $0.id == rackID }),
              let index = devices.firstIndex(where: { $0.id == id }) else { return false }
        let device = devices[index]

        func isAt(_ other: PlannedDevice, _ rack: UUID?, _ position: Int?) -> Bool {
            other.rackID == rack && other.shelfIndex == position && rack != nil
        }

        guard device.shelfUsage == .dedicated else {
            devices[index].rackID = rackID
            devices[index].shelfIndex = shelf
            return true
        }

        let targetHasDedicated = devices.contains {
            $0.id != id && $0.shelfUsage == .dedicated && isAt($0, rackID, shelf)
        }

        guard let sourceRack = device.rackID, let sourceShelf = device.shelfIndex else {
            guard !targetHasDedicated else { return false }
            devices[index].rackID = rackID
            devices[index].shelfIndex = shelf
            return true
        }

        if sourceRack == rackID && sourceShelf == shelf { return true }

        let movers = devices.indices.filter { isAt(devices[$0], sourceRack, sourceShelf) }
        let displaced = targetHasDedicated
            ? devices.indices.filter { isAt(devices[$0], rackID, shelf) }
            : []
        for position in movers {
            devices[position].rackID = rackID
            devices[position].shelfIndex = shelf
        }
        for position in displaced {
            devices[position].rackID = sourceRack
            devices[position].shelfIndex = sourceShelf
        }
        return true
    }

    /// Inserts a device in the gap *before* shelf `gap` (0...shelfCount), as when it is dropped
    /// between two shelves. Nothing swaps: neighbouring shelves slide over by one to make room,
    /// stopping at the nearest empty shelf (below the gap first, then above it).
    ///
    /// Moves a dedicated device together with its shared accessories, like `moveDevice`.
    /// Returns false, changing nothing, when the rack has no empty shelf to slide into.
    @discardableResult
    mutating func insertDevice(_ id: UUID, toRack rackID: UUID, before gap: Int) -> Bool {
        guard let rack = racks.first(where: { $0.id == rackID }),
              let index = devices.firstIndex(where: { $0.id == id }),
              (0...rack.shelfCount).contains(gap) else { return false }
        let device = devices[index]

        var moverIDs: Set<UUID> = [id]
        if device.shelfUsage == .dedicated, let sourceRack = device.rackID, let sourceShelf = device.shelfIndex {
            moverIDs = Set(devices.filter { $0.rackID == sourceRack && $0.shelfIndex == sourceShelf }.map(\.id))
        }

        let occupied = Set(devices.compactMap { other -> Int? in
            guard other.rackID == rackID, !moverIDs.contains(other.id) else { return nil }
            return other.shelfIndex
        })

        var landing = gap
        var shift = 0   // +1 slides shelves from gap down; -1 slides shelves above the gap up
        var range = 0..<0
        if gap < rack.shelfCount, let empty = (gap..<rack.shelfCount).first(where: { !occupied.contains($0) }) {
            landing = gap
            shift = 1
            range = gap..<empty
        } else if let empty = (0..<gap).last(where: { !occupied.contains($0) }) {
            landing = gap - 1
            shift = -1
            range = (empty + 1)..<gap
        } else {
            return false
        }

        for position in devices.indices where devices[position].rackID == rackID && !moverIDs.contains(devices[position].id) {
            if let shelf = devices[position].shelfIndex, range.contains(shelf) {
                devices[position].shelfIndex = shelf + shift
            }
        }
        for position in devices.indices where moverIDs.contains(devices[position].id) {
            devices[position].rackID = rackID
            devices[position].shelfIndex = landing
        }
        return true
    }
}
