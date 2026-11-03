import AppKit
import SwiftUI

struct RackPlannerCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            RackPlannerOpenWindowButton(label: "About Rack Planner", windowID: "about")
        }

        CommandGroup(replacing: .help) {
            RackPlannerOpenWindowButton(label: "Rack Planner Help", windowID: "help")
            .keyboardShortcut("?", modifiers: .command)

            Link("Full User Guide", destination: RackPlannerLinks.userGuide)
            Link("Report an Issue", destination: RackPlannerLinks.issues)

            Divider()

            Link("Visit code.matx.ca", destination: RackPlannerLinks.website)
        }
    }
}

enum RackPlannerLinks {
    static let website = URL(string: "https://code.matx.ca")!
    static let repository = URL(string: "https://github.com/macvfx/rackPlanner")!
    static let userGuide = URL(string: "https://github.com/macvfx/rackPlanner/blob/main/Docs/USER_GUIDE.md")!
    static let issues = URL(string: "https://github.com/macvfx/rackPlanner/issues")!
}

private struct RackPlannerOpenWindowButton: View {
    let label: String
    let windowID: String
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(label) {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: windowID)
        }
    }
}
