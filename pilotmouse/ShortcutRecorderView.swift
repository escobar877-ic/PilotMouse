import AppKit
import SwiftUI

struct ShortcutRecorderView: View {
    let shortcut: KeyboardShortcutDefinition?
    let onChange: (KeyboardShortcutDefinition?) -> Void

    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            Button(shortcut?.displayText ?? "Record Shortcut") {
                isRecording = true
            }

            if shortcut != nil {
                Button("Clear") {
                    onChange(nil)
                }
            }
        }
        .sheet(isPresented: $isRecording) {
            ShortcutRecorderSheet(
                onCapture: { shortcut in
                    onChange(shortcut)
                    isRecording = false
                },
                onCancel: {
                    isRecording = false
                }
            )
        }
    }
}

private struct ShortcutRecorderSheet: View {
    let onCapture: (KeyboardShortcutDefinition) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "keyboard")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)

            Text("Press a shortcut")
                .font(.headline)

            Text("Press a key, optionally with Command, Shift, Option, or Control. Press Escape to cancel.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            ShortcutCaptureView(onCapture: onCapture, onCancel: onCancel)
                .frame(width: 1, height: 1)

            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(width: 360)
    }
}

private struct ShortcutCaptureView: NSViewRepresentable {
    let onCapture: (KeyboardShortcutDefinition) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onCancel = onCancel

        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class ShortcutCaptureNSView: NSView {
    var onCapture: ((KeyboardShortcutDefinition) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        guard let shortcut = KeyboardShortcutDefinition(event: event) else {
            return
        }

        onCapture?(shortcut)
    }
}

private extension KeyboardShortcutDefinition {
    init?(event: NSEvent) {
        let keyName = Self.keyName(for: event)
        guard !keyName.isEmpty else {
            return nil
        }

        let modifiers = MouseModifierFlags(eventModifierFlags: event.modifierFlags)
        let modifierText = modifiers.isEmpty ? "" : "\(modifiers.displayName) + "
        self.init(keyCode: event.keyCode, modifiers: modifiers, displayText: "\(modifierText)\(keyName)")
    }

    static func keyName(for event: NSEvent) -> String {
        switch event.keyCode {
        case 36: "Return"
        case 48: "Tab"
        case 49: "Space"
        case 51: "Delete"
        case 53: "Escape"
        case 64: "F17"
        case 71: "Clear"
        case 76: "Enter"
        case 79: "F18"
        case 80: "F19"
        case 90: "F20"
        case 96: "F5"
        case 97: "F6"
        case 98: "F7"
        case 99: "F3"
        case 100: "F8"
        case 101: "F9"
        case 103: "F11"
        case 105: "F13"
        case 106: "F16"
        case 107: "F14"
        case 109: "F10"
        case 111: "F12"
        case 113: "F15"
        case 115: "Home"
        case 116: "Page Up"
        case 117: "Forward Delete"
        case 118: "F4"
        case 119: "End"
        case 120: "F2"
        case 121: "Page Down"
        case 122: "F1"
        case 123: "Left Arrow"
        case 124: "Right Arrow"
        case 125: "Down Arrow"
        case 126: "Up Arrow"
        default:
            event.charactersIgnoringModifiers?.uppercased() ?? ""
        }
    }
}

private extension MouseModifierFlags {
    init(eventModifierFlags: NSEvent.ModifierFlags) {
        self = []

        if eventModifierFlags.contains(.command) {
            insert(.command)
        }

        if eventModifierFlags.contains(.shift) {
            insert(.shift)
        }

        if eventModifierFlags.contains(.option) {
            insert(.option)
        }

        if eventModifierFlags.contains(.control) {
            insert(.control)
        }
    }
}
