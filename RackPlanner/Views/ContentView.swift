import AppKit
import SwiftUI

enum PlannerViewMode: String, CaseIterable, Identifiable {
    case rack = "Rack"
    case network = "Network"
    case overview = "Overview"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .rack: "square.grid.3x3"
        case .network: "point.3.connected.trianglepath.dotted"
        case .overview: "chart.bar"
        }
    }
}

struct ContentView: View {
    @Binding var document: RackPlanDocument
    @State private var selectedDeviceID: UUID?
    @State private var mode: PlannerViewMode = .rack
    @State private var statusMessage: String?

    var body: some View {
        NavigationSplitView {
            DeviceLibraryView { template in
                add(template: template)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } content: {
            VStack(spacing: 0) {
                Picker("View", selection: $mode) {
                    ForEach(PlannerViewMode.allCases) { value in
                        Label(value.rawValue, systemImage: value.symbol).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding()

                Divider()

                switch mode {
                case .rack:
                    RackLayoutView(project: $document.project, selectedDeviceID: $selectedDeviceID)
                case .network:
                    NetworkPlannerView(project: document.project, selectedDeviceID: $selectedDeviceID)
                case .overview:
                    OverviewView(project: document.project)
                }
            }
            .navigationTitle(document.project.name)
            .navigationSplitViewColumnWidth(min: 560, ideal: 820)
        } detail: {
            inspector
                .navigationSplitViewColumnWidth(min: 280, ideal: 330, max: 420)
        }
        .frame(minWidth: 1120, minHeight: 700)
        .onChange(of: document.project.devices) {
            var cleaned = document.project
            cleaned.pruneDanglingReferences()
            if cleaned.devices != document.project.devices { document.project.devices = cleaned.devices }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    addRack()
                } label: {
                    Label("Add Rack", systemImage: "rectangle.stack.badge.plus")
                }
                Button {
                    exportCSVs()
                } label: {
                    Label("Export CSVs", systemImage: "tablecells.badge.ellipsis")
                }
                Button(role: .destructive) {
                    document.project = .blank
                    selectedDeviceID = nil
                } label: {
                    Label("Blank Plan", systemImage: "doc.badge.plus")
                }
                .help("Replace the current document with a blank plan")
            }
        }
        .alert("Rack Planner", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button("OK") { statusMessage = nil }
        } message: {
            Text(statusMessage ?? "")
        }
    }

    @ViewBuilder
    private var inspector: some View {
        if let selectedDeviceID,
           let index = document.project.devices.firstIndex(where: { $0.id == selectedDeviceID }) {
            DeviceInspectorView(
                device: $document.project.devices[index],
                racks: document.project.racks,
                allDevices: document.project.devices,
                occupiedDedicatedShelves: occupiedDedicatedShelves(excluding: selectedDeviceID),
                delete: {
                    document.project.removeDevice(selectedDeviceID)
                    self.selectedDeviceID = nil
                }
            )
        } else {
            ProjectInspectorView(project: $document.project)
        }
    }

    private func occupiedDedicatedShelves(excluding id: UUID) -> Set<String> {
        Set(document.project.devices.compactMap { device in
            guard device.id != id, device.shelfUsage == .dedicated,
                  let rack = device.rackID, let shelf = device.shelfIndex else { return nil }
            return "\(rack.uuidString):\(shelf)"
        })
    }

    private func add(template: DeviceTemplate) {
        let device = template.instantiate()
        document.project.devices.append(device)
        selectedDeviceID = device.id
    }

    private func addRack() {
        let number = document.project.racks.count + 1
        document.project.racks.append(EquipmentRack(name: "Rack \(number)", format: .rack19, shelfCount: 12))
    }

    private func exportCSVs() {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder for Rack Planner CSVs"
        panel.prompt = "Export"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        let existing = CSVExporter.fileNames.filter {
            FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path)
        }
        if !existing.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Replace existing CSV files?"
            alert.informativeText = "This folder already contains: \(existing.joined(separator: ", ")). Exporting will replace them."
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        do {
            try CSVExporter.export(project: document.project, to: directory)
            statusMessage = "Exported devices, ports, quick access, host connections, network requirements, and power CSVs."
        } catch {
            statusMessage = "CSV export failed: \(error.localizedDescription)"
        }
    }
}

