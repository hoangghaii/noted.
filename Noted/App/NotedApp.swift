import SwiftUI

@main
struct NotedApp: App {
    #if DEBUG
    @State private var showGateFixtures = ProcessInfo.processInfo.arguments.contains("--device-gate-fixtures")
    @State private var showGateInbox = false
    #endif
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if showGateFixtures {
                DeviceGateFixturesView(onInbox: { showGateFixtures = false; showGateInbox = true })
            } else if showGateInbox { ShareGateInboxView() }
            else { LibraryStartupView() }
            #else
            LibraryStartupView()
            #endif
        }
    }

}

