import XCTest
@testable import RackPlanner

final class PlanningEngineTests: XCTestCase {
    func testPublicSupportLinksStayOnExpectedHosts() {
        XCTAssertEqual(RackPlannerLinks.website.absoluteString, "https://code.matx.ca")
        XCTAssertEqual(RackPlannerLinks.repository.absoluteString, "https://github.com/macvfx/rackPlanner")
        XCTAssertEqual(
            RackPlannerLinks.userGuide.absoluteString,
            "https://github.com/macvfx/rackPlanner/blob/main/Docs/USER_GUIDE.md"
        )
        XCTAssertEqual(RackPlannerLinks.issues.host, "github.com")
    }

    func testFivePortSwitchIsShortForSixComputersAndTwentyPercentSpare() throws {
        var project = RackPlanProject.blank
        project.devices = (1...6).map { DeviceCatalog.template(id: "mac-mini")!.instantiate(named: "Computer \($0)") }
        project.devices.append(DeviceCatalog.template(id: "switch-5-1g")!.instantiate())

        let result = PlanningEngine.networkResult(for: .lan, project: project)

        XCTAssertEqual(result.endpointDemand, 6)
        XCTAssertEqual(result.grossCapacity, 5)
        XCTAssertEqual(result.targetCapacity, 8)
        XCTAssertEqual(result.shortage, 3)
    }

    func testTwoFourPortProvidersLoseTwoPortsToOneUplink() throws {
        var project = RackPlanProject.blank
        let template = DeviceTemplate(
            id: "test-switch",
            name: "Test Switch",
            category: .networking,
            ports: (1...4).map {
                .network("Port \($0)", role: .switchAccess, purpose: .lan, speeds: [.gb1])
            },
            estimatedWatts: nil,
            upsOutletCount: 0
        )
        project.devices = [template.instantiate(), template.instantiate()]

        let result = PlanningEngine.networkResult(for: .lan, project: project)

        XCTAssertEqual(result.providerCount, 2)
        XCTAssertEqual(result.grossCapacity, 8)
        XCTAssertEqual(result.reservedUplinkPorts, 2)
        XCTAssertEqual(result.usableCapacity, 6)
    }

    func testNetworksRemainIndependent() throws {
        var project = RackPlanProject.blank
        project.devices = [
            DeviceCatalog.template(id: "mac-mini")!.instantiate(),
            DeviceCatalog.template(id: "nas")!.instantiate(),
            DeviceCatalog.template(id: "switch-5-1g")!.instantiate(),
            DeviceCatalog.template(id: "switch-4-2-5g-2-10g")!.instantiate()
        ]

        let lan = PlanningEngine.networkResult(for: .lan, project: project)
        let production = PlanningEngine.networkResult(for: .production, project: project)

        XCTAssertEqual(lan.endpointDemand, 2)
        XCTAssertEqual(lan.grossCapacity, 5)
        XCTAssertEqual(production.endpointDemand, 1)
        XCTAssertEqual(production.grossCapacity, 6)
    }

    func testPowerShortageCountsProtectedDevicesAgainstUPSOutlets() throws {
        var project = RackPlanProject.blank
        var computer = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        computer.requiresUPS = true
        var ups = DeviceCatalog.template(id: "ups")!.instantiate()
        ups.upsOutletCount = 0
        project.devices = [computer, ups]

        XCTAssertEqual(PlanningEngine.powerResult(for: project).outletShortage, 1)
    }

    func testCSVQuotesCommasAndQuotes() throws {
        var project = RackPlanProject.blank
        var device = DeviceCatalog.template(id: "mac-mini")!.instantiate(named: "Computer, \"A\"")
        device.notes = "Example, only"
        project.devices = [device]

        let csv = CSVExporter.devices(project)

        XCTAssertTrue(csv.contains("\"Computer, \"\"A\"\"\""))
        XCTAssertTrue(csv.contains("\"Example, only\""))
    }

    func testSharedAccessoryDoesNotConsumeAnotherShelfPosition() throws {
        var project = RackPlanProject.blank
        let rackID = try XCTUnwrap(project.racks.first?.id)
        var computer = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        computer.rackID = rackID
        computer.shelfIndex = 0
        var kvm = DeviceCatalog.template(id: "generic-kvm")!.instantiate()
        kvm.rackID = rackID
        kvm.shelfIndex = 0
        project.devices = [computer, kvm]

        let shelves = PlanningEngine.shelfResult(for: project)

        XCTAssertEqual(kvm.shelfUsage, .sharedAccessory)
        XCTAssertEqual(shelves.occupied, 1)
        XCTAssertEqual(shelves.free, project.racks[0].shelfCount - 1)
    }

