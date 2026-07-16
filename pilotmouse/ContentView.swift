import SwiftUI

struct ContentView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var permissionsManager: PermissionsManager
    @ObservedObject var mouseEventManager: MouseEventManager
    @ObservedObject var pointerController: PointerController
    @ObservedObject var scrollController: ScrollController
    @ObservedObject var mouseDeviceMonitor: MouseDeviceMonitor
    @ObservedObject var themeManager: ThemeManager

    var body: some View {
        SettingsView(
            settingsStore: settingsStore,
            permissionsManager: permissionsManager,
            mouseEventManager: mouseEventManager,
            pointerController: pointerController,
            scrollController: scrollController,
            mouseDeviceMonitor: mouseDeviceMonitor,
            themeManager: themeManager
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.windowBackground)
    }
}

#Preview("System") {
    let permissionsManager = PermissionsManager()
    ContentView(
        settingsStore: SettingsStore(),
        permissionsManager: permissionsManager,
        mouseEventManager: MouseEventManager(settings: .defaultSettings, permissionsManager: permissionsManager),
        pointerController: PointerController(),
        scrollController: ScrollController(),
        mouseDeviceMonitor: MouseDeviceMonitor(),
        themeManager: ThemeManager()
    )
}

#Preview("Dark") {
    let permissionsManager = PermissionsManager()
    let settingsStore = SettingsStore(userDefaults: UserDefaults(suiteName: "MousePilot.DarkPreview") ?? .standard)
    ContentView(
        settingsStore: settingsStore,
        permissionsManager: permissionsManager,
        mouseEventManager: MouseEventManager(settings: .defaultSettings, permissionsManager: permissionsManager),
        pointerController: PointerController(),
        scrollController: ScrollController(),
        mouseDeviceMonitor: MouseDeviceMonitor(),
        themeManager: ThemeManager()
    )
    .preferredColorScheme(.dark)
}
