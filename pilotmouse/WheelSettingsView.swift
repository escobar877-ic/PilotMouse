import SwiftUI

struct WheelSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var mouseEventManager: MouseEventManager
    @ObservedObject var scrollController: ScrollController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wheel")
                            .font(.headline)
                    }

                    Spacer()

                    if let isContinuous = mouseEventManager.lastScrollEventIsContinuous {
                        Label(
                            isContinuous ? "Continuous input" : "Step wheel input",
                            systemImage: isContinuous ? "waveform.path" : "circle.grid.3x3.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Picker("Scroll direction", selection: scrollDirectionBinding) {
                    ForEach(ScrollDirection.allCases) { direction in
                        Text(direction.displayName).tag(direction)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Wheel acceleration", isOn: accelerationEnabledBinding)

                accelerationRow

                sensitivityRow(
                    title: "Vertical sensitivity",
                    value: verticalSensitivityBinding
                )

                sensitivityRow(
                    title: "Horizontal sensitivity",
                    value: horizontalSensitivityBinding
                )

                Toggle("Adjust continuous / smooth wheel events", isOn: continuousScrollingBinding)

                Picker("Middle click behavior", selection: middleClickBinding) {
                    ForEach(MiddleClickBehavior.stableBehaviors) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }

                Divider()

                Text("Wheel Actions")
                    .font(.subheadline.weight(.semibold))

                WheelMappingsEditorView(
                    mappings: settingsStore.settings.wheelMappings,
                    onChange: settingsStore.setWheelMappings
                )

                if let lastError = scrollController.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }
            .padding(.top, 12)
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
        }
        .background(AppColors.windowBackground)
    }

    private var scrollDirectionBinding: Binding<ScrollDirection> {
        Binding(
            get: { settingsStore.settings.scrollDirection },
            set: { settingsStore.setScrollDirection($0) }
        )
    }

    private var accelerationEnabledBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.scrollAccelerationEnabled },
            set: { settingsStore.setScrollAccelerationEnabled($0) }
        )
    }

    private var accelerationBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.scrollAcceleration },
            set: { settingsStore.setScrollAcceleration($0) }
        )
    }

    private var accelerationSliderBinding: Binding<Double> {
        Binding(
            get: {
                ScrollAccelerationMapper.sliderPosition(
                    forValue: settingsStore.settings.scrollAcceleration
                )
            },
            set: {
                settingsStore.setScrollAcceleration(
                    ScrollAccelerationMapper.value(forSliderPosition: $0)
                )
            }
        )
    }

    private var verticalSensitivityBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.verticalScrollSensitivity },
            set: { settingsStore.setVerticalScrollSensitivity($0) }
        )
    }

    private var horizontalSensitivityBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.horizontalScrollSensitivity },
            set: { settingsStore.setHorizontalScrollSensitivity($0) }
        )
    }

    private var middleClickBinding: Binding<MiddleClickBehavior> {
        Binding(
            get: { settingsStore.settings.middleClickBehavior },
            set: { settingsStore.setMiddleClickBehavior($0) }
        )
    }

    private var continuousScrollingBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.smoothScrollingEnabled },
            set: { settingsStore.setSmoothScrollingEnabled($0) }
        )
    }

    private var accelerationRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Acceleration")
                Spacer()
                TextField("Acceleration", value: accelerationBinding, format: .number.precision(.fractionLength(0...4)))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)
                    .monospacedDigit()
            }

            Slider(
                value: accelerationSliderBinding,
                in: ScrollAccelerationMapper.sliderPositionRange
            )

            HStack {
                ForEach(ScrollAccelerationMapper.anchors.indices, id: \.self) { index in
                    Text(scrollAccelerationLabel(ScrollAccelerationMapper.anchors[index]))
                    if index != ScrollAccelerationMapper.anchors.indices.last {
                        Spacer()
                    }
                }
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .disabled(!settingsStore.settings.scrollAccelerationEnabled)
    }

    private func sensitivityRow(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                TextField("Sensitivity", text: sensitivityTextBinding(value))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
            }

            Slider(
                value: sensitivitySliderBinding(value),
                in: ScrollSensitivityMapper.sliderPositionRange
            )

            HStack {
                Text("-100")
                Spacer()
                Text("0")
                Spacer()
                Text("+1")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private func sensitivitySliderBinding(_ value: Binding<Double>) -> Binding<Double> {
        Binding(
            get: {
                ScrollSensitivityMapper.sliderPosition(
                    forFactor: value.wrappedValue
                )
            },
            set: {
                value.wrappedValue = ScrollSensitivityMapper.factor(
                    forSliderPosition: $0
                )
            }
        )
    }

    private func sensitivityTextBinding(_ value: Binding<Double>) -> Binding<String> {
        Binding(
            get: { signedValue(value.wrappedValue) },
            set: { text in
                guard let parsed = Double(text.replacingOccurrences(of: "+", with: "")) else {
                    return
                }
                guard parsed.isFinite else {
                    return
                }
                value.wrappedValue = min(max(parsed, -100), 1)
            }
        )
    }

    private func signedValue(_ value: Double) -> String {
        let normalized = abs(value) < 0.000_05 ? 0 : value
        return String(format: "%+.3g", normalized)
    }

    private func scrollAccelerationLabel(_ value: Double) -> String {
        value < 1 ? String(format: "%.1g", value) : String(format: "%.0f", value)
    }
}

