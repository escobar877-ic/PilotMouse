import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let settingsStore: SettingsStore
    private let permissionsManager: PermissionsManager
    private let mouseEventManager: MouseEventManager
    private let pointerController: PointerController
    private let themeManager: ThemeManager
    private var window: NSWindow?

    init(settingsStore: SettingsStore, permissionsManager: PermissionsManager, mouseEventManager: MouseEventManager, pointerController: PointerController, themeManager: ThemeManager) {
        self.settingsStore = settingsStore
        self.permissionsManager = permissionsManager
        self.mouseEventManager = mouseEventManager
        self.pointerController = pointerController
        self.themeManager = themeManager
    }

    func showWindow() {
        permissionsManager.refresh()

        if window == nil {
            let contentView = ContentView(
                settingsStore: settingsStore,
                permissionsManager: permissionsManager,
                mouseEventManager: mouseEventManager,
                pointerController: pointerController,
                themeManager: themeManager
            )
            let rootView = contentView
                .frame(minWidth: 780, idealWidth: 860, minHeight: 560, idealHeight: 640)
            let hostingController = NSHostingController(rootView: rootView)
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 860, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            settingsWindow.contentViewController = hostingController
            settingsWindow.title = "MousePilot"
            settingsWindow.titleVisibility = .hidden
            settingsWindow.titlebarAppearsTransparent = true
            settingsWindow.backgroundColor = .windowBackgroundColor
            settingsWindow.isOpaque = true
            settingsWindow.minSize = NSSize(width: 780, height: 560)
            settingsWindow.setContentSize(NSSize(width: 860, height: 640))
            settingsWindow.setFrameAutosaveName("MousePilotSettingsWindowV3")
            settingsWindow.isReleasedWhenClosed = false
            settingsWindow.delegate = self
            settingsWindow.center()
            themeManager.applyTheme(settingsStore.settings.appTheme, to: settingsWindow)
            window = settingsWindow
        }

        if let window {
            themeManager.applyTheme(settingsStore.settings.appTheme, to: window)

            if window.frame.width < 780 || window.frame.height < 560 {
                window.setContentSize(NSSize(width: 860, height: 640))
                window.center()
            }
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
