import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let settingsStore: SettingsStore
    private let permissionsManager: PermissionsManager
    private let mouseEventManager: MouseEventManager
    private var window: NSWindow?

    init(settingsStore: SettingsStore, permissionsManager: PermissionsManager, mouseEventManager: MouseEventManager) {
        self.settingsStore = settingsStore
        self.permissionsManager = permissionsManager
        self.mouseEventManager = mouseEventManager
    }

    func showWindow() {
        permissionsManager.refresh()

        if window == nil {
            let contentView = ContentView(
                settingsStore: settingsStore,
                permissionsManager: permissionsManager,
                mouseEventManager: mouseEventManager
            )
            let hostingController = NSHostingController(rootView: contentView)
            let settingsWindow = NSWindow(contentViewController: hostingController)
            settingsWindow.title = "MousePilot"
            settingsWindow.setContentSize(NSSize(width: 620, height: 520))
            settingsWindow.minSize = NSSize(width: 600, height: 500)
            settingsWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            settingsWindow.isReleasedWhenClosed = false
            settingsWindow.delegate = self
            settingsWindow.center()
            window = settingsWindow
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
