import AppKit
import SwiftUI

struct AboutRackPlannerView: View {
    @Environment(\.openWindow) private var openWindow

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 92, height: 92)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("Rack Planner").font(.title.bold())
                Text("Version \(version) (\(build))").foregroundStyle(.secondary)
            }

            Text("Plan equipment shelves, physical connections, network capacity, and UPS outlets for a home lab or small office.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 370)

            Label {
                Text("Your plans stay on this Mac. Rack Planner has no account, analytics, updater, cloud service, or background service. Support links connect only when you open them.")
            } icon: {
                Image(systemName: "hand.raised.fill").foregroundStyle(.tint)
            }
            .font(.callout)
            .padding(12)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 12) {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "help")
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }
                Link("User Guide", destination: RackPlannerLinks.userGuide)
            }

            Link("code.matx.ca", destination: RackPlannerLinks.website)
                .font(.callout)

            Text("Copyright © 2026 Mat X")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(26)
        .frame(width: 420, height: 430)
    }
}

struct RackPlannerHelpView: View {
    private enum Topic: String, CaseIterable, Identifiable {
        case quickStart = "Quick Start"
        case connections = "Connections"
        case planning = "Capacity & Export"
        case privacy = "Privacy & Help"
        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var topic: Topic = .quickStart

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 54, height: 54)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rack Planner Help").font(.title.bold())
                    Text("Plan shelves, connections, networks, and power")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(22)

            Picker("Help Topic", selection: $topic) {
                ForEach(Topic.allCases) { topic in
                    Text(topic.rawValue).tag(topic)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 22)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch topic {
                    case .quickStart: quickStart
                    case .connections: connections
                    case .planning: planning
                    case .privacy: privacy
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }

            Divider()

            HStack {
                Link("Full User Guide", destination: RackPlannerLinks.userGuide)
                Spacer()
                Link("code.matx.ca", destination: RackPlannerLinks.website)
                Spacer()
                Link("Source", destination: RackPlannerLinks.repository)
            }
            .padding(18)
        }
        .frame(minWidth: 680, minHeight: 560)
    }

    private var quickStart: some View {
        Group {
            HelpSection(title: "1. Add equipment", icon: "shippingbox") {
                Text("Add a preset from the Device Library. Drag it to a shelf, or add it to Unassigned and place it later.")
            }
            HelpSection(title: "2. Arrange shelves", icon: "rectangle.stack") {
                Text("A shelf accepts one dedicated device plus shared accessories. Select a device to edit its name, model, ports, power estimate, and notes.")
            }
            HelpSection(title: "3. Review the plan", icon: "checklist") {
                Text("Overview summarizes devices, occupied shelves, network shortages, UPS outlets, and entered watts.")
            }
        }
    }

    private var connections: some View {
        Group {
            HelpSection(title: "Accessory connections", icon: "cable.connector.horizontal") {
                Text("Select a KVM, drive, dock, or adapter. Under Host connections, choose its local USB, Thunderbolt, or HDMI port, the host device, and a compatible host port. Add one entry per cable.")
            }
            HelpSection(title: "Shared shelves", icon: "square.stack.3d.up") {
                Text("KVMs, adapters, docks, drives, and small hubs can share the host's shelf. The shelf is occupied once, while each physical connection remains visible.")
            }
            HelpSection(title: "Quick access", icon: "network") {
                Text("Store a hostname plus LAN, VPN/Tailscale, or other addresses. HTTP, HTTPS, Screen Sharing/VNC, and SSH entries become clickable links. Rack Planner does not test reachability or authenticate.")
            }
        }
    }

    private var planning: some View {
        Group {
            HelpSection(title: "Network capacity", icon: "point.3.connected.trianglepath.dotted") {
                Text("LAN and Production LAN demand are calculated separately. Rack Planner deducts inferred inter-switch uplinks, applies the spare-port target, and reports shortages.")
            }
            HelpSection(title: "Verify the recommendation", icon: "exclamationmark.triangle") {
                Text("Confirm real switch negotiation speeds, media, VLAN, routing, and uplink design before purchasing. Recommendations are planning guidance.")
            }
            HelpSection(title: "CSV export", icon: "tablecells") {
                Text("Export device, port, connection, quick-access, network-requirement, and power CSV files for review outside the app.")
            }
        }
    }

    private var privacy: some View {
        Group {
            HelpSection(title: "Privacy", icon: "hand.raised.fill") {
                Text("Rack Planner works locally and has no account, analytics, updater, cloud service, or background service. It does not upload projects, hostnames, addresses, notes, usage information, or diagnostics.")
                Text("Support and quick-access links contact their destinations only when you click them. Saved projects and exported CSVs may contain sensitive network information, so share them carefully.")
            }
            HelpSection(title: "Current boundaries", icon: "scope") {
                Text("This version does not route graphical Ethernet or power cables, calculate cable lengths, model VLAN trunks or LACP, estimate UPS runtime, or place equipment in exact rack units.")
            }
            HelpSection(title: "More help", icon: "questionmark.circle") {
                Text("Use the Full User Guide for complete operation and troubleshooting, or Report an Issue from the Help menu.")
                Link("Report an Issue", destination: RackPlannerLinks.issues)
            }
        }
    }
}

private struct HelpSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                content
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
