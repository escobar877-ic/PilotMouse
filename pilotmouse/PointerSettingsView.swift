import SwiftUI

struct PointerSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var pointerController: PointerController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cursor")
                        .font(.headline)
                    Text("Adjust mouse acceleration and hardware pointer sensitivity. Trackpad is not modified.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Enable cursor control")
                                .font(.body.weight(.medium))
                            Text("Applies acceleration and pointer resolution to connected mouse HID devices.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: cursorControlBinding)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Acceleration")
                                .font(.body.weight(.medium))
                            Text("Controls macOS tracking acceleration separately from sensitivity.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: accelerationEnabledBinding)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    accelerationRow
                    sensitivityRow
                }
                .padding(14)
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Auto Snapping")
                        .font(.body.weight(.medium))

                    Picker("Destination", selection: autoSnapDestinationBinding) {
                        ForEach(CursorAutoSnapDestination.allCases) { destination in
                            Text(destination.displayName).tag(destination)
                        }
                    }

                    Toggle(
                        "Return to the original location after the window is dismissed",
                        isOn: autoSnapReturnsBinding
                    )
                    .toggleStyle(.switch)
                    .disabled(settingsStore.settings.cursorAutoSnapDestination == .none)

                    Toggle(
                        "Move instantly to the destination",
                        isOn: autoSnapInstantBinding
                    )
                    .toggleStyle(.switch)
                    .disabled(settingsStore.settings.cursorAutoSnapDestination == .none)
                }
                .padding(14)
                .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 10) {
                    Button("Recommended") {
                        _ = settingsStore.applyRecommendedCursorPreset()
                    }

                    Button("Windows-like preset") {
                        _ = settingsStore.applyWindowsLikeCursorPreset()
                    }

                    Button("Restore System Defaults") {
                        _ = settingsStore.restoreSystemCursorDefaults()
                    }
                }

                compactStatus

                if let overrideWarning = pointerController.overrideWarning {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(overrideWarning, systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)

                        if !pointerController.conflictingUtilities.isEmpty {
                            Button {
                                settingsStore.openLoginItemsSettings()
                            } label: {
                                Label("Open Login Items", systemImage: "gear")
                            }
                        }
                    }
                }

                if let lastError = pointerController.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                advancedDebug

                Text("Cursor changes apply live with a short debounce while cursor control is enabled. MousePilot uses only the mouse HID setting and does not modify trackpad movement.")
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
            pointerController.refreshConflictingUtilities()
        }
    }

    private var accelerationRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Acceleration level")
                    .font(.body.weight(.medium))
                Spacer()
                Text("\(Int(settingsStore.settings.accelerationLevel.rounded())) / 99")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: accelerationLevelBinding, in: 0...99, step: 1)
                .disabled(!settingsStore.settings.accelerationEnabled)

            tickLabels(["0", "0.1", "0.5", "1.0", "2.0", "3.0", "5.0"])
        }
    }

    private var sensitivityRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sensitivity")
                    .font(.body.weight(.medium))
                Spacer()
                Text("\(Int(settingsStore.settings.sensitivityLevel.rounded()))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: sensitivityLevelBinding, in: 5...1990, step: 5)

            tickLabels(["5", "500", "1000", "1500", "1990"])
        }
    }

    private var compactStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            valueRow(title: "Cursor control", value: settingsStore.settings.cursorControlEnabled ? "Enabled" : "Disabled")
            valueRow(title: "Acceleration", value: settingsStore.settings.accelerationEnabled ? "Enabled" : "Disabled")
            valueRow(title: "Sensitivity", value: "\(Int(settingsStore.settings.sensitivityLevel.rounded()))")
            valueRow(title: "Desired tracking value", value: desiredTrackingValue.pointerText)
            valueRow(title: "Desired sensitivity resolution", value: desiredPointerResolution.pointerText)
            valueRow(title: "Current tracking value", value: pointerController.currentMouseAcceleration?.pointerText ?? "Unavailable")
            valueRow(title: "Current pointer resolution", value: pointerController.currentPointerResolution?.pointerText ?? "Unavailable")
            valueRow(title: "Last applied tracking", value: pointerController.lastAppliedValue?.pointerText ?? "None")
            valueRow(title: "Last applied resolution", value: pointerController.lastAppliedPointerResolution?.pointerText ?? "None")
            valueRow(title: "Reapply count", value: "\(pointerController.reapplyCount)")
        }
        .padding(12)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var advancedDebug: some View {
        DisclosureGroup("Advanced debug") {
            VStack(alignment: .leading, spacing: 10) {
                valueRow(title: "Sticky apply enabled", value: pointerController.isStickyApplyEnabled ? "true" : "false")
                valueRow(title: "HID connection", value: pointerController.hasHIDSystemConnection ? "open" : "closed")
                valueRow(title: "Pointer devices", value: "\(pointerController.pointerDeviceCount)")
                valueRow(title: "Mouse", value: pointerController.pointerDeviceNames.joined(separator: ", ").nonEmpty ?? "Unavailable")
                valueRow(title: "Conflicting utilities", value: pointerController.conflictingUtilities.joined(separator: ", ").nonEmpty ?? "None")
                valueRow(title: "Original mouse value", value: pointerController.originalMouseAcceleration?.pointerText ?? "Unavailable")
                valueRow(title: "Original pointer resolution", value: pointerController.originalPointerResolution?.pointerText ?? "Unavailable")
                valueRow(title: "Last system value", value: pointerController.lastSystemValue?.pointerText ?? "Unavailable")
                valueRow(title: "Resolution applies", value: "\(pointerController.pointerResolutionApplyCount)")
                valueRow(title: "Last reapply", value: pointerController.lastReapplyDate?.formatted(date: .omitted, time: .standard) ?? "Never")
                valueRow(title: "Mode", value: settingsStore.settings.windowsLikeModeEnabled ? "Windows-like" : "Custom")

                Text("If values keep reverting, quit other mouse utilities before testing MousePilot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                #if DEBUG
                HStack(spacing: 8) {
                    Button("Test 1.0") { pointerController.applyStickyMouseAcceleration(1.0) }
                    Button("Test 2.5") { pointerController.applyStickyMouseAcceleration(2.5) }
                    Button("Test 5.0") { pointerController.applyStickyMouseAcceleration(5.0) }
                }
                #endif
            }
            .padding(.top, 8)
        }
    }

    private var desiredTrackingValue: Double {
        MouseCursorMapper.hidAccelerationValue(
            accelerationEnabled: settingsStore.settings.accelerationEnabled,
            accelerationLevel: settingsStore.settings.accelerationLevel
        )
    }

    private var desiredPointerResolution: Double {
        MouseCursorMapper.hidPointerResolutionValue(sensitivityLevel: settingsStore.settings.sensitivityLevel)
    }

    private var cursorControlBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.cursorControlEnabled },
            set: { isEnabled in
                _ = settingsStore.setCursorControlEnabled(isEnabled)
            }
        )
    }

    private var accelerationEnabledBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.accelerationEnabled },
            set: { isEnabled in
                _ = settingsStore.setAccelerationEnabled(isEnabled)
            }
        )
    }

    private var accelerationLevelBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.accelerationLevel },
            set: { newValue in
                _ = settingsStore.setAccelerationLevel(newValue)
            }
        )
    }

    private var sensitivityLevelBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.sensitivityLevel },
            set: { newValue in
                _ = settingsStore.setSensitivityLevel(newValue)
            }
        )
    }

    private var autoSnapDestinationBinding: Binding<CursorAutoSnapDestination> {
        Binding(
            get: { settingsStore.settings.cursorAutoSnapDestination },
            set: { settingsStore.setCursorAutoSnapDestination($0) }
        )
    }

    private var autoSnapReturnsBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.cursorAutoSnapReturnsToOriginal },
            set: { settingsStore.setCursorAutoSnapReturnsToOriginal($0) }
        )
    }

    private var autoSnapInstantBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.cursorAutoSnapMovesInstantly },
            set: { settingsStore.setCursorAutoSnapMovesInstantly($0) }
        )
    }

    private func tickLabels(_ labels: [String]) -> some View {
        HStack {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if label != labels.last {
                    Spacer()
                }
            }
        }
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

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

#Preview {
    PointerSettingsView(settingsStore: SettingsStore(), pointerController: PointerController())
}
