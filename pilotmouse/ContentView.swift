import SwiftUI

struct ContentView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var permissionsManager: PermissionsManager
    @ObservedObject var mouseEventManager: MouseEventManager
    @ObservedObject var pointerController: PointerController
    @ObservedObject var themeManager: ThemeManager

    var body: some View {
        SettingsView(
            settingsStore: settingsStore,
            permissionsManager: permissionsManager,
            mouseEventManager: mouseEventManager,
            pointerController: pointerController,
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
        themeManager: ThemeManager()
    )
    .preferredColorScheme(.dark)
}