    func testConnectionCSVNamesBothDevicesAndPorts() throws {
        var project = RackPlanProject.blank
        let computer = DeviceCatalog.template(id: "mac-mini")!.instantiate(named: "Host Mac")
        var kvm = DeviceCatalog.template(id: "generic-kvm")!.instantiate(named: "KVM")
        let local = try XCTUnwrap(kvm.ports.first { $0.kind == .hdmi })
        let host = try XCTUnwrap(computer.ports.first { $0.kind == .hdmi })
        kvm.hostConnections = [
            HostConnection(localPortID: local.id, hostDeviceID: computer.id, hostPortID: host.id)
        ]
        project.devices = [computer, kvm]

        let csv = CSVExporter.connections(project)

        XCTAssertTrue(csv.contains("\"KVM\",\"HDMI Input\",\"HDMI\",\"Host Mac\",\"HDMI\""))
    }

    func testQuickAccessBuildsBrowserAndScreenSharingURLs() throws {
        XCTAssertEqual(
            RemoteAccessMethod.https.url(for: "192.0.2.50")?.absoluteString,
            "https://192.0.2.50"
        )
        XCTAssertEqual(
            RemoteAccessMethod.screenSharing.url(for: "mac-1.example.invalid")?.absoluteString,
            "vnc://mac-1.example.invalid"
        )
        XCTAssertNil(RemoteAccessMethod.none.url(for: "192.0.2.50"))
    }

    func testQuickAccessPreservesAnExplicitURL() throws {
        XCTAssertEqual(
            RemoteAccessMethod.https.url(for: "http://192.0.2.50:8080/admin")?.absoluteString,
            "http://192.0.2.50:8080/admin"
        )
    }

    func testAccessCSVIncludesHostnameAndVPNAddress() throws {
        var project = RackPlanProject.blank
        var kvm = DeviceCatalog.template(id: "generic-kvm")!.instantiate(named: "Example KVM")
        kvm.hostname = "kvm.example.invalid"
        kvm.hostnameAccessMethod = .https
        kvm.networkAddresses = [
            DeviceNetworkAddress(
                label: "Example VPN",
                kind: .vpn,
                address: "198.51.100.50",
                accessMethod: .https
            )
        ]
        project.devices = [kvm]

        let csv = CSVExporter.access(project)

        XCTAssertTrue(csv.contains("\"kvm.example.invalid\""))
        XCTAssertTrue(csv.contains("\"VPN / Tailscale\""))
        XCTAssertTrue(csv.contains("\"https://198.51.100.50\""))
    }

    func testQuickAccessRefusesUnlistedSchemes() throws {
        XCTAssertNil(RemoteAccessMethod.https.url(for: "file:///Applications"))
        XCTAssertNil(RemoteAccessMethod.https.url(for: "smb://192.0.2.5/share"))
        XCTAssertEqual(
            RemoteAccessMethod.ssh.url(for: "ssh://192.0.2.5")?.absoluteString,
            "ssh://192.0.2.5"
        )
        XCTAssertEqual(
            RemoteAccessMethod.https.url(for: "host.example.invalid:8443")?.absoluteString,
            "https://host.example.invalid:8443"
        )
    }

    func testCSVNeutralisesSpreadsheetFormulas() throws {
        XCTAssertEqual(CSVExporter.csv("=SUM(A1)"), "\"'=SUM(A1)\"")
        XCTAssertEqual(CSVExporter.csv("@cmd"), "\"'@cmd\"")
        XCTAssertEqual(CSVExporter.csv("Plain"), "\"Plain\"")
    }

    func testRemovingAPortDropsConnectionsThatUseIt() throws {
        var project = RackPlanProject.blank
        var host = DeviceCatalog.template(id: "mac-mini")!.instantiate(named: "Host")
        var kvm = DeviceCatalog.template(id: "generic-kvm")!.instantiate(named: "KVM")
        let local = try XCTUnwrap(kvm.ports.first { $0.kind == .hdmi })
        let hostPort = try XCTUnwrap(host.ports.first { $0.kind == .hdmi })
        kvm.hostConnections = [HostConnection(localPortID: local.id, hostDeviceID: host.id, hostPortID: hostPort.id)]
        host.ports.removeAll { $0.id == hostPort.id }
        project.devices = [host, kvm]

        project.pruneDanglingReferences()

        XCTAssertTrue(project.devices[1].hostConnections.isEmpty)
    }

