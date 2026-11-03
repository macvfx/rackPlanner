import SwiftUI

@main
struct RackPlannerApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: RackPlanDocument()) { file in
            ContentView(document: file.$document)
        }
        .commands {
            SidebarCommands()
            InspectorCommands()
            RackPlannerCommands()
        }

        Window("About Rack Planner", id: "about") {
            AboutRackPlannerView()
                .frame(width: 420, height: 430)
        }
        .windowResizability(.contentSize)

        Window("Rack Planner Help", id: "help") {
            RackPlannerHelpView()
                .frame(minWidth: 680, minHeight: 560)
        }
        .windowResizability(.contentSize)
    }
}
