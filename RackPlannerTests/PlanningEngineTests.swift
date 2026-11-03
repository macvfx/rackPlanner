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
        var kvm = DeviceCatalog.template(id: "jetkvm")!.instantiate()
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
        var kvm = DeviceCatalog.template(id: "jetkvm")!.instantiate(named: "KVM")
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
        var kvm = DeviceCatalog.template(id: "jetkvm")!.instantiate(named: "Example KVM")
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
}
