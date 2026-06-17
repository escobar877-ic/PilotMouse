import SwiftUI

struct PointerSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pointer")
                    .font(.headline)
                Text("Pointer controls are experimental and avoid changing system preferences directly.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            sliderRow(
                title: "Pointer speed",
                value: pointerSpeedBinding,
                range: 0.25...3.0,
                valueText: settingsStore.settings.pointerSpeed.pointerText
            )

            Toggle("Pointer acceleration", isOn: accelerationBinding)
            Text("Acceleration remains system-owned in this version; the toggle is stored for future behavior.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Precise mode", isOn: preciseModeBinding)

            sliderRow(
                title: "Precise mode speed",
                value: preciseModeSpeedBinding,
                range: 0.1...1.0,
                valueText: settingsStore.settings.preciseModeSpeed.pointerText
            )
            .disabled(!settingsStore.settings.preciseModeEnabled)

            Text("Experimental: mouseMoved delta edits can vary by device, so MousePilot keeps this conservative.")
                .font(.caption)
                .foregroundStyle(.orange)

            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
    }

    private var pointerSpeedBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.pointerSpeed },
            set: { newValue in settingsStore.update { $0.pointerSpeed = newValue } }
        )
    }

    private var accelerationBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.pointerAccelerationEnabled },
            set: { newValue in settingsStore.update { $0.pointerAccelerationEnabled = newValue } }
        )
    }

    private var preciseModeBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.preciseModeEnabled },
            set: { newValue in settingsStore.update { $0.preciseModeEnabled = newValue } }
        )
    }

    private var preciseModeSpeedBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.preciseModeSpeed },
            set: { newValue in settingsStore.update { $0.preciseModeSpeed = newValue } }
        )
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, valueText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(valueText)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: value, in: range)
        }
    }
}

private extension Double {
    var pointerText: String {
        String(format: "%.2fx", self)
    }
}

#Preview {
    PointerSettingsView(settingsStore: SettingsStore())
}
