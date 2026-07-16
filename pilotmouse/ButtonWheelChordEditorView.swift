import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ButtonWheelChordEditorView: View {
    let chord: ButtonWheelChordMapping
    let onChange: (ButtonWheelChordMapping) -> Void
    let onDelete: () -> Void

    private static let selectableButtons = MouseButtonDefinition.all.filter(\.isRemappable)
    private static let selectableActions = MouseAction.stableActions.filter { $0 != .defaultClick }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 12) {
                labeledPicker("Button", width: 142) {
                    Picker("Button", selection: buttonBinding) {
                        ForEach(Self.selectableButtons) { button in
                            Text(button.name).tag(button.buttonNumber)
                        }
                    }
                }

                Image(systemName: "plus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 7)

                labeledPicker("Wheel", width: 138) {
                    Picker("Wheel direction", selection: wheelDirectionBinding) {
                        ForEach(WheelDirection.allCases) { direction in
                            Label(direction.displayName, systemImage: direction.systemImage)
                                .tag(direction)
                        }
                    }
                }

                labeledPicker("Modifiers", width: 250) {
                    Picker("Modifiers", selection: modifierBinding) {
                        ForEach(MouseModifierFlags.visiblePresets, id: \.rawValue) { modifierFlags in
                            Text(modifierFlags.displayName).tag(modifierFlags)
                        }
                    }
                }

                Spacer(minLength: 4)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove button and wheel chord")
                .padding(.bottom, 5)
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
                ShortcutSequenceEditorView(steps: chord.shortcutSequence ?? []) { steps in
                    var updated = chord
                    updated.action = .shortcutSequence
                    updated.shortcutSequence = steps
                    onChange(updated)
                }
                .padding(.leading, 66)
            }
        }
    }

    private func labeledPicker<Content: View>(
        _ title: String,
        width: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
                .labelsHidden()
                .frame(width: width)
        }
    }

    @ViewBuilder
    private var payloadEditor: some View {
        if chord.action.needsCustomShortcut {
            ShortcutRecorderView(shortcut: chord.customShortcut) { shortcut in
                var updated = chord
                updated.action = chord.action
                updated.customShortcut = shortcut
                onChange(updated)
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

    private var buttonBinding: Binding<Int> {
        Binding(
            get: { chord.buttonNumber },
            set: { buttonNumber in
                var updated = chord
                updated.buttonNumber = buttonNumber
                onChange(updated)
            }
        )
    }

    private var wheelDirectionBinding: Binding<WheelDirection> {
        Binding(
            get: { chord.wheelDirection },
            set: { wheelDirection in
                var updated = chord
                updated.wheelDirection = wheelDirection
                onChange(updated)
            }
        )
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

}