struct DeviceLibraryView: View {
    let add: (DeviceTemplate) -> Void
    @State private var search = ""

    var filtered: [DeviceTemplate] {
        guard !search.isEmpty else { return DeviceCatalog.templates }
        return DeviceCatalog.templates.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.category.rawValue.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            ForEach(DeviceCategory.allCases) { category in
                let items = filtered.filter { $0.category == category }
                if !items.isEmpty {
                    Section(category.rawValue) {
                        ForEach(items) { template in
                            HStack {
                                Label(template.name, systemImage: category.symbol)
                                    .lineLimit(2)
                                Spacer()
                                Button {
                                    add(template)
                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Add \(template.name)")
                            }
                            .padding(.vertical, 2)
                            .draggable("template:\(template.id)")
                        }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Find equipment")
        .navigationTitle("Device Library")
    }
}

struct RackLayoutView: View {
    @Binding var project: RackPlanProject
    @Binding var selectedDeviceID: UUID?
    @State private var pendingDelete: PlannedDevice?

    /// Right-click menu shared by every card in Rack view.
    private func cardMenu(for device: PlannedDevice) -> AnyView {
        AnyView(Group {
            Button("Show in Inspector", systemImage: "sidebar.right") { selectedDeviceID = device.id }
            Button("Duplicate", systemImage: "plus.square.on.square") {
                if let copy = project.duplicateDevice(device.id) { selectedDeviceID = copy }
            }
            Divider()
            Button("Delete…", systemImage: "trash", role: .destructive) { pendingDelete = device }
        })
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 18) {
                ForEach(project.racks) { rack in
                    rackColumn(rack)
                }
                unassignedColumn
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .confirmationDialog(
            "Delete \(pendingDelete?.name ?? "device")?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let device = pendingDelete {
                    project.removeDevice(device.id)
                    if selectedDeviceID == device.id { selectedDeviceID = nil }
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("This also removes connections that use it. This can't be undone.")
        }
    }

    private func rackColumn(_ rack: EquipmentRack) -> some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(rack.name).font(.headline)
                    Text("\(rack.format.rawValue) · \(rack.shelfCount) shelves")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
            ForEach(0..<rack.shelfCount, id: \.self) { shelf in
                ShelfGapView { tokens in handleInsert(tokens, rackID: rack.id, gap: shelf) }
                let devices = project.devices.filter { $0.rackID == rack.id && $0.shelfIndex == shelf }
                ShelfSlotView(
                    shelf: shelf,
                    devices: devices,
                    selectedDeviceID: selectedDeviceID,
                    connectionSummary: connectionSummary,
                    select: { selectedDeviceID = $0 },
                    menu: cardMenu,
                    handleDrop: { tokens in handleDrop(tokens, rackID: rack.id, shelf: shelf) }
                )
            }
            ShelfGapView { tokens in handleInsert(tokens, rackID: rack.id, gap: rack.shelfCount) }
            }
        }
        .padding(12)
        .frame(width: 330)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
    }

    private var unassignedColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unassigned").font(.headline)
            Text("Drop devices here to remove shelf placement.")
                .font(.caption).foregroundStyle(.secondary)

            ForEach(project.devices.filter { $0.rackID == nil || $0.shelfIndex == nil }) { device in
                DeviceCardView(
                    device: device,
                    selected: device.id == selectedDeviceID,
                    connectionSummary: connectionSummary(device)
                )
                    .onTapGesture { selectedDeviceID = device.id }
                    .draggable("device:\(device.id.uuidString)")
                    .contextMenu { cardMenu(for: device) }
            }

            if project.devices.allSatisfy({ $0.rackID != nil && $0.shelfIndex != nil }) {
                ContentUnavailableView("No Unassigned Devices", systemImage: "checkmark.circle")
                    .frame(height: 120)
            }
        }
        .padding(12)
        .frame(width: 300)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
        .dropDestination(for: String.self) { tokens, _ in
            guard let token = tokens.first, token.hasPrefix("device:"),
                  let id = UUID(uuidString: String(token.dropFirst("device:".count))),
                  let index = project.devices.firstIndex(where: { $0.id == id }) else { return false }
            project.devices[index].rackID = nil
            project.devices[index].shelfIndex = nil
            return true
        }
    }

    private func handleDrop(_ tokens: [String], rackID: UUID, shelf: Int) -> Bool {
        guard let token = tokens.first else { return false }

        if token.hasPrefix("template:"),
           let template = DeviceCatalog.template(id: String(token.dropFirst("template:".count))) {
            var device = template.instantiate()
            guard canPlace(device, on: rackID, shelf: shelf, excluding: nil) else { return false }
            device.rackID = rackID
            device.shelfIndex = shelf
            project.devices.append(device)
            selectedDeviceID = device.id
            return true
        }
        if token.hasPrefix("device:"),
           let id = UUID(uuidString: String(token.dropFirst("device:".count))) {
            guard project.moveDevice(id, toRack: rackID, shelf: shelf) else { return false }
            selectedDeviceID = id
            return true
        }
        return false
    }

    /// A drop in the gap between two shelves: insert there and slide neighbours over.
    private func handleInsert(_ tokens: [String], rackID: UUID, gap: Int) -> Bool {
        guard let token = tokens.first else { return false }
        if token.hasPrefix("template:"),
           let template = DeviceCatalog.template(id: String(token.dropFirst("template:".count))) {
            let device = template.instantiate()
            var trial = project
            trial.devices.append(device)
            guard trial.insertDevice(device.id, toRack: rackID, before: gap) else { return false }
            project = trial
            selectedDeviceID = device.id
            return true
        }
        if token.hasPrefix("device:"),
           let id = UUID(uuidString: String(token.dropFirst("device:".count))) {
            guard project.insertDevice(id, toRack: rackID, before: gap) else { return false }
            selectedDeviceID = id
            return true
        }
        return false
    }

    private func canPlace(_ device: PlannedDevice, on rackID: UUID, shelf: Int, excluding id: UUID?) -> Bool {
        guard device.shelfUsage == .dedicated else { return true }
        return !project.devices.contains {
            $0.id != id && $0.rackID == rackID && $0.shelfIndex == shelf && $0.shelfUsage == .dedicated
        }
    }

    private func connectionSummary(_ device: PlannedDevice) -> String? {
        guard let connection = device.hostConnections.first,
              let hostID = connection.hostDeviceID,
              let host = project.devices.first(where: { $0.id == hostID }) else { return nil }
        let localName = device.ports.first(where: { $0.id == connection.localPortID })?.name ?? "Accessory"
        let hostPort = host.ports.first(where: { $0.id == connection.hostPortID })?.name
        let destination = hostPort.map { "\(host.name) / \($0)" } ?? host.name
        let extra = device.hostConnections.count > 1 ? " +\(device.hostConnections.count - 1) more" : ""
        return "\(localName) → \(destination)\(extra)"
    }
}

