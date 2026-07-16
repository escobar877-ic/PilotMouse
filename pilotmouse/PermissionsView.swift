import SwiftUI

struct PermissionsView: View {
    @ObservedObject var permissionsManager: PermissionsManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Permissions")
                        .font(.headline)
                    Text("MousePilot needs Accessibility and event access to listen for mouse input, suppress remapped buttons, and post selected actions.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: permissionsManager.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(permissionsManager.isTrusted ? .green : .orange)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(permissionsManager.isTrusted ? "Permissions ready" : "Permissions missing")
                            .font(.headline)
                        Text(permissionsManager.isTrusted ? "MousePilot can identify connected mice, receive events, and trigger selected actions." : "MousePilot needs Accessibility and direct mouse input access for all configured actions and device profiles.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((permissionsManager.isTrusted ? Color.green : Color.orange).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                actionButtons

                VStack(alignment: .leading, spacing: 8) {
                    permissionRow("Accessibility", granted: permissionsManager.status.accessibilityTrusted)
                    permissionRow("Core Graphics event listening", granted: permissionsManager.status.listenEventAccess)
                    permissionRow("Direct HID mouse input", granted: permissionsManager.status.hidListenEventAccess)
                    permissionRow("Core Graphics event posting", granted: permissionsManager.status.postEventAccess)
                    permissionRow("Post shortcut actions", granted: permissionsManager.status.postShortcutActions)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8))

                if !permissionsManager.isTrusted {
                    Text("Permission status refreshes automatically. If System Settings already shows MousePilot enabled but direct HID access remains missing, remove old MousePilot entries, reveal the current build, add that exact app again, and relaunch it.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Current build")
                        .font(.subheadline.weight(.semibold))
                    labeledValue("Bundle ID", permissionsManager.currentBundleIdentifier)
                    labeledValue("App Path", permissionsManager.currentAppPath)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.top, 12)
            .padding(.horizontal, 4)
            .padding(.bottom, 16)
        }
        .background(AppColors.windowBackground)
        .onAppear {
            permissionsManager.startMonitoring()
        }
    }

    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button("Request Permissions") {
                    permissionsManager.requestPermissionIfNeeded()
                }
                .keyboardShortcut(.defaultAction)

                Button("Open Privacy Settings") {
                    permissionsManager.openAccessibilitySettings()
                }

                Button("Open Input Monitoring Settings") {
                    permissionsManager.openInputMonitoringSettings()
                }
            }

            HStack(spacing: 10) {
                Button("Refresh") {
                    permissionsManager.refresh()
                }

                Button("Reveal Current Build") {
                    permissionsManager.revealCurrentBuildInFinder()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func permissionRow(_ title: String, granted: Bool) -> some View {
        HStack {
            Label(granted ? "Granted" : "Missing", systemImage: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .orange)
                .frame(width: 110, alignment: .leading)
            Text(title)
            Spacer()
        }
        .font(.callout)
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }
}

#Preview {
    PermissionsView(permissionsManager: PermissionsManager())
}
