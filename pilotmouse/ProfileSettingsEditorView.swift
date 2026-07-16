import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ProfileSettingsEditorView<Profile: ConfigurableMouseProfile>: View {
    let profile: Profile
    let onChange: (Profile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            wheelSection
            Divider()
            cursorSection
            Divider()
            buttonSection
            Divider()
            chordSections
        }
    }

    private var wheelSection: some View {
        DisclosureGroup("Wheel") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Picker("Direction", selection: binding(\.scrollDirection)) {
                        ForEach(ScrollDirection.allCases) { direction in
                            Text(direction.displayName).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)

                    Toggle("Acceleration", isOn: binding(\.scrollAccelerationEnabled))
                        .toggleStyle(.switch)

                    Slider(
                        value: scrollAccelerationSliderBinding,
                        in: ScrollAccelerationMapper.sliderPositionRange
                    )
                        .frame(minWidth: 130, maxWidth: 220)
                        .disabled(!profile.scrollAccelerationEnabled)

                    TextField("Acceleration", value: binding(\.scrollAcceleration), format: .number.precision(.fractionLength(0...4)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                        .disabled(!profile.scrollAccelerationEnabled)
                        .help("Accepted range: 0 to 20")
                }

                sensitivityRow(
                    title: "Vertical sensitivity",
                    factor: \.verticalScrollSensitivity,
                    speed: \.verticalScrollSpeed
                )
                sensitivityRow(
                    title: "Horizontal sensitivity",
                    factor: \.horizontalScrollSensitivity,
                    speed: \.horizontalScrollSpeed
                )

                HStack(spacing: 16) {
                    Toggle("Continuous events", isOn: binding(\.smoothScrollingEnabled))
                        .toggleStyle(.switch)

                    Picker("Middle button", selection: binding(\.middleClickBehavior)) {
                        ForEach(MiddleClickBehavior.stableBehaviors) { behavior in
                            Text(behavior.displayName).tag(behavior)
                        }
                    }
                    .frame(width: 220)
                }

                Divider()

                Text("Wheel Actions")
                    .font(.caption.weight(.semibold))

                WheelMappingsEditorView(
                    mappings: profile.wheelMappings,
                    onChange: { wheelMappings in
                        update { $0.wheelMappings = wheelMappings }
                    }
                )
            }
            .padding(.top, 8)
        }
    }

    private var cursorSection: some View {
        DisclosureGroup("Cursor") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Custom cursor settings", isOn: binding(\.cursorControlEnabled))
                    .toggleStyle(.switch)

                HStack(spacing: 12) {
                    Toggle("Acceleration", isOn: binding(\.accelerationEnabled))
                        .toggleStyle(.switch)
                        .disabled(!profile.cursorControlEnabled)

                    Text("Level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: binding(\.accelerationLevel), in: 0...99, step: 1)
                        .frame(minWidth: 150, maxWidth: 260)
                        .disabled(!profile.cursorControlEnabled || !profile.accelerationEnabled)
                    TextField("Level", value: binding(\.accelerationLevel), format: .number.precision(.fractionLength(0)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 62)
                        .disabled(!profile.cursorControlEnabled || !profile.accelerationEnabled)
                }

                HStack(spacing: 12) {
                    Text("Sensitivity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 82, alignment: .leading)
                    Slider(value: binding(\.sensitivityLevel), in: 5...1990, step: 1)
                        .frame(minWidth: 180, maxWidth: 330)
                        .disabled(!profile.cursorControlEnabled)
                    TextField("Sensitivity", value: binding(\.sensitivityLevel), format: .number.precision(.fractionLength(0)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 76)
                        .disabled(!profile.cursorControlEnabled)
                }

                Divider()

                Picker(
                    "Auto snapping",
                    selection: binding(\.cursorAutoSnapDestination)
                ) {
                    ForEach(CursorAutoSnapDestination.allCases) { destination in
                        Text(destination.displayName).tag(destination)
                    }
                }

                Toggle(
                    "Return to the original location after the window is dismissed",
                    isOn: binding(\.cursorAutoSnapReturnsToOriginal)
                )
                .toggleStyle(.switch)
                .disabled(profile.cursorAutoSnapDestination == .none)

                Toggle(
                    "Move instantly to the destination",
                    isOn: binding(\.cursorAutoSnapMovesInstantly)
                )
                .toggleStyle(.switch)
                .disabled(profile.cursorAutoSnapDestination == .none)
            }
            .padding(.top, 8)
        }
    }

    private var buttonSection: some View {
        DisclosureGroup("Button mappings") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(MouseButtonDefinition.all.filter(\.isRemappable)) { button in
                    VStack(alignment: .leading, spacing: 7) {
                        mappingRow(button: button, modifierFlags: [])

                        DisclosureGroup("Modifier mappings") {
                            VStack(spacing: 7) {
                                ForEach(MouseModifierFlags.visiblePresets.dropFirst(), id: \.rawValue) { flags in
                                    mappingRow(button: button, modifierFlags: flags)
                                }
                            }
                            .padding(.top, 6)
                        }
                        .font(.caption)
                    }

                    if button.id != MouseButtonDefinition.all.filter(\.isRemappable).last?.id {
                        Divider()
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var chordSections: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup("Button chords") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("\(profile.buttonChords.count) configured")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            addButtonChord()
                        } label: {
                            Label("Add Chord", systemImage: "plus")
                        }
                    }

                    ForEach(profile.buttonChords) { chord in
                        ButtonChordEditorView(
                            chord: chord,
                            onChange: updateButtonChord,
                            onDelete: { removeButtonChord(chord.id) }
                        )
                        if chord.id != profile.buttonChords.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.top, 8)
            }

            DisclosureGroup("Button + wheel chords") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("\(profile.buttonWheelChords.count) configured")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            addButtonWheelChord()
                        } label: {
                            Label("Add Chord", systemImage: "plus")
                        }
                    }

                    ForEach(profile.buttonWheelChords) { chord in
                        ButtonWheelChordEditorView(
                            chord: chord,
                            onChange: updateButtonWheelChord,
                            onDelete: { removeButtonWheelChord(chord.id) }
                        )
                        if chord.id != profile.buttonWheelChords.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func sensitivityRow(
        title: String,
        factor: WritableKeyPath<Profile, Double>,
        speed: WritableKeyPath<Profile, Double>
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 132, alignment: .leading)
            Slider(
                value: sliderSensitivityBinding(factor: factor, speed: speed),
                in: ScrollSensitivityMapper.sliderPositionRange
            )
                .frame(minWidth: 190, maxWidth: 330)
            TextField(
                "Factor",
                value: sensitivityBinding(factor: factor, speed: speed),
                format: .number.precision(.fractionLength(0...4))
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 76)
        }
    }

    private func mappingRow(
        button: MouseButtonDefinition,
        modifierFlags: MouseModifierFlags
    ) -> some View {
        let mapping = mapping(for: button.buttonNumber, modifierFlags: modifierFlags)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(modifierFlags.isEmpty ? button.name : modifierFlags.displayName)
                    .font(modifierFlags.isEmpty ? .callout.weight(.medium) : .caption)
                    .foregroundStyle(modifierFlags.isEmpty ? .primary : .secondary)
                    .frame(width: 150, alignment: .leading)

                Picker("Action", selection: actionBinding(for: mapping)) {
                    ForEach(MouseAction.stableActions) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 320)

                Spacer(minLength: 4)
            }

            payloadEditor(mapping: mapping)
                .padding(.leading, 160)
        }
    }

    @ViewBuilder
    private func payloadEditor(mapping: ButtonMapping) -> some View {
        if mapping.action.needsCustomShortcut {
            VStack(alignment: .leading, spacing: 7) {
                ShortcutRecorderView(shortcut: mapping.customShortcut) { shortcut in
                    var updated = mapping
                    updated.customShortcut = shortcut
                    setMapping(updated)
                }

                if mapping.action.supportsShortcutRepeat {
                    Toggle("Key Repeat", isOn: shortcutRepeatBinding(for: mapping))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
        } else if mapping.action.needsShortcutSequence {
            VStack(alignment: .leading, spacing: 7) {
                Toggle("Key Repeat", isOn: shortcutRepeatBinding(for: mapping))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                ShortcutSequenceEditorView(steps: mapping.shortcutSequence ?? []) { steps in
                    var updated = mapping
                    updated.shortcutSequence = steps
                    setMapping(updated)
                }
            }
        } else if mapping.action.needsTargetMouseButton {
            TargetMouseButtonPicker(
                buttonNumber: mapping.targetMouseButtonNumber ?? 3
            ) { buttonNumber in
                var updated = mapping
                updated.targetMouseButtonNumber = buttonNumber
                setMapping(updated)
            }
        } else if mapping.action.needsOpenTarget {
            OpenTargetsEditorView(
                action: mapping.action,
                targets: mapping.openTargets
            ) { targets in
                var updated = mapping
                updated.openTargets = targets
                updated.openTarget = targets.first
                setMapping(updated)
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<Profile, Value>) -> Binding<Value> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { value in
                update { $0[keyPath: keyPath] = value }
            }
        )
    }

    private func sensitivityBinding(
        factor: WritableKeyPath<Profile, Double>,
        speed: WritableKeyPath<Profile, Double>
    ) -> Binding<Double> {
        Binding(
            get: { profile[keyPath: factor] },
            set: { value in
                update {
                    let value = min(max(value, -100), 1)
                    $0[keyPath: factor] = value
                    $0[keyPath: speed] = ScrollSensitivityMapper.multiplier(for: value)
                }
            }
        )
    }

    private var scrollAccelerationSliderBinding: Binding<Double> {
        Binding(
            get: {
                ScrollAccelerationMapper.sliderPosition(
                    forValue: profile.scrollAcceleration
                )
            },
            set: {
                binding(\.scrollAcceleration).wrappedValue =
                    ScrollAccelerationMapper.value(forSliderPosition: $0)
            }
        )
    }

    private func sliderSensitivityBinding(
        factor: WritableKeyPath<Profile, Double>,
        speed: WritableKeyPath<Profile, Double>
    ) -> Binding<Double> {
        Binding(
            get: {
                ScrollSensitivityMapper.sliderPosition(
                    forFactor: profile[keyPath: factor]
                )
            },
            set: {
                sensitivityBinding(factor: factor, speed: speed).wrappedValue =
                    ScrollSensitivityMapper.factor(forSliderPosition: $0)
            }
        )
    }

    private func actionBinding(for mapping: ButtonMapping) -> Binding<MouseAction> {
        Binding(
            get: { mapping.action },
            set: { action in
                var updated = mapping
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
                    updated.shortcutRepeatEnabled = false
                }
                if !action.needsTargetMouseButton {
                    updated.targetMouseButtonNumber = nil
                } else if updated.targetMouseButtonNumber == nil {
                    updated.targetMouseButtonNumber = 3
                }
                if !action.needsOpenTarget {
                    updated.openTarget = nil
                    updated.openTargets = []
                }
                setMapping(updated)
            }
        )
    }

    private func shortcutRepeatBinding(for mapping: ButtonMapping) -> Binding<Bool> {
        Binding(
            get: { mapping.shortcutRepeatEnabled },
            set: { isEnabled in
                var updated = mapping
                updated.shortcutRepeatEnabled = isEnabled
                setMapping(updated)
            }
        )
    }

    private func mapping(for buttonNumber: Int, modifierFlags: MouseModifierFlags) -> ButtonMapping {
        if let exact = profile.buttonMappings.first(where: {
            $0.buttonNumber == buttonNumber && $0.modifierFlags == modifierFlags
        }) {
            return exact
        }

        if !modifierFlags.isEmpty {
            var inherited = mapping(for: buttonNumber, modifierFlags: [])
            inherited.modifierFlags = modifierFlags
            return inherited
        }

        return ButtonMapping(
            buttonNumber: buttonNumber,
            modifierFlags: modifierFlags,
            action: .defaultClick
        )
    }

    private func setMapping(_ mapping: ButtonMapping) {
        update { profile in
            if let index = profile.buttonMappings.firstIndex(where: { $0.id == mapping.id }) {
                profile.buttonMappings[index] = mapping
            } else {
                profile.buttonMappings.append(mapping)
            }
        }
    }

    private func addButtonChord() {
        let buttons = MouseButtonDefinition.preferredChordButtonNumbers
        let signatures = Set(profile.buttonChords.map(\.signature))
        for flags in MouseModifierFlags.visiblePresets {
            for first in buttons.indices {
                for second in buttons.indices where second > first {
                    let chord = ButtonChordMapping(
                        buttons: [buttons[first], buttons[second]],
                        modifierFlags: flags,
                        action: .missionControl
                    )
                    if !signatures.contains(chord.signature) {
                        update { $0.buttonChords.append(chord) }
                        return
                    }
                }
            }
        }
    }

    private func updateButtonChord(_ chord: ButtonChordMapping) {
        guard chord.isValid,
              !profile.buttonChords.contains(where: { $0.id != chord.id && $0.signature == chord.signature }) else {
            return
        }
        update { profile in
            guard let index = profile.buttonChords.firstIndex(where: { $0.id == chord.id }) else { return }
            profile.buttonChords[index] = chord
        }
    }

    private func removeButtonChord(_ id: UUID) {
        update { $0.buttonChords.removeAll { $0.id == id } }
    }

    private func addButtonWheelChord() {
        let buttons = MouseButtonDefinition.preferredChordButtonNumbers
        let signatures = Set(profile.buttonWheelChords.map(\.signature))
        for flags in MouseModifierFlags.visiblePresets {
            for button in buttons {
                for direction in WheelDirection.allCases {
                    let chord = ButtonWheelChordMapping(
                        buttonNumber: button,
                        wheelDirection: direction,
                        modifierFlags: flags,
                        action: .missionControl
                    )
                    if !signatures.contains(chord.signature) {
                        update { $0.buttonWheelChords.append(chord) }
                        return
                    }
                }
            }
        }
    }

    private func updateButtonWheelChord(_ chord: ButtonWheelChordMapping) {
        guard chord.isValid,
              !profile.buttonWheelChords.contains(where: { $0.id != chord.id && $0.signature == chord.signature }) else {
            return
        }
        update { profile in
            guard let index = profile.buttonWheelChords.firstIndex(where: { $0.id == chord.id }) else { return }
            profile.buttonWheelChords[index] = chord
        }
    }

    private func removeButtonWheelChord(_ id: UUID) {
        update { $0.buttonWheelChords.removeAll { $0.id == id } }
    }

    private func update(_ transform: (inout Profile) -> Void) {
        var updated = profile
        transform(&updated)
        onChange(updated)
    }
}
