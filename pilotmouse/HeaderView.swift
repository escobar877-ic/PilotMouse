import SwiftUI

struct HeaderView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var permissionsManager: PermissionsManager
    @ObservedObject var mouseEventManager: MouseEventManager

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "computermouse")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("MousePilot")
                        .font(.title3.bold())
                        .lineLimit(1)
                    Text("Local mouse customization for macOS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            Spacer(minLength: 10)

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text("Enabled")
                        .font(.callout)
                        .lineLimit(1)
                        .fixedSize()

                    Toggle("", isOn: enabledBinding)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .frame(width: 52)
                }
                .layoutPriority(2)

                StatusBadgeView(
                    title: mouseEventManager.isRunning ? "Active" : "Stopped",
                    systemImage: mouseEventManager.isRunning ? "checkmark.circle.fill" : "pause.circle.fill",
                    style: mouseEventManager.isRunning ? .success : .neutral
                )
                .help(mouseEventManager.isRunning ? "Mouse event tap active" : "Mouse event tap stopped")

                StatusBadgeView(
                    title: eventStatusTitle,
                    systemImage: mouseEventManager.lastErrorReason == nil ? "waveform.path.ecg" : "exclamationmark.triangle.fill",
                    style: mouseEventManager.lastErrorReason == nil ? .info : .warning
                )
                .help(mouseEventManager.lastErrorReason ?? mouseEventManager.lastEventDescription)

                StatusBadgeView(
                    title: permissionsManager.isTrusted ? "Ready" : "Missing",
                    systemImage: permissionsManager.isTrusted ? "lock.open.fill" : "lock.trianglebadge.exclamationmark.fill",
                    style: permissionsManager.isTrusted ? .success : .warning
                )
                .help(permissionsManager.isTrusted ? "Required permissions granted" : "Required permissions missing")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(AppColors.windowBackground)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.isEnabled },
            set: { settingsStore.setEnabled($0) }
        )
    }

    private var eventStatusTitle: String {
        if mouseEventManager.lastErrorReason != nil {
            return "Blocked"
        }

        if mouseEventManager.lastEventDescription.localizedCaseInsensitiveContains("scroll") {
            return "Scroll"
        }

        if mouseEventManager.lastEventDescription.localizedCaseInsensitiveContains("button") {
            return "Button"
        }

        return "Input"
    }
}

struct StatusBadgeView: View {
    let title: String
    let systemImage: String
    let style: StatusBadgeStyle

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(style.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(style.color.opacity(0.12), in: Capsule())
    }
}

enum StatusBadgeStyle {
    case success
    case warning
    case info
    case neutral

    var color: Color {
        switch self {
        case .success: .green
        case .warning: .orange
        case .info: .blue
        case .neutral: .secondary
        }
    }
}

#Preview {
    let permissionsManager = PermissionsManager()
    HeaderView(
        settingsStore: SettingsStore(),
        permissionsManager: permissionsManager,
        mouseEventManager: MouseEventManager(settings: .defaultSettings, permissionsManager: permissionsManager)
    )
}
