import SwiftUI

struct ShortcutSequenceEditorView: View {
    let steps: [ShortcutSequenceStep]
    let onChange: ([ShortcutSequenceStep]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sequence")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    addStep()
                } label: {
                    Label("Add Step", systemImage: "plus")
                }
                .disabled(steps.count >= 32)
            }

            if steps.isEmpty {
                Text("No sequence steps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    stepEditor(step, at: index)

                    if step.id != steps.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func stepEditor(_ step: ShortcutSequenceStep, at index: Int) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text("\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Picker("Operation", selection: operationBinding(for: step.id)) {
                ForEach(ShortcutSequenceOperation.allCases) { operation in
                    Text(operation.displayName).tag(operation)
                }
            }
            .labelsHidden()
            .frame(width: 150)

            if step.operation.needsShortcut {
                ShortcutRecorderView(shortcut: step.shortcut) { shortcut in
                    updateStep(step.id) { $0.shortcut = shortcut }
                }
                .frame(maxWidth: 190, alignment: .leading)
            } else {
                Text(step.operation.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 190, alignment: .leading)
            }

            if index == 0 {
                Text("Start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 92)
            } else {
                Stepper(
                    value: delayBinding(for: step.id),
                    in: 0...5,
                    step: 0.05
                ) {
                    Text("\(step.delayBefore, specifier: "%.2f") s")
                        .monospacedDigit()
                }
                .font(.caption)
                .frame(width: 92)
                .help("Delay before this step")
            }

            Button {
                moveStep(from: index, offset: -1)
            } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.borderless)
            .disabled(index == 0)
            .help("Move step up")

            Button {
                moveStep(from: index, offset: 1)
            } label: {
                Image(systemName: "arrow.down")
            }
            .buttonStyle(.borderless)
            .disabled(index == steps.count - 1)
            .help("Move step down")

            Button(role: .destructive) {
                onChange(steps.filter { $0.id != step.id })
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove step")
        }
    }

    private func operationBinding(for stepID: UUID) -> Binding<ShortcutSequenceOperation> {
        Binding(
            get: { steps.first(where: { $0.id == stepID })?.operation ?? .keyboardShortcut },
            set: { operation in
                updateStep(stepID) { step in
                    step.operation = operation
                    if !operation.needsShortcut {
                        step.shortcut = nil
                    }
                }
            }
        )
    }

    private func delayBinding(for stepID: UUID) -> Binding<Double> {
        Binding(
            get: { steps.first(where: { $0.id == stepID })?.delayBefore ?? 0 },
            set: { value in
                updateStep(stepID) { $0.delayBefore = min(max(value, 0), 5) }
            }
        )
    }

    private func addStep() {
        guard steps.count < 32 else {
            return
        }

        var updated = steps
        updated.append(
            ShortcutSequenceStep(delayBefore: updated.isEmpty ? 0 : 0.1)
        )
        onChange(updated)
    }

    private func updateStep(_ id: UUID, transform: (inout ShortcutSequenceStep) -> Void) {
        guard let index = steps.firstIndex(where: { $0.id == id }) else {
            return
        }

        var updated = steps
        transform(&updated[index])
        onChange(updated)
    }

    private func moveStep(from index: Int, offset: Int) {
        let destination = index + offset
        guard steps.indices.contains(index), steps.indices.contains(destination) else {
            return
        }

        var updated = steps
        updated.swapAt(index, destination)
        updated[0].delayBefore = 0
        onChange(updated)
    }
}
