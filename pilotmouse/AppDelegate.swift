import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private let permissionsManager = PermissionsManager()
    private let pointerController = PointerController()
    private let themeManager = ThemeManager()
    private lazy var mouseEventManager = MouseEventManager(settings: settingsStore.settings, permissionsManager: permissionsManager)
    private var settingsWindowController: SettingsWindowController?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        themeManager.applyTheme(settingsStore.settings.appTheme)

        settingsStore.onSettingsChanged = { [weak self] settings in
            self?.mouseEventManager.updateSettings(settings)
            self?.pointerController.handleSettingsChanged(settings)
            self?.themeManager.applyTheme(settings.appTheme)
        }

        permissionsManager.onTrustChanged = { [weak self] trusted in
            guard let self, trusted, self.settingsStore.settings.isEnabled else {
                return
            }

            self.mouseEventManager.restart()
        }

        let windowController = SettingsWindowController(
            settingsStore: settingsStore,
            permissionsManager: permissionsManager,
            mouseEventManager: mouseEventManager,
            pointerController: pointerController,
            themeManager: themeManager
        )
        settingsWindowController = windowController

        menuBarController = MenuBarController(
            settingsStore: settingsStore,
            mouseEventManager: mouseEventManager,
            settingsWindowController: windowController
        )

        permissionsManager.startMonitoring()

        if settingsStore.settings.isEnabled {
            mouseEventManager.start()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.settingsStore.settings.pointerControlEnabled else {
                return
            }

            self.pointerController.scheduleApplySpeedLevel(self.settingsStore.settings.mouseSpeedLevel)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        permissionsManager.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionsManager.stopMonitoring()
        mouseEventManager.stop()
    }
}