/// A thin drop target between two shelves. Dropping here inserts instead of swapping.
struct ShelfGapView: View {
    let handleDrop: ([String]) -> Bool
    @State private var targeted = false

    var body: some View {
        Color.clear
            .frame(height: 12)
            .overlay {
                if targeted {
                    Capsule().fill(Color.accentColor).frame(height: 4)
                }
            }
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { tokens, _ in handleDrop(tokens) } isTargeted: { targeted = $0 }
            .accessibilityHidden(true)
    }
}

struct ShelfSlotView: View {
    let shelf: Int
    let devices: [PlannedDevice]
    let selectedDeviceID: UUID?
    let connectionSummary: (PlannedDevice) -> String?
    let select: (UUID) -> Void
    let menu: (PlannedDevice) -> AnyView
    let handleDrop: ([String]) -> Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("\(shelf + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22)
            if !devices.isEmpty {
                VStack(spacing: 5) {
                    ForEach(devices.sorted { $0.shelfUsage == .dedicated && $1.shelfUsage != .dedicated }) { device in
                        DeviceCardView(
                            device: device,
                            selected: device.id == selectedDeviceID,
                            connectionSummary: connectionSummary(device)
                        )
                        .onTapGesture { select(device.id) }
                        .draggable("device:\(device.id.uuidString)")
                        .contextMenu { menu(device) }
                    }
                }
            } else {
                Label("Empty shelf", systemImage: "square.dashed")
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(7)
        .frame(minHeight: 58)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator.opacity(0.7)))
        .dropDestination(for: String.self) { tokens, _ in handleDrop(tokens) }
    }
}

