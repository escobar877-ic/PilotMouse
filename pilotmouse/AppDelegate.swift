import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private let permissionsManager = PermissionsManager()
    private lazy var mouseEventManager = MouseEventManager(settings: settingsStore.settings)
    private var settingsWindowController: SettingsWindowController?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        settingsStore.onSettingsChanged = { [weak self] settings in
            self?.mouseEventManager.updateSettings(settings)
        }

        let windowController = SettingsWindowController(
            settingsStore: settingsStore,
            permissionsManager: permissionsManager,
            mouseEventManager: mouseEventManager
        )
        settingsWindowController = windowController

        menuBarController = MenuBarController(
            settingsStore: settingsStore,
            mouseEventManager: mouseEventManager,
            settingsWindowController: windowController
        )

        if settingsStore.settings.isEnabled {
            mouseEventManager.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        mouseEventManager.stop()
    }
}