struct WheelMappingsEditorView: View {
    let mappings: [WheelMapping]
    let onChange: ([WheelMapping]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(WheelDirection.allCases) { direction in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Label(direction.displayName, systemImage: direction.systemImage)
                            .font(.callout.weight(.medium))
                            .frame(width: 130, alignment: .leading)

                        WheelMappingRowView(
                            wheelDirection: direction,
                            modifierFlags: [],
                            mapping: exactMapping(for: direction, modifierFlags: []),
                            onChange: {
                                setMapping(
                                    $0,
                                    wheelDirection: direction,
                                    modifierFlags: []
                                )
                            }
                        )
                    }

                    DisclosureGroup("Modifier mappings") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(MouseModifierFlags.visiblePresets.dropFirst(), id: \.rawValue) { flags in
                                WheelMappingRowView(
                                    wheelDirection: direction,
                                    modifierFlags: flags,
                                    mapping: exactMapping(
                                        for: direction,
                                        modifierFlags: flags
                                    ),
                                    onChange: {
                                        setMapping(
                                            $0,
                                            wheelDirection: direction,
                                            modifierFlags: flags
                                        )
                                    }
                                )
                            }
                        }
                        .padding(.top, 7)
                    }
                    .font(.caption)
                }

                if direction != WheelDirection.allCases.last {
                    Divider()
                }
            }
        }
    }

    private func exactMapping(
        for wheelDirection: WheelDirection,
        modifierFlags: MouseModifierFlags
    ) -> WheelMapping? {
        mappings.first {
            $0.wheelDirection == wheelDirection
                && $0.modifierFlags == modifierFlags
        }
    }

    private func setMapping(
        _ mapping: WheelMapping?,
        wheelDirection: WheelDirection,
        modifierFlags: MouseModifierFlags
    ) {
        let mappingID = WheelMapping(
            wheelDirection: wheelDirection,
            modifierFlags: modifierFlags,
            action: .defaultClick
        ).id
        var updated = mappings.filter { $0.id != mappingID }
        if let mapping {
            updated.append(mapping)
        }
        onChange(updated)
    }
}

private enum WheelActionSelection: Hashable {
    case inheritBase
    case defaultScroll
    case action(MouseAction)
}

