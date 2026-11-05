import SwiftUI

@main
struct NotedApp: App {
    #if DEBUG
    @State private var showGateFixtures = ProcessInfo.processInfo.arguments.contains("--device-gate-fixtures")
    @State private var showGateInbox = false

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--e5-load-probe") {
            IntelligenceResourceProbe.recordE5Load(variant: arguments.dropFirst(index + 1).first ?? "int8")
        }
    }
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

