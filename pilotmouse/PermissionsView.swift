import SwiftUI

struct PermissionsView: View {
    @ObservedObject var permissionsManager: PermissionsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Permissions")
                    .font(.headline)
                Text("MousePilot needs Accessibility permission to listen for extra mouse buttons and trigger selected actions.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: permissionsManager.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(permissionsManager.isTrusted ? .green : .orange)

                VStack(alignment: .leading, spacing: 6) {
                    Text(permissionsManager.isTrusted ? "Permission granted" : "Permission missing")
                        .font(.headline)
                    Text(permissionsManager.isTrusted ? "MousePilot can receive supported mouse events." : "The app will open and save settings, but remapping will not work until Accessibility is enabled.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background((permissionsManager.isTrusted ? Color.green : Color.orange).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Button("Open Accessibility Settings") {
                    permissionsManager.openAccessibilitySettings()
                }

                Button("Show Permission Prompt") {
                    permissionsManager.requestPermissionIfNeeded()
                }

                Button("Refresh") {
                    permissionsManager.refresh()
                }
            }

            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
        .onAppear {
            permissionsManager.refresh()
        }
    }
}

#Preview {
    PermissionsView(permissionsManager: PermissionsManager())
}