private struct WheelMappingRowView: View {
    let wheelDirection: WheelDirection
    let modifierFlags: MouseModifierFlags
    let mapping: WheelMapping?
    let onChange: (WheelMapping?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                if !modifierFlags.isEmpty {
                    Text(modifierFlags.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 150, alignment: .leading)
                }

                Picker("Action", selection: actionSelectionBinding) {
                    if !modifierFlags.isEmpty {
                        Text("Same as No Modifier Keys")
                            .tag(WheelActionSelection.inheritBase)
                    }
                    Text("Default Scroll")
                        .tag(WheelActionSelection.defaultScroll)
                    ForEach(MouseAction.wheelAssignableActions) { action in
                        Text(action.displayName)
                            .tag(WheelActionSelection.action(action))
                    }
                }
                .labelsHidden()
                .frame(width: 290)

                Spacer(minLength: 4)
            }

            if let mapping, mapping.action.needsCustomShortcut {
                VStack(alignment: .leading, spacing: 7) {
                    ShortcutRecorderView(shortcut: mapping.customShortcut) { shortcut in
                        var updated = mapping
                        updated.customShortcut = shortcut
                        onChange(updated)
                    }

                    Toggle(
                        "Enter keys only at the beginning of rolling",
                        isOn: beginningOnlyBinding(mapping)
                    )
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
                .padding(.leading, modifierFlags.isEmpty ? 0 : 160)
            } else if let mapping, mapping.action.needsShortcutSequence {
                VStack(alignment: .leading, spacing: 7) {
                    Toggle(
                        "Enter keys only at the beginning of rolling",
                        isOn: beginningOnlyBinding(mapping)
                    )
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    ShortcutSequenceEditorView(steps: mapping.shortcutSequence ?? []) { steps in
                        var updated = mapping
                        updated.shortcutSequence = steps
                        onChange(updated)
                    }
                }
                .padding(.leading, modifierFlags.isEmpty ? 0 : 160)
            }
        }
    }

    private var actionSelectionBinding: Binding<WheelActionSelection> {
        Binding(
            get: {
                guard let mapping else {
                    return modifierFlags.isEmpty ? .defaultScroll : .inheritBase
                }
                return mapping.action == .defaultClick
                    ? .defaultScroll
                    : .action(mapping.action)
            },
            set: { selection in
                switch selection {
                case .inheritBase:
                    onChange(nil)
                case .defaultScroll:
                    if modifierFlags.isEmpty {
                        onChange(nil)
                    } else {
                        onChange(
                            WheelMapping(
                                wheelDirection: wheelDirection,
                                modifierFlags: modifierFlags,
                                action: .defaultClick
                            )
                        )
                    }
                case let .action(action):
                    var updated = mapping ?? WheelMapping(
                        wheelDirection: wheelDirection,
                        modifierFlags: modifierFlags,
                        action: action
                    )
                    updated.action = action
                    if !action.needsCustomShortcut {
                        updated.customShortcut = nil
                    }
                    if action.needsShortcutSequence {
                        if updated.shortcutSequence == nil {
                            updated.shortcutSequence = [ShortcutSequenceStep()]
                        }
                    } else {
                        updated.shortcutSequence = nil
                    }
                    if !action.supportsShortcutRepeat {
                        updated.shortcutOnlyAtScrollStart = false
                    }
                    onChange(updated)
                }
            }
        )
    }

    private func beginningOnlyBinding(_ mapping: WheelMapping) -> Binding<Bool> {
        Binding(
            get: { mapping.shortcutOnlyAtScrollStart },
            set: { isEnabled in
                var updated = mapping
                updated.shortcutOnlyAtScrollStart = isEnabled
                onChange(updated)
            }
        )
    }
}

#Preview {
    let permissionsManager = PermissionsManager()
    WheelSettingsView(
        settingsStore: SettingsStore(),
        mouseEventManager: MouseEventManager(settings: .defaultSettings, permissionsManager: permissionsManager),
        scrollController: ScrollController()
    )
}
