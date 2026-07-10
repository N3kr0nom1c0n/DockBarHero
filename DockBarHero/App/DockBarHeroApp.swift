import AppKit
import SwiftUI

@main
struct DockBarHeroApp: App {
    var body: some Scene {
        MenuBarExtra("DockBarHero", systemImage: "sparkles") {
            Text("Phase 0")
            Divider()
            Button("Quit DockBarHero") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
