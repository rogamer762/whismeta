import SwiftUI

@main
struct WhisApp: App {
    @StateObject private var probe = AudioProbe()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(probe: probe)
                .onChange(of: scenePhase) { _, phase in
                    probe.record("App state: \(phase)")
                    probe.refreshRoute()
                }
        }
    }
}
