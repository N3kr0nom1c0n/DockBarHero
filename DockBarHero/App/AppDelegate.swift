import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        do {
            let scene = try PrototypeSceneHost()
            let window = OverlayWindowController(contentView: scene.view)
            let screen = AppKitScreenProvider()
            let monitor = EnvironmentMonitor(evaluator: WorkspaceEnvironmentEvaluator())
            model.connect(window: window, scene: scene, screen: screen, monitor: monitor)
            model.start()
            AppLog.lifecycle.info("DockBarHero launched")
        } catch {
            AppLog.scene.error("Scene bootstrap failed: \(error.localizedDescription)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    func send(_ action: OverlayAction) {
        model.send(action)
    }
}
