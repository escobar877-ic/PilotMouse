import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let settingsStore: SettingsStore
    private let settingsWindowController: SettingsWindowController
    private let menu = NSMenu()
    private let startStopItem = NSMenuItem()
    private var cancellables = Set<AnyCancellable>()

    init(settingsStore: SettingsStore, settingsWindowController: SettingsWindowController) {
        self.settingsStore = settingsStore
        self.settingsWindowController = settingsWindowController
        super.init()
        configureStatusItem()
        configureMenu()
        observeSettings()
        updateStatusItemAppearance()
    }

    private func configureStatusItem() {
        statusItem.length = NSStatusItem.squareLength

        guard let button = statusItem.button else {
            return
        }

        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.isBordered = false
        button.wantsLayer = false
        button.contentTintColor = nil
        button.state = .off
        button.toolTip = "MousePilot"
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureMenu() {
        let titleItem = NSMenuItem(title: "MousePilot", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "Open MousePilot", action: #selector(openSettingsWindowFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        startStopItem.action = #selector(toggleEnabled)
        startStopItem.target = self
        menu.addItem(startStopItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func observeSettings() {
        settingsStore.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemAppearance()
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemAppearance() {
        let enabled = settingsStore.settings.isEnabled

        if let button = statusItem.button {
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            button.image = makeStatusImage()
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.isBordered = false
            button.wantsLayer = false
            button.contentTintColor = nil
            button.state = .off
            button.toolTip = enabled ? "MousePilot - Enabled" : "MousePilot - Stopped"
        }

        startStopItem.title = enabled ? "Stop" : "Start"
    }

    private func makeStatusImage() -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "MousePilot")?
            .withSymbolConfiguration(config)
            ?? NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: "MousePilot")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            openSettingsWindow()
            return
        }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            openSettingsWindow()
        }
    }

    private func showMenu() {
        updateStatusItemAppearance()

        guard let button = statusItem.button else {
            return
        }

        let location = NSPoint(x: 0, y: button.bounds.height)
        menu.popUp(positioning: nil, at: location, in: button)
        button.state = .off
        button.highlight(false)
    }

    @objc private func openSettingsWindowFromMenu() {
        openSettingsWindow()
    }

    private func openSettingsWindow() {
        settingsWindowController.showWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleEnabled() {
        let enabled = !settingsStore.settings.isEnabled
        settingsStore.setEnabled(enabled)
        updateStatusItemAppearance()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