    func testIncompleteConnectionRowsSurvivePruning() throws {
        var project = RackPlanProject.blank
        var kvm = DeviceCatalog.template(id: "generic-kvm")!.instantiate()
        kvm.hostConnections = [HostConnection()]
        project.devices = [kvm]
        project.pruneDanglingReferences()
        XCTAssertEqual(project.devices[0].hostConnections.count, 1)
    }

    func testOlderFileWithoutSettingsStillOpens() throws {
        let json = #"{"name":"Old","racks":[],"devices":[]}"#
        let project = try JSONDecoder().decode(RackPlanProject.self, from: Data(json.utf8))
        XCTAssertEqual(project.name, "Old")
        XCTAssertEqual(project.settings.sparePortPercentage, 20)
        XCTAssertEqual(project.schemaVersion, RackPlanProject.currentSchemaVersion)
    }

    func testNewerSchemaIsRefusedInsteadOfBeingSilentlyDowngraded() throws {
        let json = #"{"schemaVersion":99,"name":"Future","racks":[],"devices":[]}"#
        XCTAssertThrowsError(try JSONDecoder().decode(RackPlanProject.self, from: Data(json.utf8)))
    }

    func testPlacementInARemovedRackIsCleared() throws {
        var project = RackPlanProject.blank
        var device = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        device.rackID = UUID()
        device.shelfIndex = 3
        project.devices = [device]
        project.pruneDanglingReferences()
        XCTAssertNil(project.devices[0].rackID)
        XCTAssertNil(project.devices[0].shelfIndex)
    }

    func testFastEndpointsNeedFastPortsNotJustManyPorts() throws {
        var project = RackPlanProject.blank
        let fastNIC = DeviceTemplate(
            id: "t-nic", name: "NIC", category: .computer,
            ports: [.network("10G", purpose: .production, speeds: [.gb1, .gb10])],
            estimatedWatts: nil, upsOutletCount: 0
        )
        let slowSwitch = DeviceTemplate(
            id: "t-sw", name: "Switch", category: .networking,
            ports: (1...8).map { .network("P\($0)", role: .switchAccess, purpose: .production, speeds: [.gb1]) }
                + [.network("10G", kind: .sfp, role: .switchAccess, purpose: .production, speeds: [.gb1, .gb10])],
            estimatedWatts: nil, upsOutletCount: 0
        )
        project.devices = (1...4).map { _ in fastNIC.instantiate() } + [slowSwitch.instantiate()]

        let result = PlanningEngine.networkResult(for: .production, project: project)

        XCTAssertEqual(result.grossCapacity, 9)
        XCTAssertGreaterThan(result.speedShortage, 0)
        XCTAssertEqual(result.limitingSpeed, .gb10)
        XCTAssertFalse(result.isAdequate)
    }

    func testEveryCategoryHasAGenericBlock() throws {
        for category in DeviceCategory.allCases {
            XCTAssertTrue(
                DeviceCatalog.templates.contains { $0.category == category && $0.id.hasPrefix("generic-") },
                "No generic block for \(category.rawValue)"
            )
        }
        XCTAssertEqual(DeviceCatalog.template(id: "generic-kvm")?.name, "Generic KVM")
    }

    private func shelfProject() throws -> (RackPlanProject, UUID) {
        var project = RackPlanProject.blank
        project.racks[0].shelfCount = 6
        return (project, project.racks[0].id)
    }

    func testDraggingOntoAnOccupiedShelfSwapsTheTwoShelvesWithTheirAccessories() throws {
        var (project, rack) = try shelfProject()
        var a = DeviceCatalog.template(id: "mac-mini")!.instantiate(named: "A")
        var b = DeviceCatalog.template(id: "nas")!.instantiate(named: "B")
        var kvm = DeviceCatalog.template(id: "generic-kvm")!.instantiate(named: "KVM")
        a.rackID = rack; a.shelfIndex = 0
        kvm.rackID = rack; kvm.shelfIndex = 0
        b.rackID = rack; b.shelfIndex = 3
        project.devices = [a, b, kvm]

        XCTAssertTrue(project.moveDevice(a.id, toRack: rack, shelf: 3))

        XCTAssertEqual(project.devices[0].shelfIndex, 3)
        XCTAssertEqual(project.devices[2].shelfIndex, 3, "accessory travels with its host")
        XCTAssertEqual(project.devices[1].shelfIndex, 0)
    }

    func testDraggingADedicatedDeviceToAnEmptyShelfMovesItsAccessoriesToo() throws {
        var (project, rack) = try shelfProject()
        var a = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        var kvm = DeviceCatalog.template(id: "generic-kvm")!.instantiate()
        a.rackID = rack; a.shelfIndex = 1
        kvm.rackID = rack; kvm.shelfIndex = 1
        project.devices = [a, kvm]

        XCTAssertTrue(project.moveDevice(a.id, toRack: rack, shelf: 4))

        XCTAssertEqual(project.devices.map(\.shelfIndex), [4, 4])
    }

