import SwiftUI

struct ButtonsSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader

            VStack(spacing: 8) {
                ForEach(MouseButtonDefinition.all) { button in
                    buttonRow(button)
                }
            }

            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Buttons")
                .font(.headline)
            Text("Assign global actions to extra mouse buttons. Left and right click stay protected.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func buttonRow(_ button: MouseButtonDefinition) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(button.name)
                    .font(.body.weight(.medium))
                Text("Button number \(button.buttonNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 170, alignment: .leading)

            if button.isRemappable {
                Picker("Action", selection: actionBinding(for: button.buttonNumber)) {
                    ForEach(MouseAction.allCases) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)

                if !settingsStore.action(for: button.buttonNumber).isImplemented {
                    Text("TODO")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(MouseAction.defaultClick.displayName)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Protected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private func actionBinding(for buttonNumber: Int) -> Binding<MouseAction> {
        Binding(
            get: { settingsStore.action(for: buttonNumber) },
            set: { settingsStore.setButtonAction($0, for: buttonNumber) }
        )
    }
}

#Preview {
    ButtonsSettingsView(settingsStore: SettingsStore())
}
