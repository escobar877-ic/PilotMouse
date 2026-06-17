import CoreGraphics

enum ActionExecutor {
    private static let leftBracketKey: CGKeyCode = 0x21
    private static let rightBracketKey: CGKeyCode = 0x1E
    private static let upArrowKey: CGKeyCode = 0x7E
    private static let f11Key: CGKeyCode = 0x67
    private static let tabKey: CGKeyCode = 0x30
    private static let wKey: CGKeyCode = 0x0D
    private static let tKey: CGKeyCode = 0x11
    private static let cKey: CGKeyCode = 0x08
    private static let vKey: CGKeyCode = 0x09

    static func execute(_ action: MouseAction) {
        switch action {
        case .disabled, .defaultClick:
            break
        case .back:
            sendKeyCombo(keyCode: leftBracketKey, flags: .maskCommand)
        case .forward:
            sendKeyCombo(keyCode: rightBracketKey, flags: .maskCommand)
        case .missionControl:
            sendKeyCombo(keyCode: upArrowKey, flags: .maskControl)
        case .showDesktop:
            sendFunctionKey(keyCode: f11Key)
        case .appSwitcher:
            sendKeyCombo(keyCode: tabKey, flags: .maskCommand)
        case .closeWindow:
            sendKeyCombo(keyCode: wKey, flags: .maskCommand)
        case .newTab:
            sendKeyCombo(keyCode: tKey, flags: .maskCommand)
        case .closeTab:
            sendKeyCombo(keyCode: wKey, flags: .maskCommand)
        case .copy:
            sendKeyCombo(keyCode: cKey, flags: .maskCommand)
        case .paste:
            sendKeyCombo(keyCode: vKey, flags: .maskCommand)
        case .launchpad:
            // TODO: Add Launchpad support when a stable public trigger strategy is selected.
            break
        case .customShortcut:
            // TODO: Replay only an explicitly configured shortcut, never record keyboard history.
            break
        case .openApplication:
            // TODO: Launch a user-selected app URL stored in settings.
            break
        }
    }

    static func sendKeyCombo(keyCode: CGKeyCode, flags: CGEventFlags) {
        postKey(keyCode: keyCode, flags: flags)
    }

    static func sendFunctionKey(keyCode: CGKeyCode) {
        postKey(keyCode: keyCode, flags: [])
    }

    private static func postKey(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else {
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
