import SwiftUI

@main
struct DockBarHeroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("DockBarHero", systemImage: "sparkles") {
            MenuBarContent(model: appDelegate.model, send: appDelegate.send)
        }
        .menuBarExtraStyle(.menu)
    }
}