    func testDraggingAnAccessoryMovesOnlyThatAccessory() throws {
        var (project, rack) = try shelfProject()
        var a = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        var kvm = DeviceCatalog.template(id: "generic-kvm")!.instantiate()
        a.rackID = rack; a.shelfIndex = 1
        kvm.rackID = rack; kvm.shelfIndex = 1
        project.devices = [a, kvm]

        XCTAssertTrue(project.moveDevice(kvm.id, toRack: rack, shelf: 2))

        XCTAssertEqual(project.devices.map(\.shelfIndex), [1, 2])
    }

    func testUnassignedDedicatedDeviceCannotDisplaceAnotherDedicatedDevice() throws {
        var (project, rack) = try shelfProject()
        var a = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        a.rackID = rack; a.shelfIndex = 2
        let b = DeviceCatalog.template(id: "nas")!.instantiate()
        project.devices = [a, b]

        XCTAssertFalse(project.moveDevice(b.id, toRack: rack, shelf: 2))
        XCTAssertNil(project.devices[1].shelfIndex)
    }

    func testSwapWorksAcrossRacks() throws {
        var (project, rack) = try shelfProject()
        let second = EquipmentRack(name: "Second", format: .rack19, shelfCount: 4)
        project.racks.append(second)
        var a = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        var b = DeviceCatalog.template(id: "nas")!.instantiate()
        a.rackID = rack; a.shelfIndex = 0
        b.rackID = second.id; b.shelfIndex = 1
        project.devices = [a, b]

        XCTAssertTrue(project.moveDevice(a.id, toRack: second.id, shelf: 1))

        XCTAssertEqual(project.devices[0].rackID, second.id)
        XCTAssertEqual(project.devices[1].rackID, rack)
        XCTAssertEqual(project.devices[1].shelfIndex, 0)
    }

    func testInsertBetweenShelvesSlidesNeighboursDownToTheNextEmptyShelf() throws {
        var (project, rack) = try shelfProject()
        var m1 = DeviceCatalog.template(id: "mac-mini")!.instantiate(named: "M1")
        var intel = DeviceCatalog.template(id: "mac-mini")!.instantiate(named: "Intel")
        var nas = DeviceCatalog.template(id: "nas")!.instantiate(named: "NAS")
        m1.rackID = rack; m1.shelfIndex = 0
        intel.rackID = rack; intel.shelfIndex = 1
        nas.rackID = rack; nas.shelfIndex = 4
        project.devices = [m1, intel, nas]

        // Put the NAS between M1 and Intel.
        XCTAssertTrue(project.insertDevice(nas.id, toRack: rack, before: 1))

        XCTAssertEqual(project.devices.map(\.shelfIndex), [0, 2, 1])
    }

    func testInsertSlidesOnlyUntilTheFirstGap() throws {
        var (project, rack) = try shelfProject()
        var a = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        var b = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        var c = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        var d = DeviceCatalog.template(id: "nas")!.instantiate()
        a.rackID = rack; a.shelfIndex = 0
        b.rackID = rack; b.shelfIndex = 1
        c.rackID = rack; c.shelfIndex = 3   // shelf 2 is empty
        d.rackID = rack; d.shelfIndex = 5
        project.devices = [a, b, c, d]

        XCTAssertTrue(project.insertDevice(d.id, toRack: rack, before: 1))

        XCTAssertEqual(project.devices.map(\.shelfIndex), [0, 2, 3, 1])
    }

    func testInsertAtTheBottomSlidesUpWhenThereIsNoRoomBelow() throws {
        var (project, rack) = try shelfProject()
        project.racks[0].shelfCount = 3
        var a = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        var b = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        var c = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        a.rackID = rack; a.shelfIndex = 0
        b.rackID = rack; b.shelfIndex = 1
        c.rackID = rack; c.shelfIndex = nil
        project.devices = [a, b, c]

        XCTAssertTrue(project.insertDevice(c.id, toRack: rack, before: 3))   // below the last shelf

        XCTAssertEqual(project.devices.map(\.shelfIndex), [0, 1, 2])
    }

    func testInsertIntoAFullRackIsRefusedAndChangesNothing() throws {
        var (project, rack) = try shelfProject()
        project.racks[0].shelfCount = 2
        var a = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        var b = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        a.rackID = rack; a.shelfIndex = 0
        b.rackID = rack; b.shelfIndex = 1
        let c = DeviceCatalog.template(id: "nas")!.instantiate()
        project.devices = [a, b, c]

        XCTAssertFalse(project.insertDevice(c.id, toRack: rack, before: 1))
        XCTAssertEqual(project.devices.map(\.shelfIndex), [0, 1, nil])
    }

