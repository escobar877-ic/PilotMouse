import SwiftUI

struct WheelSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wheel")
                    .font(.headline)
                Text("Adjust scroll direction and speed for non-continuous mouse wheel events. Trackpad scrolling is passed through unchanged.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

            HStack {
                Text("Smooth scrolling")
                Spacer()
                Text("Native passthrough")
                    .foregroundStyle(.secondary)
            }
            Text("MousePilot does not modify continuous scrolling, so trackpads and smooth mouse wheels keep their native macOS behavior.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Middle click behavior", selection: middleClickBinding) {
                ForEach(MiddleClickBehavior.stableBehaviors) { behavior in
                    Text(behavior.displayName).tag(behavior)
                }
            }

            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
        .background(AppColors.windowBackground)
    }

    private var scrollDirectionBinding: Binding<ScrollDirection> {
        Binding(
            get: { settingsStore.settings.scrollDirection },
            set: { settingsStore.setScrollDirection($0) }
        )
    }

    private var verticalSpeedBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.verticalScrollSpeed },
            set: { settingsStore.setVerticalScrollSpeed($0) }
        )
    }

    private var horizontalSpeedBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.horizontalScrollSpeed },
            set: { settingsStore.setHorizontalScrollSpeed($0) }
        )
    }

    private var middleClickBinding: Binding<MiddleClickBehavior> {
        Binding(
            get: { settingsStore.settings.middleClickBehavior },
            set: { settingsStore.setMiddleClickBehavior($0) }
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
