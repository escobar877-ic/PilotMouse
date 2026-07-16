import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var permissionsManager: PermissionsManager
    @ObservedObject var mouseEventManager: MouseEventManager
    @ObservedObject var pointerController: PointerController
    @ObservedObject var scrollController: ScrollController
    @ObservedObject var mouseDeviceMonitor: MouseDeviceMonitor
    @ObservedObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            TopNavigationBarView(settingsStore: settingsStore)

            HeaderView(
                settingsStore: settingsStore,
                permissionsManager: permissionsManager,
                mouseEventManager: mouseEventManager
            )

            Divider()

            selectedContent
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(AppColors.windowBackground)
        }
        .frame(minWidth: 780, idealWidth: 860, maxWidth: .infinity, minHeight: 560, idealHeight: 640, maxHeight: .infinity)
        .background(AppColors.windowBackground.ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(settingsStore.settings.appTheme.colorScheme)
        .id("theme-\(settingsStore.settings.appTheme.rawValue)")
        .onAppear {
            permissionsManager.refresh()
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch settingsStore.settings.selectedTab {
        case .buttons:
            ButtonsSettingsView(settingsStore: settingsStore, mouseEventManager: mouseEventManager)
        case .wheel:
            WheelSettingsView(
                settingsStore: settingsStore,
                mouseEventManager: mouseEventManager,
                scrollController: scrollController
            )
        case .pointer:
            PointerSettingsView(settingsStore: settingsStore, pointerController: pointerController)
        case .profiles:
            ProfilesSettingsView(
                settingsStore: settingsStore,
                mouseDeviceMonitor: mouseDeviceMonitor
            )
        case .permissions:
            PermissionsView(permissionsManager: permissionsManager)
        case .about:
            AboutView(settingsStore: settingsStore, pointerController: pointerController, themeManager: themeManager)
        }
    }
}

#Preview {
    let permissionsManager = PermissionsManager()
    SettingsView(
        settingsStore: SettingsStore(),
        permissionsManager: permissionsManager,
        mouseEventManager: MouseEventManager(settings: .defaultSettings, permissionsManager: permissionsManager),
        pointerController: PointerController(),
        scrollController: ScrollController(),
        mouseDeviceMonitor: MouseDeviceMonitor(),
        themeManager: ThemeManager()
    )
}
