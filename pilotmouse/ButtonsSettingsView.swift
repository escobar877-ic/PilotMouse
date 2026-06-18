import SwiftUI

struct ButtonsSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(MouseButtonDefinition.all) { button in
                        buttonRow(button)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
        .background(AppColors.windowBackground)
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Buttons")
                .font(.headline)
            Text("Assign global actions to extra mouse buttons. Left and right click stay protected. Button 4 and Button 5 are commonly used for Back and Forward.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
            .frame(width: 180, alignment: .leading)

            Spacer(minLength: 12)

            if button.isRemappable {
                Picker("Action", selection: actionBinding(for: button.buttonNumber)) {
                    ForEach(MouseAction.stableActions) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .labelsHidden()
                .frame(width: 260)
            } else {
                Text(MouseAction.defaultClick.displayName)
                    .foregroundStyle(.secondary)
                    .frame(width: 180, alignment: .leading)

                Text("Protected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8))
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