    func testInsertingAHostBringsItsAccessoryAlong() throws {
        var (project, rack) = try shelfProject()
        var a = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        var kvm = DeviceCatalog.template(id: "generic-kvm")!.instantiate()
        var b = DeviceCatalog.template(id: "nas")!.instantiate()
        a.rackID = rack; a.shelfIndex = 0
        kvm.rackID = rack; kvm.shelfIndex = 0
        b.rackID = rack; b.shelfIndex = 1
        project.devices = [a, kvm, b]

        XCTAssertTrue(project.insertDevice(a.id, toRack: rack, before: 2))   // below the NAS

        XCTAssertEqual(project.devices.map(\.shelfIndex), [2, 2, 1])   // shelf 0 is left empty
    }

    func testPortSummaryCountsByTypeAndSkipsWiFiAndPower() throws {
        let router = DeviceCatalog.template(id: "router")!.instantiate()
        // WAN + 4 LAN count; the Wi-Fi radio and AC inlet do not.
        XCTAssertEqual(router.portCounts.network, 5)
        XCTAssertEqual(router.portSummary, "5 network")

        let mini = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        XCTAssertEqual(mini.portSummary, "1 network · 2 Thunderbolt · 1 HDMI")

        let pi = DeviceCatalog.template(id: "raspberry-pi")!.instantiate()
        XCTAssertEqual(pi.portSummary, "1 network · 1 USB · 1 HDMI")   // USB-C power input excluded

        let ups = DeviceCatalog.template(id: "ups")!.instantiate()
        XCTAssertEqual(ups.portSummary, "")
    }

    func testDuplicateGetsNewIdentitiesClearsAddressesAndLandsOnTheNextEmptyShelf() throws {
        var (project, rack) = try shelfProject()
        var host = DeviceCatalog.template(id: "mac-mini")!.instantiate(named: "Host")
        var kvm = DeviceCatalog.template(id: "generic-kvm")!.instantiate(named: "KVM")
        host.rackID = rack; host.shelfIndex = 0
        kvm.rackID = rack; kvm.shelfIndex = 0
        kvm.hostname = "kvm.example.invalid"
        kvm.networkAddresses = [DeviceNetworkAddress(label: "L", kind: .lan, address: "192.0.2.5", accessMethod: .https)]
        kvm.hostConnections = [HostConnection(localPortID: kvm.ports[1].id, hostDeviceID: host.id, hostPortID: host.ports[0].id)]
        kvm.modelLine = "JetKVM"
        project.devices = [host, kvm]

        let copyID = try XCTUnwrap(project.duplicateDevice(kvm.id))
        let copy = try XCTUnwrap(project.devices.first { $0.id == copyID })

        XCTAssertEqual(copy.name, "KVM copy")
        XCTAssertEqual(copy.modelLine, "JetKVM")
        XCTAssertEqual(copy.shelfIndex, 1)
        XCTAssertEqual(copy.hostname, "")
        XCTAssertTrue(copy.networkAddresses.isEmpty)
        XCTAssertTrue(copy.hostConnections.isEmpty)
        XCTAssertEqual(Set(copy.ports.map(\.id)).intersection(Set(kvm.ports.map(\.id))), [])
        XCTAssertEqual(copy.ports.map(\.name), kvm.ports.map(\.name))
    }

    func testDuplicateGoesToUnassignedWhenTheRackIsFull() throws {
        var (project, rack) = try shelfProject()
        project.racks[0].shelfCount = 1
        var a = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        a.rackID = rack; a.shelfIndex = 0
        project.devices = [a]

        let copyID = try XCTUnwrap(project.duplicateDevice(a.id))

        XCTAssertNil(project.devices.first { $0.id == copyID }?.rackID)
    }

    func testRemoveDeviceAlsoRemovesConnectionsToIt() throws {
        var project = RackPlanProject.blank
        let host = DeviceCatalog.template(id: "mac-mini")!.instantiate()
        var kvm = DeviceCatalog.template(id: "generic-kvm")!.instantiate()
        kvm.hostConnections = [HostConnection(localPortID: kvm.ports[1].id, hostDeviceID: host.id, hostPortID: host.ports[0].id)]
        project.devices = [host, kvm]

        project.removeDevice(host.id)

        XCTAssertEqual(project.devices.count, 1)
        XCTAssertTrue(project.devices[0].hostConnections.isEmpty)
    }
}
