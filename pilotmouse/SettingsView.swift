import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var permissionsManager: PermissionsManager
    @ObservedObject var mouseEventManager: MouseEventManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            TabView {
                ButtonsSettingsView(settingsStore: settingsStore)
                    .tabItem { Label("Buttons", systemImage: "computermouse") }

                WheelSettingsView(settingsStore: settingsStore)
                    .tabItem { Label("Wheel", systemImage: "arrow.up.and.down") }

                PointerSettingsView(settingsStore: settingsStore)
                    .tabItem { Label("Pointer", systemImage: "cursorarrow.motionlines") }

                PermissionsView(permissionsManager: permissionsManager)
                    .tabItem { Label("Permissions", systemImage: "lock.shield") }

                AboutView()
                    .tabItem { Label("About", systemImage: "info.circle") }
            }
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 520)
        .onAppear {
            permissionsManager.refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MousePilot")
                    .font(.title2.bold())
                Text("Local mouse customization for macOS")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("Enabled", isOn: enabledBinding)
                .toggleStyle(.switch)

            statusBadge(
                text: mouseEventManager.isRunning ? "Event tap active" : "Event tap stopped",
                systemImage: mouseEventManager.isRunning ? "checkmark.circle.fill" : "pause.circle.fill",
                color: mouseEventManager.isRunning ? .green : .secondary
            )

            statusBadge(
                text: permissionsManager.isTrusted ? "Permission granted" : "Permission missing",
                systemImage: permissionsManager.isTrusted ? "lock.open.fill" : "lock.trianglebadge.exclamationmark.fill",
                color: permissionsManager.isTrusted ? .green : .orange
            )
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.isEnabled },
            set: { settingsStore.setEnabled($0) }
        )
    }

    private func statusBadge(text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }
}

#Preview {
    SettingsView(
        settingsStore: SettingsStore(),
        permissionsManager: PermissionsManager(),
        mouseEventManager: MouseEventManager(settings: .defaultSettings)
    )
}
