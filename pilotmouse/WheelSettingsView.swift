import SwiftUI

struct WheelSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wheel")
                    .font(.headline)
                Text("Adjust global scroll direction and speed. Smooth scrolling is prepared as UI for a later pass.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Picker("Scroll direction", selection: scrollDirectionBinding) {
                ForEach(ScrollDirection.allCases) { direction in
                    Text(direction.displayName).tag(direction)
                }
            }
            .pickerStyle(.segmented)

            sliderRow(
                title: "Vertical scroll speed",
                value: verticalSpeedBinding,
                range: 0.25...5.0,
                valueText: settingsStore.settings.verticalScrollSpeed.multiplierText
            )

            sliderRow(
                title: "Horizontal scroll speed",
                value: horizontalSpeedBinding,
                range: 0.25...5.0,
                valueText: settingsStore.settings.horizontalScrollSpeed.multiplierText
            )

            Toggle("Smooth scrolling", isOn: smoothScrollingBinding)
            Text("Smooth scrolling is a placeholder until device-specific behavior can be tuned safely.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Middle click behavior", selection: middleClickBinding) {
                ForEach(MiddleClickBehavior.allCases) { behavior in
                    Text(behavior.displayName).tag(behavior)
                }
            }

            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
    }

    private var scrollDirectionBinding: Binding<ScrollDirection> {
        Binding(
            get: { settingsStore.settings.scrollDirection },
            set: { newValue in settingsStore.update { $0.scrollDirection = newValue } }
        )
    }

    private var verticalSpeedBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.verticalScrollSpeed },
            set: { newValue in settingsStore.update { $0.verticalScrollSpeed = newValue } }
        )
    }

    private var horizontalSpeedBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.horizontalScrollSpeed },
            set: { newValue in settingsStore.update { $0.horizontalScrollSpeed = newValue } }
        )
    }

    private var smoothScrollingBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.smoothScrollingEnabled },
            set: { newValue in settingsStore.update { $0.smoothScrollingEnabled = newValue } }
        )
    }

    private var middleClickBinding: Binding<MiddleClickBehavior> {
        Binding(
            get: { settingsStore.settings.middleClickBehavior },
            set: { newValue in settingsStore.update { $0.middleClickBehavior = newValue } }
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
    var multiplierText: String {
        String(format: "%.2fx", self)
    }
}

#Preview {
    WheelSettingsView(settingsStore: SettingsStore())
}
