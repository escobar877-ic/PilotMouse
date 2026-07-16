import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ButtonsSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var mouseEventManager: MouseEventManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        chordSection

                        Divider()
                            .padding(.vertical, 4)

                        buttonWheelChordSection

                        Divider()
                            .padding(.vertical, 4)

                        Text("Individual Buttons")
                            .font(.subheadline.weight(.semibold))

                        ForEach(MouseButtonDefinition.all) { button in
                            buttonCard(button)
                                .id(button.id)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                }
                .onChange(of: mouseEventManager.lastDetectedButtonNumber) { _, buttonNumber in
                    guard let buttonNumber else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(buttonNumber, anchor: .center)
                    }
                }
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
        .background(AppColors.windowBackground)
    }

    private var sectionHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Buttons")
                    .font(.headline)
                Text("Assign actions to mouse buttons, chords, and button-plus-wheel gestures.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if let buttonNumber = mouseEventManager.lastDetectedButtonNumber {
                VStack(alignment: .trailing, spacing: 2) {
                    Label(buttonName(for: buttonNumber), systemImage: "dot.circle.and.hand.point.up.left.fill")
                        .font(.callout.weight(.medium))
                    Text(mouseEventManager.lastDetectedModifierFlags.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func buttonName(for number: Int) -> String {
        MouseButtonDefinition.all.first(where: { $0.buttonNumber == number })?.name
            ?? "Button \(number + 1)"
    }

    private var chordSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Button Chords")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    settingsStore.addButtonChord()
                } label: {
                    Label("Add Chord", systemImage: "plus")
                }
            }

            if settingsStore.settings.buttonChords.isEmpty {
                Text("No button chords")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(settingsStore.settings.buttonChords) { chord in
                    ButtonChordEditorView(
                        chord: chord,
                        onChange: settingsStore.updateButtonChord,
                        onDelete: { settingsStore.removeButtonChord(id: chord.id) }
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var buttonWheelChordSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Button + Wheel Chords")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    settingsStore.addButtonWheelChord()
                } label: {
                    Label("Add Chord", systemImage: "plus")
                }
            }

            if settingsStore.settings.buttonWheelChords.isEmpty {
                Text("No button and wheel chords")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(settingsStore.settings.buttonWheelChords) { chord in
                    ButtonWheelChordEditorView(
                        chord: chord,
                        onChange: settingsStore.updateButtonWheelChord,
                        onDelete: { settingsStore.removeButtonWheelChord(id: chord.id) }
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buttonCard(_ button: MouseButtonDefinition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(button.name)
                        .font(.body.weight(.medium))
                    Text("Button number \(button.buttonNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

            }

            mappingEditor(button: button, modifierFlags: [])

            DisclosureGroup("Modifier mappings") {
                VStack(spacing: 8) {
                    ForEach(MouseModifierFlags.visiblePresets.dropFirst(), id: \.rawValue) { modifierFlags in
                        mappingEditor(button: button, modifierFlags: modifierFlags)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private func mappingEditor(button: MouseButtonDefinition, modifierFlags: MouseModifierFlags) -> some View {
        let mapping = settingsStore.mapping(for: button.buttonNumber, modifierFlags: modifierFlags)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(modifierFlags.isEmpty ? "Base action" : modifierFlags.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 150, alignment: .leading)

                Picker("Action", selection: actionBinding(for: button.buttonNumber, modifierFlags: modifierFlags)) {
                    ForEach(MouseAction.stableActions) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 320)

                Spacer(minLength: 8)
            }

            payloadEditor(mapping: mapping)
                .padding(.leading, 162)
        }
    }

    @ViewBuilder
    private func payloadEditor(mapping: ButtonMapping) -> some View {
        if mapping.action.needsCustomShortcut {
            VStack(alignment: .leading, spacing: 7) {
                ShortcutRecorderView(shortcut: mapping.customShortcut) { shortcut in
                    var updated = settingsStore.mapping(for: mapping.buttonNumber, modifierFlags: mapping.modifierFlags)
                    updated.action = mapping.action
                    updated.customShortcut = shortcut
                    settingsStore.setButtonMapping(updated)
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
                    var updated = settingsStore.mapping(for: mapping.buttonNumber, modifierFlags: mapping.modifierFlags)
                    updated.action = .shortcutSequence
                    updated.shortcutSequence = steps
                    settingsStore.setButtonMapping(updated)
                }
            }
        } else if mapping.action.needsTargetMouseButton {
            TargetMouseButtonPicker(
                buttonNumber: mapping.targetMouseButtonNumber ?? 3
            ) { buttonNumber in
                var updated = settingsStore.mapping(
                    for: mapping.buttonNumber,
                    modifierFlags: mapping.modifierFlags
                )
                updated.targetMouseButtonNumber = buttonNumber
                settingsStore.setButtonMapping(updated)
            }
        } else if mapping.action.needsOpenTarget {
            OpenTargetsEditorView(
                action: mapping.action,
                targets: mapping.openTargets
            ) { targets in
                var updated = settingsStore.mapping(
                    for: mapping.buttonNumber,
                    modifierFlags: mapping.modifierFlags
                )
                updated.openTargets = targets
                updated.openTarget = targets.first
                settingsStore.setButtonMapping(updated)
            }
        }
    }

    private func actionBinding(for buttonNumber: Int, modifierFlags: MouseModifierFlags) -> Binding<MouseAction> {
        Binding(
            get: {
                settingsStore.mapping(for: buttonNumber, modifierFlags: modifierFlags).action
            },
            set: { action in
                var mapping = settingsStore.mapping(for: buttonNumber, modifierFlags: modifierFlags)
                mapping.action = action

                if !action.needsCustomShortcut {
                    mapping.customShortcut = nil
                }

                if action.needsShortcutSequence {
                    if mapping.shortcutSequence == nil {
                        mapping.shortcutSequence = [ShortcutSequenceStep()]
                    }
                } else {
                    mapping.shortcutSequence = nil
                }

                if !action.supportsShortcutRepeat {
                    mapping.shortcutRepeatEnabled = false
                }

                if !action.needsTargetMouseButton {
                    mapping.targetMouseButtonNumber = nil
                } else if mapping.targetMouseButtonNumber == nil {
                    mapping.targetMouseButtonNumber = 3
                }

                if !action.needsOpenTarget {
                    mapping.openTarget = nil
                    mapping.openTargets = []
                }

                settingsStore.setButtonMapping(mapping)
            }
        )
    }

    private func shortcutRepeatBinding(for mapping: ButtonMapping) -> Binding<Bool> {
        Binding(
            get: {
                settingsStore.mapping(
                    for: mapping.buttonNumber,
                    modifierFlags: mapping.modifierFlags
                ).shortcutRepeatEnabled
            },
            set: { isEnabled in
                var updated = settingsStore.mapping(
                    for: mapping.buttonNumber,
                    modifierFlags: mapping.modifierFlags
                )
                updated.shortcutRepeatEnabled = isEnabled
                settingsStore.setButtonMapping(updated)
            }
        )
    }

}

struct OpenTargetsEditorView: View {
    let action: MouseAction
    let targets: [String]
    let onChange: ([String]) -> Void

    @State private var pendingURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if action == .openURL {
                HStack(spacing: 7) {
                    TextField("https://example.com", text: $pendingURL)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addPendingURLs)

                    Button(action: addPendingURLs) {
                        Image(systemName: "plus")
                    }
                    .help("Add URL")
                    .disabled(pendingURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Button(action: chooseTargets) {
                    Label(
                        action == .openApplication ? "Add Applications" : "Add Files",
                        systemImage: "plus"
                    )
                }
            }

            ForEach(Array(targets.prefix(32).enumerated()), id: \.offset) { index, target in
                HStack(spacing: 7) {
                    Image(systemName: targetIcon)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Text(displayName(for: target))
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(target)

                    Spacer(minLength: 4)

                    Button(role: .destructive) {
                        var updated = targets
                        guard updated.indices.contains(index) else { return }
                        updated.remove(at: index)
                        onChange(updated)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove target")
                }
            }
        }
        .frame(maxWidth: 430, alignment: .leading)
    }

    private var targetIcon: String {
        switch action {
        case .openApplication: "app"
        case .openURL: "link"
        default: "doc"
        }
    }

    private func displayName(for target: String) -> String {
        guard action != .openURL else { return target }
        let name = URL(fileURLWithPath: target).lastPathComponent
        return name.isEmpty ? target : name
    }

    private func addPendingURLs() {
        let additions = pendingURL
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !additions.isEmpty else { return }
        onChange(mergedTargets(additions))
        pendingURL = ""
    }

    private func chooseTargets() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = action == .openApplication
        panel.canChooseFiles = true
        if action == .openApplication {
            panel.allowedContentTypes = [.applicationBundle]
        }

        guard panel.runModal() == .OK else { return }
        onChange(mergedTargets(panel.urls.map(\.path)))
    }

    private func mergedTargets(_ additions: [String]) -> [String] {
        var seen = Set<String>()
        return (targets + additions).filter {
            !$0.isEmpty && seen.insert($0).inserted
        }.prefix(32).map { $0 }
    }
}

struct TargetMouseButtonPicker: View {
    let buttonNumber: Int
    let onChange: (Int) -> Void

    var body: some View {
        Picker("Target button", selection: selectionBinding) {
            ForEach(3...31, id: \.self) { number in
                Text("Button \(number + 1)").tag(number)
            }
        }
        .frame(maxWidth: 220)
    }

    private var selectionBinding: Binding<Int> {
        Binding(
            get: { min(max(buttonNumber, 3), 31) },
            set: { onChange($0) }
        )
    }
}

#Preview {
    let permissionsManager = PermissionsManager()
    ButtonsSettingsView(
        settingsStore: SettingsStore(),
        mouseEventManager: MouseEventManager(settings: .defaultSettings, permissionsManager: permissionsManager)
    )
}