struct DeviceCardView: View {
    let device: PlannedDevice
    let selected: Bool
    var connectionSummary: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: device.category.symbol)
                .frame(width: 26, height: 26)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(connectionSummary ?? secondaryText)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if device.requiresUPS { Image(systemName: "bolt.shield").foregroundStyle(.green) }
        }
        .padding(8)
        .background(selected ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(selected ? Color.accentColor : .clear, lineWidth: 1.5))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(device.name), \(device.portSummary.isEmpty ? "no data ports" : device.portSummary)")
    }

    private var secondaryText: String {
        let identity = [device.modelLine, device.modelIdentifier].filter { !$0.isEmpty }.joined(separator: " · ")
        let shared = device.shelfUsage == .sharedAccessory ? " · shared" : ""
        if !identity.isEmpty { return identity + shared }
        let ports = device.portSummary.isEmpty ? "no data ports" : device.portSummary
        return ports + shared
    }
}

struct NetworkPlannerView: View {
    let project: RackPlanProject
    @Binding var selectedDeviceID: UUID?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), spacing: 16)], alignment: .leading, spacing: 16) {
                ForEach(PlanningEngine.networkResults(for: project)) { result in
                    NetworkCard(result: result, devices: devices(on: result.network)) { selectedDeviceID = $0 }
                }
            }
            .padding(20)
        }
    }

    private func devices(on network: NetworkPurpose) -> [PlannedDevice] {
        project.devices.filter { $0.ports.contains { $0.network == network } }
    }
}

struct NetworkCard: View {
    let result: NetworkPlanResult
    let devices: [PlannedDevice]
    let select: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(result.network.color).frame(width: 12, height: 12)
                Text(result.network.rawValue).font(.title3.bold())
                Spacer()
                Label(result.isAdequate ? "Ready" : "Needs attention",
                      systemImage: result.isAdequate ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(result.isAdequate ? .green : .orange)
            }

            HStack {
                MetricView(value: result.endpointDemand, label: "Endpoints")
                MetricView(value: result.usableCapacity, label: "Usable")
                MetricView(value: result.reservedUplinkPorts, label: "Uplink ports")
                MetricView(value: result.targetCapacity, label: "20% target")
            }

            Text(result.recommendation)
                .font(.callout)
                .foregroundStyle(result.isAdequate ? .secondary : .primary)

