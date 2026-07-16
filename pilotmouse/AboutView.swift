import SwiftUI

struct AboutView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var pointerController: PointerController
    @ObservedObject var themeManager: ThemeManager
    @State private var showsResetConfirmation = false

    private let principles = [
        "Local only",
        "No account",
        "No subscription",
        "No telemetry",
        "Settings are stored locally"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("MousePilot")
                    .font(.largeTitle.bold())
                Text("Version \(versionText)")
                    .foregroundStyle(.secondary)
                Text("Local mouse customization tool for macOS")
                    .font(.headline)
                    .padding(.top, 6)
            }

            Text("Built for mouse buttons, scrolling, cursor control, and application profiles without accounts, subscriptions, telemetry, or cloud sync.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(principles, id: \.self) { principle in
                    Label(principle, systemImage: "checkmark.circle")
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Appearance")
                    .font(.headline)
                Picker("Appearance", selection: themeBinding) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Launch MousePilot at login", isOn: launchAtLoginBinding)
                    .toggleStyle(.switch)

                if settingsStore.launchAtLoginRequiresApproval {
                    Button {
                        settingsStore.openLoginItemsSettings()
                    } label: {
                        Label("Open Login Items", systemImage: "gear")
                    }
                }

                if let error = settingsStore.launchAtLoginError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("Open-source ready: local settings, no network requests, no analytics, and no external dependencies.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button("Reset Settings", role: .destructive) {
                showsResetConfirmation = true
            }
            .confirmationDialog("Reset MousePilot settings?", isPresented: $showsResetConfirmation) {
                Button("Reset Settings", role: .destructive) {
                    settingsStore.resetToDefaults()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This restores local settings to defaults. macOS permissions are not changed.")
            }

            Spacer()
        }
        .padding(.top, 16)
        .padding(.horizontal, 4)
        .background(AppColors.windowBackground)
        .onAppear {
            settingsStore.refreshLaunchAtLoginStatus()
        }
    }

    private var themeBinding: Binding<AppTheme> {
        Binding(
            get: { settingsStore.settings.appTheme },
            set: { theme in
                settingsStore.setAppTheme(theme)
                themeManager.applyTheme(theme)
            }
        )
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.launchAtLoginEnabled },
            set: { settingsStore.setLaunchAtLoginEnabled($0) }
        )
    }
}

#Preview {
    AboutView(settingsStore: SettingsStore(), pointerController: PointerController(), themeManager: ThemeManager())
}
