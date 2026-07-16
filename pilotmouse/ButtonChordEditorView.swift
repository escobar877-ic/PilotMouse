import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ButtonChordEditorView: View {
    let chord: ButtonChordMapping
    let onChange: (ButtonChordMapping) -> Void
    let onDelete: () -> Void

    private static let selectableButtons = MouseButtonDefinition.all.filter(\.isRemappable)
    private static let selectableActions = MouseAction.stableActions.filter { $0 != .defaultClick }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Buttons")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 7) {
                        buttonPicker(index: 0, title: "First button")

                        Image(systemName: "plus")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        buttonPicker(index: 1, title: "Second button")
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Modifiers")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Modifiers", selection: modifierBinding) {
                        ForEach(MouseModifierFlags.visiblePresets, id: \.rawValue) { modifierFlags in
                            Text(modifierFlags.displayName).tag(modifierFlags)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 280)
                }

                Spacer(minLength: 4)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove chord")
            }

            HStack(alignment: .top, spacing: 12) {
                Text("Action")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 54, alignment: .leading)
                    .padding(.top, 5)

                Picker("Action", selection: actionBinding) {
                    ForEach(Self.selectableActions) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .labelsHidden()
                .frame(width: 270)

                payloadEditor
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if chord.action.needsShortcutSequence {
                VStack(alignment: .leading, spacing: 7) {
                    Toggle("Key Repeat", isOn: shortcutRepeatBinding)
                        .toggleStyle(.switch)
                        .controlSize(.small)

                    ShortcutSequenceEditorView(steps: chord.shortcutSequence ?? []) { steps in
                        var updated = chord
                        updated.action = .shortcutSequence
                        updated.shortcutSequence = steps
                        onChange(updated)
                    }
                }
                .padding(.leading, 66)
            }
        }
    }

    private func buttonPicker(index: Int, title: String) -> some View {
        Picker(title, selection: buttonBinding(index: index)) {
            ForEach(Self.selectableButtons) { button in
                Text(button.name)
                    .tag(button.buttonNumber)
                    .disabled(button.buttonNumber == buttonNumber(at: index == 0 ? 1 : 0))
            }
        }
        .labelsHidden()
        .frame(width: 142)
    }

    @ViewBuilder
    private var payloadEditor: some View {
        if chord.action.needsCustomShortcut {
            VStack(alignment: .leading, spacing: 7) {
                ShortcutRecorderView(shortcut: chord.customShortcut) { shortcut in
                    var updated = chord
                    updated.action = chord.action
                    updated.customShortcut = shortcut
                    onChange(updated)
                }

                if chord.action.supportsShortcutRepeat {
                    Toggle("Key Repeat", isOn: shortcutRepeatBinding)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
        } else if chord.action.needsTargetMouseButton {
            TargetMouseButtonPicker(
                buttonNumber: chord.targetMouseButtonNumber ?? 3
            ) { buttonNumber in
                var updated = chord
                updated.targetMouseButtonNumber = buttonNumber
                onChange(updated)
            }
        } else if chord.action.needsOpenTarget {
            OpenTargetsEditorView(
                action: chord.action,
                targets: chord.openTargets
            ) { targets in
                var updated = chord
                updated.openTargets = targets
                updated.openTarget = targets.first
                onChange(updated)
            }
        }
    }

    private var modifierBinding: Binding<MouseModifierFlags> {
        Binding(
            get: { chord.modifierFlags },
            set: { modifierFlags in
                var updated = chord
                updated.modifierFlags = modifierFlags
                onChange(updated)
            }
        )
    }

    private var actionBinding: Binding<MouseAction> {
        Binding(
            get: { chord.action },
            set: { action in
                var updated = chord
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

                onChange(updated)
            }
        )
    }

    private var shortcutRepeatBinding: Binding<Bool> {
        Binding(
            get: { chord.shortcutRepeatEnabled },
            set: { isEnabled in
                var updated = chord
                updated.shortcutRepeatEnabled = isEnabled
                onChange(updated)
            }
        )
    }

    private func buttonBinding(index: Int) -> Binding<Int> {
        Binding(
            get: { buttonNumber(at: index) },
            set: { buttonNumber in
                var buttons = normalizedPair
                let otherIndex = index == 0 ? 1 : 0
                guard buttons[otherIndex] != buttonNumber else {
                    return
                }

                buttons[index] = buttonNumber
                var updated = chord
                updated.buttons = ButtonChordMapping.normalizedButtons(buttons)
                onChange(updated)
            }
        )
    }

    private var normalizedPair: [Int] {
        if chord.buttons.count == 2 {
            return chord.buttons
        }

        return [2, 3]
    }

    private func buttonNumber(at index: Int) -> Int {
        normalizedPair[index]
    }

}