            Divider()
            ForEach(devices) { device in
                Button {
                    select(device.id)
                } label: {
                    HStack {
                        Image(systemName: device.category.symbol)
                        Text(device.name)
                        Spacer()
                        Text(device.providesNetworkCapacity ? "Provider" : "Endpoint")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(result.network.color.opacity(0.35)))
    }
}

struct MetricView: View {
    let value: Int
    let label: String
    var body: some View {
        VStack {
            Text(value, format: .number).font(.title3.monospacedDigit().bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct OverviewView: View {
    let project: RackPlanProject

    var body: some View {
        let shelves = PlanningEngine.shelfResult(for: project)
        let power = PlanningEngine.powerResult(for: project)
        let networks = PlanningEngine.networkResults(for: project)
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
                SummaryTile(title: "Equipment", symbol: "shippingbox", value: "\(project.devices.count)", detail: "devices in inventory")
                SummaryTile(title: "Shelves", symbol: "rectangle.stack", value: "\(shelves.free)", detail: "free of \(shelves.total); \(shelves.unassigned) unassigned")
                SummaryTile(title: "Networks", symbol: "network", value: "\(networks.reduce(0) { $0 + $1.shortage })", detail: "additional switch ports recommended")
                SummaryTile(title: "UPS", symbol: "bolt.shield", value: "\(power.outletShortage)", detail: "outlet shortage; \(power.upsOutlets) available")
                SummaryTile(title: "Planned Load", symbol: "bolt", value: power.plannedWatts.formatted(.number.precision(.fractionLength(0))), detail: "watts from entered estimates")
                SummaryTile(title: "Spare Target", symbol: "gauge.with.dots.needle.33percent", value: "\(project.settings.sparePortPercentage)%", detail: "applied to endpoint demand")
            }
            .padding(20)
        }
    }
}

struct SummaryTile: View {
    let title: String
    let symbol: String
    let value: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.headline)
            Text(value).font(.system(size: 34, weight: .bold, design: .rounded))
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct ProjectInspectorView: View {
    @Binding var project: RackPlanProject

    var body: some View {
        Form {
            Section("Project") {
                TextField("Name", text: $project.name)
                Stepper("Spare network capacity: \(project.settings.sparePortPercentage)%", value: $project.settings.sparePortPercentage, in: 0...100, step: 5)
            }
            Section("Racks and equipment areas") {
                ForEach($project.racks) { $rack in
                    DisclosureGroup(rack.name) {
                        TextField("Name", text: $rack.name)
                        Picker("Format", selection: $rack.format) {
                            ForEach(RackFormat.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Stepper("Shelf positions: \(rack.shelfCount)", value: $rack.shelfCount, in: 1...48)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Plan Inspector")
    }
}

struct DeviceInspectorView: View {
    @Binding var device: PlannedDevice
    let racks: [EquipmentRack]
    let allDevices: [PlannedDevice]
    let occupiedDedicatedShelves: Set<String>
    let delete: () -> Void

    var body: some View {
        Form {
            Section("Device") {
                TextField("Name", text: $device.name)
                LabeledContent("Category", value: device.category.rawValue)
                TextField("Model line", text: $device.modelLine, prompt: Text("Example: Mac mini (M4 Pro)"))
                TextField("Model identifier", text: $device.modelIdentifier, prompt: Text("Example: Mac16,11"))
                Toggle("Protect with UPS", isOn: $device.requiresUPS)
                TextField("Estimated watts", value: $device.estimatedWatts, format: .number)
                if device.category == .power {
                    Stepper("UPS outlets: \(device.upsOutletCount)", value: $device.upsOutletCount, in: 0...64)
                }
            }

            Section("Quick access") {
                TextField("Hostname", text: $device.hostname, prompt: Text("device.example.invalid"))
                Picker("Hostname action", selection: $device.hostnameAccessMethod) {
                    ForEach(RemoteAccessMethod.allCases) { Text($0.rawValue).tag($0) }
                }
                if let url = device.hostnameAccessMethod.url(for: device.hostname) {
                    Link(destination: url) {
                        Label(device.hostnameAccessMethod.actionLabel, systemImage: device.hostnameAccessMethod.symbol)
                    }
                }

                ForEach($device.networkAddresses) { $address in
                    DisclosureGroup(address.label.isEmpty ? address.kind.rawValue : address.label) {
                        TextField("Label", text: $address.label)
                        Picker("Address type", selection: $address.kind) {
                            ForEach(AddressKind.allCases) { Text($0.rawValue).tag($0) }
                        }
                        TextField("IP or address", text: $address.address, prompt: Text("192.0.2.10"))
                        Picker("Open with", selection: $address.accessMethod) {
                            ForEach(RemoteAccessMethod.allCases) { Text($0.rawValue).tag($0) }
                        }
                        if let url = address.accessMethod.url(for: address.address) {
                            Link(destination: url) {
                                Label(address.accessMethod.actionLabel, systemImage: address.accessMethod.symbol)
                            }
                        }
                        Button("Remove Address", role: .destructive) {
                            device.networkAddresses.removeAll { $0.id == address.id }
                        }
                    }
                }

                Menu {
                    Button("LAN IP") { addAddress(kind: .lan) }
                    Button("VPN / Tailscale") { addAddress(kind: .vpn) }
                    Button("Other address") { addAddress(kind: .other) }
                } label: {
                    Label("Add Address", systemImage: "plus")
                }
            }

            Section("Placement") {
                Picker("Shelf use", selection: $device.shelfUsage) {
                    ForEach(ShelfUsage.allCases) { Text($0.label).tag($0) }
                }
                .onChange(of: device.shelfUsage) { _, newValue in
                    guard newValue == .dedicated, let rackID = device.rackID, let shelf = device.shelfIndex else { return }
                    if occupiedDedicatedShelves.contains("\(rackID.uuidString):\(shelf)") {
                        device.shelfIndex = nil
                    }
                }
                Picker("Rack", selection: $device.rackID) {
                    Text("Unassigned").tag(nil as UUID?)
                    ForEach(racks) { rack in Text(rack.name).tag(rack.id as UUID?) }
                }
                .onChange(of: device.rackID) { _, _ in device.shelfIndex = nil }

                if let rackID = device.rackID, let rack = racks.first(where: { $0.id == rackID }) {
                    Picker("Shelf", selection: $device.shelfIndex) {
                        Text("Choose a shelf").tag(nil as Int?)
                        ForEach(0..<rack.shelfCount, id: \.self) { shelf in
                            let occupied = occupiedDedicatedShelves.contains("\(rack.id.uuidString):\(shelf)")
                            let canShare = device.shelfUsage == .sharedAccessory
                            Text("Shelf \(shelf + 1)\(occupied ? (canShare ? " — shared" : " — occupied") : "")")
                                .tag(shelf as Int?)
                                .disabled(occupied && !canShare)
                        }
                    }
                }
            }

            Section("Host connections") {
                if device.hostConnections.isEmpty {
                    Text("Assign the accessory's USB, Thunderbolt, or HDMI ports to ports on a Mac or other host device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach($device.hostConnections) { $connection in
                    DisclosureGroup(connectionLabel(connection)) {
                        Picker("Accessory port", selection: $connection.localPortID) {
                            Text("Choose a port").tag(nil as UUID?)
                            ForEach(attachableLocalPorts) { port in
                                Text("\(port.name) · \(port.kind.rawValue)").tag(port.id as UUID?)
                            }
                        }
                        .onChange(of: connection.localPortID) { _, _ in connection.hostPortID = nil }

                        Picker("Host device", selection: $connection.hostDeviceID) {
                            Text("Choose a host").tag(nil as UUID?)
                            ForEach(allDevices.filter { $0.id != device.id }) { host in
                                Text(host.name).tag(host.id as UUID?)
                            }
                        }
                        .onChange(of: connection.hostDeviceID) { _, _ in connection.hostPortID = nil }

                        Picker("Host port", selection: $connection.hostPortID) {
                            Text("Choose a host port").tag(nil as UUID?)
                            ForEach(compatibleHostPorts(for: connection)) { port in
                                Text("\(port.name) · \(port.kind.rawValue)").tag(port.id as UUID?)
                            }
                        }

                        Button("Remove Connection", role: .destructive) {
                            device.hostConnections.removeAll { $0.id == connection.id }
                        }
                    }
                }
                Button {
                    device.hostConnections.append(HostConnection(localPortID: attachableLocalPorts.first?.id))
                } label: {
                    Label("Add Host Connection", systemImage: "cable.connector")
                }
                .disabled(attachableLocalPorts.isEmpty || allDevices.count < 2)
            }

            if !inboundConnectionLabels.isEmpty {
                Section("Attached accessories") {
                    ForEach(Array(inboundConnectionLabels.enumerated()), id: \.offset) { _, label in
                        Label(label, systemImage: "cable.connector.horizontal")
                    }
                }
            }

            Section("Ports") {
                ForEach($device.ports) { $port in
                    DisclosureGroup(port.name) {
                        TextField("Port name", text: $port.name)
                        Picker("Connector", selection: $port.kind) {
                            ForEach(PortKind.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Role", selection: $port.role) {
                            ForEach(PortRole.allCases) { Text($0.rawValue).tag($0) }
                        }
                        if port.kind.isNetwork {
                            Picker("Network", selection: $port.network) {
                                ForEach(NetworkPurpose.allCases) { Text($0.rawValue).tag($0) }
                            }
                            if !port.supportedSpeeds.isEmpty {
                                Picker("Planned speed", selection: $port.selectedSpeed) {
                                    ForEach(port.supportedSpeeds.sorted(), id: \.self) { speed in
                                        Text(speed.label).tag(speed as EthernetSpeed?)
                                    }
                                }
                            }
                        }
                        Button("Remove Port", role: .destructive) {
                            device.ports.removeAll { $0.id == port.id }
                        }
                    }
                }
                Button {
                    device.ports.append(.network("New Port", purpose: .lan, speeds: [.gb1]))
                } label: {
                    Label("Add Port", systemImage: "plus")
                }
            }

            Section("Notes") {
                TextEditor(text: $device.notes).frame(minHeight: 70)
            }

            Section {
                Button("Delete Device", role: .destructive, action: delete)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Device Inspector")
    }

    private var attachableLocalPorts: [DevicePort] {
        device.ports.filter {
            $0.role == .peripheral && $0.kind != .acPower && $0.kind != .storage
        }
    }

    private func addAddress(kind: AddressKind) {
        let method: RemoteAccessMethod = device.category == .computer ? .screenSharing : .https
        device.networkAddresses.append(
            DeviceNetworkAddress(label: kind.rawValue, kind: kind, address: "", accessMethod: method)
        )
    }

    private func compatibleHostPorts(for connection: HostConnection) -> [DevicePort] {
        guard let hostID = connection.hostDeviceID,
              let host = allDevices.first(where: { $0.id == hostID }),
              let localID = connection.localPortID,
              let local = device.ports.first(where: { $0.id == localID }) else { return [] }
        return host.ports.filter { hostPort in
            hostPort.role == .peripheral && compatible(local.kind, hostPort.kind)
        }
    }

    private func compatible(_ local: PortKind, _ host: PortKind) -> Bool {
        if local == host { return true }
        let usb: Set<PortKind> = [.usbA, .usbC]
        if usb.contains(local) && (usb.contains(host) || host == .thunderbolt) { return true }
        if local == .thunderbolt && host == .usbC { return true }
        return false
    }

    private func connectionLabel(_ connection: HostConnection) -> String {
        let local = device.ports.first(where: { $0.id == connection.localPortID })?.name ?? "Accessory port"
        let host = allDevices.first(where: { $0.id == connection.hostDeviceID })?.name ?? "Choose host"
        return "\(local) → \(host)"
    }

    private var inboundConnectionLabels: [String] {
        allDevices.flatMap { accessory in
            accessory.hostConnections.compactMap { connection -> String? in
                guard connection.hostDeviceID == device.id else { return nil }
                let local = accessory.ports.first(where: { $0.id == connection.localPortID })?.name ?? "Accessory port"
                let host = device.ports.first(where: { $0.id == connection.hostPortID })?.name ?? "Host port"
                return "\(accessory.name): \(local) → \(host)"
            }
        }
    }
}
