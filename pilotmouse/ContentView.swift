import SwiftUI

struct ContentView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var permissionsManager: PermissionsManager
    @ObservedObject var mouseEventManager: MouseEventManager

    var body: some View {
        SettingsView(
            settingsStore: settingsStore,
            permissionsManager: permissionsManager,
            mouseEventManager: mouseEventManager
        )
    }
}

#Preview {
    ContentView(
        settingsStore: SettingsStore(),
        permissionsManager: PermissionsManager(),
        mouseEventManager: MouseEventManager(settings: .defaultSettings)
    )
}
