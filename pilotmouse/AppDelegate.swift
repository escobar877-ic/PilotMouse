import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private let permissionsManager = PermissionsManager()
    private let pointerController = PointerController()
    private let scrollController = ScrollController()
    private let cursorAutoSnappingController = CursorAutoSnappingController()
    private let mouseDeviceMonitor = MouseDeviceMonitor()
    private let themeManager = ThemeManager()
    private lazy var mouseEventManager = MouseEventManager(
        settings: settingsStore.settings,
        permissionsManager: permissionsManager,
        deviceMonitor: mouseDeviceMonitor,
        nativeScrollController: scrollController
    )
    private var settingsWindowController: SettingsWindowController?
    private var menuBarController: MenuBarController?
    private var deviceChangeCancellable: AnyCancellable?
    private var activeDeviceCancellable: AnyCancellable?
    private var wakeObserver: NSObjectProtocol?
    private var terminationSignalSources: [DispatchSourceSignal] = []
    private var hasShutDown = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard activateExistingInstanceIfNeeded() else {
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)
        installTerminationSignalHandlers()
        themeManager.applyTheme(settingsStore.settings.appTheme)

        settingsStore.onSettingsChanged = { [weak self] settings in
            guard let self else { return }
            let bundleIdentifier = self.settingsStore.frontmostApplicationBundleIdentifier
            self.mouseEventManager.updateSettings(settings)
            self.pointerController.handleSettingsChanged(
                settings,
                activeBundleIdentifier: bundleIdentifier
            )
            self.scrollController.handleSettingsChanged(
                settings,
                activeBundleIdentifier: bundleIdentifier
            )
            self.cursorAutoSnappingController.handleSettingsChanged(
                settings,
                activeBundleIdentifier: bundleIdentifier
            )
            self.themeManager.applyTheme(settings.appTheme)
        }

        settingsStore.onFrontmostApplicationChanged = { [weak self] bundleIdentifier in
            guard let self else { return }
            self.mouseEventManager.handleFrontmostApplicationChanged()
            self.pointerController.handleFrontmostApplicationChanged(
                bundleIdentifier,
                settings: self.settingsStore.settings
            )
            self.scrollController.handleFrontmostApplicationChanged(
                bundleIdentifier,
                settings: self.settingsStore.settings
            )
            self.cursorAutoSnappingController.handleFrontmostApplicationChanged(
                bundleIdentifier,
                settings: self.settingsStore.settings
            )
        }

        permissionsManager.onStatusChanged = { [weak self] status in
            guard let self else {
                return
            }

            self.mouseDeviceMonitor.refreshAuthorization()
            let settings = self.settingsStore.settings
            let bundleIdentifier = self.settingsStore.frontmostApplicationBundleIdentifier
            self.pointerController.refreshAuthorizationAndReapply(
                settings,
                activeBundleIdentifier: bundleIdentifier
            )
            self.scrollController.refreshAuthorizationAndReapply(
                settings,
                activeBundleIdentifier: bundleIdentifier
            )

            if status.isReady,
               self.mouseDeviceMonitor.isMonitoring,
               settings.isEnabled {
                self.mouseEventManager.start()
            } else {
                self.mouseEventManager.stop()
            }
        }

        let windowController = SettingsWindowController(
            settingsStore: settingsStore,
            permissionsManager: permissionsManager,
            mouseEventManager: mouseEventManager,
            pointerController: pointerController,
            scrollController: scrollController,
            mouseDeviceMonitor: mouseDeviceMonitor,
            themeManager: themeManager
        )
        settingsWindowController = windowController

        menuBarController = MenuBarController(
            settingsStore: settingsStore,
            settingsWindowController: windowController
        )

        migrateLegacyDeviceProfileIdentifiers(mouseDeviceMonitor.devices)
        observeHardwareChanges()
        permissionsManager.startMonitoring()

        if settingsStore.settings.isEnabled {
            mouseEventManager.start()
        }

        let frontmostBundleIdentifier = settingsStore.frontmostApplicationBundleIdentifier
        pointerController.handleSettingsChanged(
            settingsStore.settings,
            activeBundleIdentifier: frontmostBundleIdentifier
        )
        scrollController.handleSettingsChanged(
            settingsStore.settings,
            activeBundleIdentifier: frontmostBundleIdentifier
        )
        cursorAutoSnappingController.start(
            settings: settingsStore.settings,
            activeBundleIdentifier: frontmostBundleIdentifier
        )
        windowController.showWindow()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        permissionsManager.refresh()
        if !mouseDeviceMonitor.isMonitoring {
            mouseDeviceMonitor.refreshAuthorization()
        }
        if permissionsManager.status.isReady,
           mouseDeviceMonitor.isMonitoring,
           settingsStore.settings.isEnabled {
            mouseEventManager.start()
        } else {
            mouseEventManager.stop()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindowController?.showWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        shutDown()
    }

    private func installTerminationSignalHandlers() {
        for signalNumber in [SIGTERM, SIGINT] {
            signal(signalNumber, SIG_IGN)

            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleTerminationSignal()
                }
            }
            source.resume()
            terminationSignalSources.append(source)
        }
    }

    private func activateExistingInstanceIfNeeded() -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return true
        }

        let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        guard let existingApplication = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { $0.processIdentifier != ownProcessIdentifier }) else {
            return true
        }

        existingApplication.activate(options: [.activateAllWindows])
        return false
    }

    private func observeHardwareChanges() {
        deviceChangeCancellable = mouseDeviceMonitor.$devices
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] devices in
                guard let self else { return }
                self.mouseEventManager.handleHardwareDevicesChanged()
                self.migrateLegacyDeviceProfileIdentifiers(devices)
                self.reapplyCurrentHardwareSettings()
            }

        activeDeviceCancellable = mouseDeviceMonitor.$lastActiveDeviceIdentifier
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] deviceIdentifier in
                guard let self else { return }
                self.cursorAutoSnappingController.handleActiveDeviceChanged(
                    deviceIdentifier,
                    settings: self.settingsStore.settings,
                    activeBundleIdentifier: self.settingsStore.frontmostApplicationBundleIdentifier
                )
            }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.mouseDeviceMonitor.refreshAuthorization()
                self.reapplyCurrentHardwareSettings()
                if self.permissionsManager.status.isReady,
                   self.mouseDeviceMonitor.isMonitoring,
                   self.settingsStore.settings.isEnabled {
                    self.mouseEventManager.restart()
                } else {
                    self.mouseEventManager.stop()
                }
            }
        }
    }

    private func reapplyCurrentHardwareSettings() {
        let settings = settingsStore.settings
        let bundleIdentifier = settingsStore.frontmostApplicationBundleIdentifier
        pointerController.refreshAuthorizationAndReapply(
            settings,
            activeBundleIdentifier: bundleIdentifier
        )
        scrollController.refreshAuthorizationAndReapply(
            settings,
            activeBundleIdentifier: bundleIdentifier
        )
    }

    private func migrateLegacyDeviceProfileIdentifiers(
        _ devices: [MouseDeviceDescriptor]
    ) {
        for device in devices {
            if let legacyIdentifier = MouseDeviceIdentity.legacyNamedIdentifier(
                vendorID: device.vendorID,
                productID: device.productID,
                serialNumber: device.serialNumber,
                transport: device.transport,
                name: device.name
            ) {
                settingsStore.migrateDeviceProfileIdentifier(
                    from: legacyIdentifier,
                    to: device.identifier
                )
            }

            if let legacyIdentifier = MouseDeviceIdentity.legacyLocationIdentifier(
                vendorID: device.vendorID,
                productID: device.productID,
                serialNumber: device.serialNumber,
                locationID: device.locationID
            ) {
                settingsStore.migrateDeviceProfileIdentifier(
                    from: legacyIdentifier,
                    to: device.identifier
                )
            }
        }
    }

    private func handleTerminationSignal() {
        shutDown()
        NSApp.terminate(nil)
    }

    private func shutDown() {
        guard !hasShutDown else {
            return
        }

        hasShutDown = true
        deviceChangeCancellable?.cancel()
        deviceChangeCancellable = nil
        activeDeviceCancellable?.cancel()
        activeDeviceCancellable = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        mouseEventManager.stop()
        cursorAutoSnappingController.stop()
        scrollController.restoreOriginalScrollSettings()
        pointerController.restoreOriginalMouseSettings()
        mouseDeviceMonitor.stopMonitoring()
        permissionsManager.stopMonitoring()
    }
}
