import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: 32)
    private let settingsStore: SettingsStore
    private let mouseEventManager: MouseEventManager
    private let settingsWindowController: SettingsWindowController
    private let menu = NSMenu()
    private let startStopItem = NSMenuItem()
    private var cancellables = Set<AnyCancellable>()

    init(settingsStore: SettingsStore, mouseEventManager: MouseEventManager, settingsWindowController: SettingsWindowController) {
        self.settingsStore = settingsStore
        self.mouseEventManager = mouseEventManager
        self.settingsWindowController = settingsWindowController
        super.init()
        configureStatusItem()
        configureMenu()
        observeSettings()
    }

    private func configureStatusItem() {
        statusItem.length = 32

        guard let button = statusItem.button else {
            return
        }

        let image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "MousePilot")
            ?? NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: "MousePilot")

        if let image {
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
        } else {
            button.title = "MP"
        }

        button.toolTip = "MousePilot"
    }

    private func configureMenu() {
        let openItem = NSMenuItem(title: "Open MousePilot", action: #selector(openMousePilot), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        startStopItem.action = #selector(toggleEnabled)
        startStopItem.target = self
        menu.addItem(startStopItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        updateStartStopTitle()
    }

    private func observeSettings() {
        settingsStore.$settings
            .sink { [weak self] _ in
                self?.updateStartStopTitle()
            }
            .store(in: &cancellables)
    }

    private func updateStartStopTitle() {
        startStopItem.title = settingsStore.settings.isEnabled ? "Stop" : "Start"
    }

    @objc private func openMousePilot() {
        settingsWindowController.showWindow()
    }

    @objc private func toggleEnabled() {
        let enabled = !settingsStore.settings.isEnabled
        settingsStore.setEnabled(enabled)

        if enabled {
            mouseEventManager.start()
        } else {
            mouseEventManager.stop()
        }

        updateStartStopTitle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
