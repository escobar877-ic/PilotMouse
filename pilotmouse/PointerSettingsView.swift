import SwiftUI

struct PointerSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var pointerController: PointerController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pointer")
                        .font(.headline)
                    Text("Pointer control uses macOS mouse HID settings and does not modify trackpad movement.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Trackpad is not modified.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Enable pointer control")
                        .font(.body.weight(.medium))
                    Spacer()
                    Toggle("", isOn: pointerControlBinding)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                sliderRow
                    .disabled(!settingsStore.settings.pointerControlEnabled)

                HStack(spacing: 10) {
                    Button("Windows-like preset") {
                        let updatedSettings = settingsStore.applyWindowsLikePointerPreset()
                        pointerController.applyPointerSettings(updatedSettings)
                    }

                    Button("Restore original") {
                        pointerController.restoreOriginalMouseSettings()
                    }
                }

                compactStatus

                if let overrideWarning = pointerController.overrideWarning {
                    Label(overrideWarning, systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let lastError = pointerController.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                #if DEBUG
                DisclosureGroup("Advanced debug") {
                    VStack(alignment: .leading, spacing: 10) {
                        valueRow(title: "Sticky apply enabled", value: pointerController.isStickyApplyEnabled ? "true" : "false")
                        valueRow(title: "HID connection", value: pointerController.hasHIDSystemConnection ? "open" : "closed")
                        valueRow(title: "Original mouse value", value: pointerController.originalMouseAcceleration?.pointerText ?? "Unavailable")
                        valueRow(title: "Last system value", value: pointerController.lastSystemValue?.pointerText ?? "Unavailable")
                        valueRow(title: "Last reapply", value: pointerController.lastReapplyDate?.formatted(date: .omitted, time: .standard) ?? "Never")
                        valueRow(title: "Mode", value: settingsStore.settings.windowsLikeModeEnabled ? "Windows-like" : "Custom")

                        Text("If the value keeps reverting, quit other mouse utilities before testing MousePilot.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Button("Test 1.0") { pointerController.applyStickyMouseAcceleration(1.0) }
                            Button("Test 2.5") { pointerController.applyStickyMouseAcceleration(2.5) }
                            Button("Test 5.0") { pointerController.applyStickyMouseAcceleration(5.0) }
                        }
                    }
                    .padding(.top, 8)
                }
                #endif

                Text("Mouse tracking speed applies live with a short debounce while pointer control is enabled. Restore original stops sticky apply first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 12)
            .padding(.horizontal, 4)
        }
        .background(AppColors.windowBackground)
        .onAppear {
            _ = pointerController.readCurrentMouseAcceleration()
        }
    }

    private var sliderRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Mouse tracking speed")
                    .font(.body.weight(.medium))
                Spacer()
                Text("\(speedLabel) · \(Int(settingsStore.settings.mouseSpeedLevel.rounded()))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: mouseSpeedLevelBinding, in: 0...100, step: 1)
        }
    }

    private var compactStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            valueRow(title: "Speed level", value: "\(Int(settingsStore.settings.mouseSpeedLevel.rounded()))%")
            valueRow(title: "Speed label", value: speedLabel)
            valueRow(title: "Desired HID value", value: pointerController.desiredMouseAcceleration?.pointerText ?? MouseSpeedMapper.hidValue(from: settingsStore.settings.mouseSpeedLevel).pointerText)
            valueRow(title: "Current macOS mouse value", value: pointerController.currentMouseAcceleration?.pointerText ?? "Unavailable")
            valueRow(title: "Last applied value", value: pointerController.lastAppliedValue?.pointerText ?? "None")
            valueRow(title: "Reapply count", value: "\(pointerController.reapplyCount)")
        }
        .padding(12)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var speedLabel: String {
        MouseSpeedMapper.label(for: settingsStore.settings.mouseSpeedLevel)
    }

    private var pointerControlBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.pointerControlEnabled },
            set: { isEnabled in
                let updatedSettings = settingsStore.setPointerControlEnabled(isEnabled)
                pointerController.handlePointerControlEnabledChanged(isEnabled)

                if isEnabled {
                    pointerController.applyDesiredMouseAcceleration(MouseSpeedMapper.hidValue(from: updatedSettings.mouseSpeedLevel))
                }
            }
        )
    }

    private var mouseSpeedLevelBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.mouseSpeedLevel },
            set: { newValue in
                let updatedSettings = settingsStore.setMouseSpeedLevel(newValue)
                if updatedSettings.pointerControlEnabled {
                    pointerController.scheduleApplySpeedLevel(updatedSettings.mouseSpeedLevel)
                }
            }
        )
    }

    private func valueRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private extension Double {
    var pointerText: String {
        String(format: "%.2f", self)
    }
}

#Preview {
    PointerSettingsView(settingsStore: SettingsStore(), pointerController: PointerController())
}
