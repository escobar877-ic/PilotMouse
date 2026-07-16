import AppKit
import ApplicationServices
import CoreGraphics
import IOKit

@MainActor
final class ShortcutRepeatScheduler {
    struct Timing: Equatable {
        let initialDelay: TimeInterval
        let interval: TimeInterval
    }

    typealias Operation = @MainActor () async -> Bool

    private var tasks = [UUID: Task<Void, Never>]()

    var activeSessionCount: Int {
        tasks.count
    }

    func start(
        timing: Timing,
        operation: @escaping Operation
    ) -> UUID {
        let sessionID = UUID()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { tasks[sessionID] = nil }

            guard await operation() else {
                return
            }
            guard await Self.wait(for: timing.initialDelay) else {
                return
            }

            while !Task.isCancelled {
                guard await operation() else {
                    return
                }
                guard await Self.wait(for: timing.interval) else {
                    return
                }
            }
        }
        tasks[sessionID] = task
        return sessionID
    }

    func stop(_ sessionID: UUID) {
        tasks.removeValue(forKey: sessionID)?.cancel()
    }

    func stopAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }

    private static func wait(for duration: TimeInterval) async -> Bool {
        guard duration > 0, duration.isFinite else {
            return !Task.isCancelled
        }

        do {
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

struct CursorSnapTarget: Equatable {
    let point: CGPoint
    let contextIdentifier: String
}

enum ActionExecutor {
    private static let leftBracketKey: CGKeyCode = 0x21
    private static let rightBracketKey: CGKeyCode = 0x1E
    private static let leftArrowKey: CGKeyCode = 0x7B
    private static let rightArrowKey: CGKeyCode = 0x7C
    private static let downArrowKey: CGKeyCode = 0x7D
    private static let upArrowKey: CGKeyCode = 0x7E
    private static let f11Key: CGKeyCode = 0x67
    private static let tabKey: CGKeyCode = 0x30
    private static let wKey: CGKeyCode = 0x0D
    private static let tKey: CGKeyCode = 0x11
    private static let cKey: CGKeyCode = 0x08
    private static let vKey: CGKeyCode = 0x09
    private static let dKey: CGKeyCode = 0x02
    private static let qKey: CGKeyCode = 0x0C
    private static let spaceKey: CGKeyCode = 0x31
    private static let graveKey: CGKeyCode = 0x32
    private static let nKey: CGKeyCode = 0x2D
    private static let equalKey: CGKeyCode = 0x18
    private static let minusKey: CGKeyCode = 0x1B

    private static var clickLockIsDown = false
    private static var shortcutSequenceTasks = [UUID: Task<Void, Never>]()
    private static let shortcutRepeatScheduler = ShortcutRepeatScheduler()
    private static var appSwitcherSessions = Set<UUID>()
    private static var syntheticAppSwitcherCommandHeld = false
    private static var cursorAnimationTask: Task<Void, Never>?

    @discardableResult
    static func execute(_ mapping: ButtonMapping) -> Bool {
        execute(mapping.action, mapping: mapping)
    }

    @discardableResult
    static func execute(_ action: MouseAction, mapping: ButtonMapping? = nil) -> Bool {
        switch action {
        case .disabled, .defaultClick:
            return true
        case .leftClick:
            return postMouseClick(button: .left, clickCount: 1)
        case .rightClick:
            return postMouseClick(button: .right, clickCount: 1)
        case .middleClick:
            return postMouseClick(button: .center, clickCount: 1)
        case .doubleClick:
            return postMouseClick(button: .left, clickCount: 2)
        case .tripleClick:
            return postMouseClick(button: .left, clickCount: 3)
        case .otherMouseClick:
            guard let buttonNumber = mapping?.targetMouseButtonNumber,
                  (3...31).contains(buttonNumber),
                  let targetButton = CGMouseButton(
                      rawValue: UInt32(buttonNumber)
                  ) else {
                return false
            }
            return postMouseClick(
                button: targetButton,
                clickCount: 1
            )
        case .clickLock:
            return toggleClickLock()
        case .keyLeftClick, .keyRightClick, .keyDoubleClick:
            guard let shortcut = mapping?.customShortcut else {
                return false
            }
            let button: CGMouseButton = action == .keyRightClick ? .right : .left
            let clickCount = action == .keyDoubleClick ? 2 : 1
            return postKeyModifiedClick(
                shortcut: shortcut,
                button: button,
                clickCount: clickCount
            )
        case .back:
            return sendKeyCombo(keyCode: leftBracketKey, flags: .maskCommand)
        case .forward:
            return sendKeyCombo(keyCode: rightBracketKey, flags: .maskCommand)
        case .missionControl:
            return openFirstAvailablePath([
                "/System/Applications/Mission Control.app"
            ]) || sendKeyCombo(keyCode: upArrowKey, flags: .maskControl)
        case .showDesktop:
            return sendFunctionKey(keyCode: f11Key)
        case .launchpad:
            return openFirstAvailablePath([
                "/System/Applications/Apps.app",
                "/System/Applications/Launchpad.app"
            ])
        case .moveSpaceLeft:
            return sendKeyCombo(keyCode: leftArrowKey, flags: .maskControl)
        case .moveSpaceRight:
            return sendKeyCombo(keyCode: rightArrowKey, flags: .maskControl)
        case .desktop1, .desktop2, .desktop3, .desktop4, .desktop5:
            return sendKeyCombo(keyCode: desktopKeyCode(for: action), flags: .maskControl)
        case .notificationCenter:
            return sendKeyCombo(keyCode: nKey, flags: .maskSecondaryFn)
        case .lookUp:
            return sendKeyCombo(keyCode: dKey, flags: [.maskCommand, .maskControl])
        case .spotlight:
            return sendKeyCombo(keyCode: spaceKey, flags: .maskCommand)
        case .siri:
            return openFirstAvailablePath([
                "/System/Applications/Siri.app",
                "/System/Applications/Siri AI.app",
                "/System/Library/CoreServices/Siri.app"
            ])
        case .quickNote:
            return sendKeyCombo(keyCode: qKey, flags: .maskSecondaryFn)
        case .lockScreen:
            return sendKeyCombo(keyCode: qKey, flags: [.maskCommand, .maskControl])
        case .appSwitcher:
            return sendKeyCombo(keyCode: tabKey, flags: .maskCommand)
        case .previousApplication:
            return sendKeyCombo(keyCode: tabKey, flags: [.maskCommand, .maskShift])
        case .applicationWindows:
            return sendKeyCombo(keyCode: downArrowKey, flags: .maskControl)
        case .nextWindow:
            return sendKeyCombo(keyCode: graveKey, flags: .maskCommand)
        case .previousWindow:
            return sendKeyCombo(keyCode: graveKey, flags: [.maskCommand, .maskShift])
        case .closeWindow:
            return closeFocusedWindow() || sendKeyCombo(keyCode: wKey, flags: .maskCommand)
        case .newTab:
            return sendKeyCombo(keyCode: tKey, flags: .maskCommand)
        case .closeTab:
            return sendKeyCombo(keyCode: wKey, flags: .maskCommand)
        case .copy:
            return sendKeyCombo(keyCode: cKey, flags: .maskCommand)
        case .paste:
            return sendKeyCombo(keyCode: vKey, flags: .maskCommand)
        case .zoomIn:
            return sendKeyCombo(keyCode: equalKey, flags: .maskCommand)
        case .zoomOut:
            return sendKeyCombo(keyCode: minusKey, flags: .maskCommand)
        case .scrollUp:
            return postScroll(vertical: 6, horizontal: 0)
        case .scrollDown:
            return postScroll(vertical: -6, horizontal: 0)
        case .scrollLeft:
            return postScroll(vertical: 0, horizontal: 6)
        case .scrollRight:
            return postScroll(vertical: 0, horizontal: -6)
        case .autoScroll:
            return false
        case .volumeUp:
            return postAuxKey(NX_KEYTYPE_SOUND_UP)
        case .volumeDown:
            return postAuxKey(NX_KEYTYPE_SOUND_DOWN)
        case .mute:
            return postAuxKey(NX_KEYTYPE_MUTE)
        case .playPause:
            return postAuxKey(NX_KEYTYPE_PLAY)
        case .nextTrack:
            return postAuxKey(NX_KEYTYPE_NEXT)
        case .previousTrack:
            return postAuxKey(NX_KEYTYPE_PREVIOUS)
        case .eject:
            return postAuxKey(NX_KEYTYPE_EJECT)
        case .snapToDefaultButton:
            return snapToWindowAttribute(kAXDefaultButtonAttribute as String)
        case .snapToCancelButton:
            return snapToWindowAttribute(kAXCancelButtonAttribute as String)
        case .snapToCloseButton:
            return snapToWindowAttribute(kAXCloseButtonAttribute as String)
        case .snapToMinimizeButton:
            return snapToWindowAttribute(kAXMinimizeButtonAttribute as String)
        case .snapToFullScreenButton:
            return snapToWindowAttribute(kAXFullScreenButtonAttribute as String)
        case .snapToDock:
            return snapToDock()
        case .snapToScreenCenter:
            return snapToScreenCenter()
        case .customShortcut:
            guard let shortcut = mapping?.customShortcut else {
                return false
            }

            return sendKeyCombo(keyCode: CGKeyCode(shortcut.keyCode), flags: shortcut.modifiers.cgEventFlags)
        case .shortcutSequence:
            return executeShortcutSequence(mapping?.shortcutSequence)
        case .openApplication, .openFile, .openURL:
            return openTargets(
                mapping?.openTargets ?? [],
                legacyTarget: mapping?.openTarget,
                action: action
            )
        }
    }

    @discardableResult
    static func sendKeyCombo(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        postKey(keyCode: keyCode, flags: flags)
    }

    @discardableResult
    static func sendFunctionKey(keyCode: CGKeyCode) -> Bool {
        postKey(keyCode: keyCode, flags: [])
    }

    static func startShortcutRepeat(_ mapping: ButtonMapping) -> UUID? {
        guard mapping.shortcutRepeatEnabled, mapping.action.supportsShortcutRepeat else {
            return nil
        }

        switch mapping.action {
        case .customShortcut:
            guard mapping.customShortcut != nil else { return nil }
        case .shortcutSequence:
            guard validatedShortcutSequence(mapping.shortcutSequence) != nil else { return nil }
        default:
            return nil
        }

        let timing = currentShortcutRepeatTiming()
        return shortcutRepeatScheduler.start(timing: timing) {
            await executeShortcutPayload(mapping)
        }
    }

    static func startAppSwitcherSession() -> UUID? {
        let currentFlags = CGEventSource.flagsState(.combinedSessionState)
        if appSwitcherSessions.isEmpty,
           !currentFlags.contains(.maskCommand) {
            guard postModifierKey(
                keyCode: 0x37,
                keyDown: true,
                flags: currentFlags.union(.maskCommand)
            ) else {
                return nil
            }
            syntheticAppSwitcherCommandHeld = true
        }

        let switcherFlags = currentFlags.union(.maskCommand)
        guard sendKeyCombo(keyCode: tabKey, flags: switcherFlags) else {
            if appSwitcherSessions.isEmpty {
                releaseSyntheticAppSwitcherCommandIfNeeded()
            }
            return nil
        }

        let sessionID = UUID()
        appSwitcherSessions.insert(sessionID)
        return sessionID
    }

    static func stopContinuousAction(_ sessionID: UUID) {
        shortcutRepeatScheduler.stop(sessionID)
        guard appSwitcherSessions.remove(sessionID) != nil,
              appSwitcherSessions.isEmpty else {
            return
        }
        releaseSyntheticAppSwitcherCommandIfNeeded()
    }

    static func releaseHeldInputs() {
        shortcutSequenceTasks.values.forEach { $0.cancel() }
        shortcutSequenceTasks.removeAll()
        shortcutRepeatScheduler.stopAll()
        appSwitcherSessions.removeAll()
        releaseSyntheticAppSwitcherCommandIfNeeded()
        cursorAnimationTask?.cancel()
        cursorAnimationTask = nil

        guard clickLockIsDown else {
            return
        }

        let location = currentMouseLocation()
        if let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: location,
            mouseButton: .left
        ) {
            MousePilotSyntheticEvent.mark(mouseUp)
            mouseUp.post(tap: .cghidEventTap)
        }
        clickLockIsDown = false
    }

    private static func postKey(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else {
            return false
        }

        keyDown.flags = flags
        keyUp.flags = flags
        MousePilotSyntheticEvent.mark(keyDown)
        MousePilotSyntheticEvent.mark(keyUp)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private static func postModifierKey(
        keyCode: CGKeyCode,
        keyDown: Bool,
        flags: CGEventFlags
    ) -> Bool {
        guard let event = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: keyDown
        ) else {
            return false
        }

        event.flags = flags
        MousePilotSyntheticEvent.mark(event)
        event.post(tap: .cghidEventTap)
        return true
    }

    private static func releaseSyntheticAppSwitcherCommandIfNeeded() {
        guard syntheticAppSwitcherCommandHeld else {
            return
        }

        var flags = CGEventSource.flagsState(.combinedSessionState)
        flags.remove(.maskCommand)
        _ = postModifierKey(keyCode: 0x37, keyDown: false, flags: flags)
        syntheticAppSwitcherCommandHeld = false
    }

    private static func desktopKeyCode(for action: MouseAction) -> CGKeyCode {
        switch action {
        case .desktop1: 0x12
        case .desktop2: 0x13
        case .desktop3: 0x14
        case .desktop4: 0x15
        case .desktop5: 0x17
        default: 0x12
        }
    }

    private static func executeShortcutSequence(_ sequence: [ShortcutSequenceStep]?) -> Bool {
        guard let sequence = validatedShortcutSequence(sequence) else {
            return false
        }

        let sequenceID = UUID()
        let task = Task { @MainActor in
            await Task.yield()
            defer { shortcutSequenceTasks[sequenceID] = nil }
            _ = await runShortcutSequence(sequence)
        }
        shortcutSequenceTasks[sequenceID] = task
        return true
    }

    private static func validatedShortcutSequence(
        _ sequence: [ShortcutSequenceStep]?
    ) -> [ShortcutSequenceStep]? {
        guard let sequence, !sequence.isEmpty, sequence.count <= 32,
              sequence.allSatisfy(\.isValid) else {
            return nil
        }

        return sequence
    }

    private static func runShortcutSequence(
        _ sequence: [ShortcutSequenceStep]
    ) async -> Bool {
        for step in sequence {
            let finiteDelay = step.delayBefore.isFinite ? step.delayBefore : 0
            let delay = min(max(finiteDelay, 0), 5)
            if delay > 0, !(await waitForDuration(delay)) {
                return false
            }

            guard !Task.isCancelled, executeShortcutSequenceStep(step) else {
                return false
            }
        }

        return true
    }

    private static func executeShortcutPayload(_ mapping: ButtonMapping) async -> Bool {
        switch mapping.action {
        case .customShortcut:
            guard let shortcut = mapping.customShortcut else {
                return false
            }
            return sendKeyCombo(
                keyCode: CGKeyCode(shortcut.keyCode),
                flags: shortcut.modifiers.cgEventFlags
            )
        case .shortcutSequence:
            guard let sequence = validatedShortcutSequence(mapping.shortcutSequence) else {
                return false
            }
            return await runShortcutSequence(sequence)
        default:
            return false
        }
    }

    private static func currentShortcutRepeatTiming() -> ShortcutRepeatScheduler.Timing {
        let defaults = UserDefaults.standard
        let initialUnits = (defaults.object(forKey: "InitialKeyRepeat") as? NSNumber)?.doubleValue ?? 25
        let intervalUnits = (defaults.object(forKey: "KeyRepeat") as? NSNumber)?.doubleValue ?? 6
        let secondsPerUnit = 1.0 / 60.0

        return ShortcutRepeatScheduler.Timing(
            initialDelay: min(max(initialUnits * secondsPerUnit, 0.1), 2.0),
            interval: min(max(intervalUnits * secondsPerUnit, 1.0 / 120.0), 1.0)
        )
    }

    private static func waitForDuration(_ duration: TimeInterval) async -> Bool {
        guard duration > 0, duration.isFinite else {
            return !Task.isCancelled
        }

        do {
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    private static func executeShortcutSequenceStep(_ step: ShortcutSequenceStep) -> Bool {
        switch step.operation {
        case .keyboardShortcut:
            guard let shortcut = step.shortcut else {
                return false
            }
            return sendKeyCombo(
                keyCode: CGKeyCode(shortcut.keyCode),
                flags: shortcut.modifiers.cgEventFlags
            )
        case .leftClick:
            return postMouseClick(button: .left, clickCount: 1)
        case .rightClick:
            return postMouseClick(button: .right, clickCount: 1)
        case .middleClick:
            return postMouseClick(button: .center, clickCount: 1)
        case .doubleClick:
            return postMouseClick(button: .left, clickCount: 2)
        }
    }

    private static func postMouseClick(
        button: CGMouseButton,
        clickCount: Int,
        flags: CGEventFlags = CGEventSource.flagsState(.combinedSessionState)
    ) -> Bool {
        let location = currentMouseLocation()
        let eventTypes: (down: CGEventType, up: CGEventType)
        switch button {
        case .left:
            eventTypes = (.leftMouseDown, .leftMouseUp)
        case .right:
            eventTypes = (.rightMouseDown, .rightMouseUp)
        default:
            eventTypes = (.otherMouseDown, .otherMouseUp)
        }

        for clickIndex in 1...max(1, clickCount) {
            guard
                let mouseDown = CGEvent(mouseEventSource: nil, mouseType: eventTypes.down, mouseCursorPosition: location, mouseButton: button),
                let mouseUp = CGEvent(mouseEventSource: nil, mouseType: eventTypes.up, mouseCursorPosition: location, mouseButton: button)
            else {
                return false
            }

            mouseDown.setIntegerValueField(.mouseEventClickState, value: Int64(clickIndex))
            mouseUp.setIntegerValueField(.mouseEventClickState, value: Int64(clickIndex))
            mouseDown.flags = flags
            mouseUp.flags = flags
            MousePilotSyntheticEvent.mark(mouseDown)
            MousePilotSyntheticEvent.mark(mouseUp)
            mouseDown.post(tap: .cghidEventTap)
            mouseUp.post(tap: .cghidEventTap)
        }

        return true
    }

    private static func postKeyModifiedClick(
        shortcut: KeyboardShortcutDefinition,
        button: CGMouseButton,
        clickCount: Int
    ) -> Bool {
        guard
            let keyDown = CGEvent(
                keyboardEventSource: nil,
                virtualKey: CGKeyCode(shortcut.keyCode),
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: nil,
                virtualKey: CGKeyCode(shortcut.keyCode),
                keyDown: false
            )
        else {
            return false
        }

        let flags = CGEventSource.flagsState(.combinedSessionState)
            .union(shortcut.modifiers.cgEventFlags)
        keyDown.flags = flags
        keyUp.flags = flags
        MousePilotSyntheticEvent.mark(keyDown)
        MousePilotSyntheticEvent.mark(keyUp)

        keyDown.post(tap: .cghidEventTap)
        let didClick = postMouseClick(
            button: button,
            clickCount: clickCount,
            flags: flags
        )
        keyUp.post(tap: .cghidEventTap)
        return didClick
    }

    private static func toggleClickLock() -> Bool {
        let location = currentMouseLocation()
        let eventType: CGEventType = clickLockIsDown ? .leftMouseUp : .leftMouseDown

        guard let event = CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: location, mouseButton: .left) else {
            return false
        }

        event.flags = CGEventSource.flagsState(.combinedSessionState)
        MousePilotSyntheticEvent.mark(event)
        event.post(tap: .cghidEventTap)
        clickLockIsDown.toggle()
        return true
    }

    private static func postScroll(vertical: Int32, horizontal: Int32) -> Bool {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 2,
            wheel1: vertical,
            wheel2: horizontal,
            wheel3: 0
        ) else {
            return false
        }

        event.flags = CGEventSource.flagsState(.combinedSessionState)
        MousePilotSyntheticEvent.mark(event)
        event.post(tap: .cghidEventTap)
        return true
    }

    private static func postAuxKey(_ keyType: Int32) -> Bool {
        let keyDownData = (Int(keyType) << 16) | (0xA << 8)
        let keyUpData = (Int(keyType) << 16) | (0xB << 8)

        guard
            let keyDown = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(keyType) << 16),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: keyDownData,
                data2: -1
            )?.cgEvent,
            let keyUp = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(keyType) << 16),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: keyUpData,
                data2: -1
            )?.cgEvent
        else {
            return false
        }

        MousePilotSyntheticEvent.mark(keyDown)
        MousePilotSyntheticEvent.mark(keyUp)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private static func openTargets(
        _ targets: [String],
        legacyTarget: String?,
        action: MouseAction
    ) -> Bool {
        let candidates = targets.isEmpty
            ? (legacyTarget.map { [$0] } ?? [])
            : Array(targets.prefix(32))
        var openedAnyTarget = false

        for target in candidates {
            openedAnyTarget = openTarget(target, action: action) || openedAnyTarget
        }

        return openedAnyTarget
    }

    private static func openTarget(_ rawTarget: String, action: MouseAction) -> Bool {
        let target = rawTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return false }

        if action == .openURL {
            return openURLString(target)
        }

        if let url = URL(string: target), url.scheme != nil, action != .openApplication {
            return NSWorkspace.shared.open(url)
        }

        return NSWorkspace.shared.open(URL(fileURLWithPath: NSString(string: target).expandingTildeInPath))
    }

    private static func openURLString(_ urlString: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized: String
        if let parsedURL = URL(string: trimmed), parsedURL.scheme != nil {
            normalized = trimmed
        } else {
            normalized = "https://\(trimmed)"
        }

        guard let url = URL(string: normalized) else {
            return false
        }

        return NSWorkspace.shared.open(url)
    }

    private static func openFirstAvailablePath(_ paths: [String]) -> Bool {
        for path in paths where FileManager.default.fileExists(atPath: path) {
            if NSWorkspace.shared.open(URL(fileURLWithPath: path)) {
                return true
            }
        }

        return false
    }

    private static func snapToWindowAttribute(_ attribute: String) -> Bool {
        guard let target = cursorSnapTarget(forAttribute: attribute) else {
            return false
        }

        return moveCursor(to: target.point, instantly: true)
    }

    static func cursorSnapTarget(
        for destination: CursorAutoSnapDestination
    ) -> CursorSnapTarget? {
        guard let attribute = destination.accessibilityAttribute else {
            return nil
        }

        return cursorSnapTarget(forAttribute: attribute)
    }

    private static func cursorSnapTarget(
        forAttribute attribute: String
    ) -> CursorSnapTarget? {
        guard
            AXIsProcessTrusted(),
            let processIdentifier = NSWorkspace.shared.frontmostApplication?.processIdentifier
        else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(processIdentifier)
        var focusedWindow: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(appElement, "AXFocusedWindow" as CFString, &focusedWindow) == .success,
            let focusedWindow,
            CFGetTypeID(focusedWindow) == AXUIElementGetTypeID()
        else {
            return nil
        }
        let focusedWindowElement = focusedWindow as! AXUIElement

        var targetElement: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(focusedWindowElement, attribute as CFString, &targetElement) == .success,
            let targetElement,
            CFGetTypeID(targetElement) == AXUIElementGetTypeID()
        else {
            return nil
        }
        let targetAXElement = targetElement as! AXUIElement

        guard let point = centerPoint(of: targetAXElement) else {
            return nil
        }

        return CursorSnapTarget(
            point: point,
            contextIdentifier: "\(processIdentifier):\(CFHash(focusedWindowElement)):\(CFHash(targetAXElement)):\(attribute)"
        )
    }

    private static func closeFocusedWindow() -> Bool {
        guard
            AXIsProcessTrusted(),
            let processIdentifier = NSWorkspace.shared.frontmostApplication?.processIdentifier
        else {
            return false
        }

        let appElement = AXUIElementCreateApplication(processIdentifier)
        var focusedWindow: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
            let focusedWindow,
            CFGetTypeID(focusedWindow) == AXUIElementGetTypeID()
        else {
            return false
        }
        let focusedWindowElement = focusedWindow as! AXUIElement

        var closeButton: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(focusedWindowElement, kAXCloseButtonAttribute as CFString, &closeButton) == .success,
            let closeButton,
            CFGetTypeID(closeButton) == AXUIElementGetTypeID()
        else {
            return false
        }
        let closeButtonElement = closeButton as! AXUIElement

        return AXUIElementPerformAction(closeButtonElement, kAXPressAction as CFString) == .success
    }

    private static func centerPoint(of element: AXUIElement) -> CGPoint? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        guard
            AXUIElementCopyAttributeValue(element, "AXPosition" as CFString, &positionRef) == .success,
            AXUIElementCopyAttributeValue(element, "AXSize" as CFString, &sizeRef) == .success,
            let positionValue = positionRef,
            let sizeValue = sizeRef,
            CFGetTypeID(positionValue) == AXValueGetTypeID(),
            CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        guard
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else {
            return nil
        }

        guard position.x.isFinite, position.y.isFinite,
              size.width.isFinite, size.height.isFinite,
              size.width >= 0, size.height >= 0 else {
            return nil
        }

        return CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
    }

    private static func snapToScreenCenter() -> Bool {
        let mouseLocation = currentMouseLocation()
        let displayIDs = NSScreen.screens.compactMap {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
                .map { CGDirectDisplayID($0.uint32Value) }
        }
        guard let displayID = displayIDs.first(where: {
            CGDisplayBounds($0).contains(mouseLocation)
        }) ?? displayIDs.first else {
            return false
        }

        let displayBounds = CGDisplayBounds(displayID)
        let destination = CGPoint(x: displayBounds.midX, y: displayBounds.midY)
        return moveCursor(to: destination, instantly: true)
    }

    private static func snapToDock() -> Bool {
        let mouseLocation = currentMouseLocation()
        let displayIDs = NSScreen.screens.compactMap {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
                .map { CGDirectDisplayID($0.uint32Value) }
        }
        guard let displayID = displayIDs.first(where: {
            CGDisplayBounds($0).contains(mouseLocation)
        }) ?? displayIDs.first else {
            return false
        }

        let bounds = CGDisplayBounds(displayID)
        let dockDefaults = UserDefaults.standard.persistentDomain(forName: "com.apple.dock")
        let orientation = dockDefaults?["orientation"] as? String ?? "bottom"
        let configuredTileSize = (dockDefaults?["tilesize"] as? NSNumber)?.doubleValue ?? 64
        let inset = min(max(configuredTileSize / 2, 16), 72)
        let destination: CGPoint

        switch orientation {
        case "left":
            destination = CGPoint(
                x: bounds.minX + inset,
                y: min(max(mouseLocation.y, bounds.minY + inset), bounds.maxY - inset)
            )
        case "right":
            destination = CGPoint(
                x: bounds.maxX - inset,
                y: min(max(mouseLocation.y, bounds.minY + inset), bounds.maxY - inset)
            )
        default:
            destination = CGPoint(
                x: min(max(mouseLocation.x, bounds.minX + inset), bounds.maxX - inset),
                y: bounds.maxY - inset
            )
        }

        return moveCursor(to: destination, instantly: true)
    }

    static func moveCursor(to point: CGPoint, instantly: Bool) -> Bool {
        guard point.x.isFinite, point.y.isFinite else {
            return false
        }

        cursorAnimationTask?.cancel()
        cursorAnimationTask = nil
        guard !instantly else {
            return warpCursor(to: point)
        }

        let origin = currentMouseLocation()
        cursorAnimationTask = Task { @MainActor in
            defer { cursorAnimationTask = nil }

            let stepCount = 12
            for step in 1...stepCount {
                guard !Task.isCancelled else { return }
                let progress = Double(step) / Double(stepCount)
                let eased = 1 - pow(1 - progress, 3)
                let intermediate = CGPoint(
                    x: origin.x + ((point.x - origin.x) * eased),
                    y: origin.y + ((point.y - origin.y) * eased)
                )
                guard warpCursor(to: intermediate) else { return }

                if step != stepCount {
                    do {
                        try await Task.sleep(nanoseconds: 12_000_000)
                    } catch {
                        return
                    }
                }
            }
        }
        return true
    }

    static func currentCursorLocation() -> CGPoint {
        currentMouseLocation()
    }

    private static func warpCursor(to point: CGPoint) -> Bool {
        guard CGWarpMouseCursorPosition(point) == .success else {
            return false
        }
        return CGAssociateMouseAndMouseCursorPosition(boolean_t(1)) == .success
    }

    private static func currentMouseLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? NSEvent.mouseLocation
    }
}

@MainActor
final class CursorAutoSnappingController {
    struct Dependencies {
        let targetProvider: @MainActor (CursorAutoSnapDestination) -> CursorSnapTarget?
        let cursorLocationProvider: @MainActor () -> CGPoint
        let cursorMover: @MainActor (CGPoint, Bool) -> Bool
        let accessibilityTrusted: @MainActor () -> Bool
        let shiftPressed: @MainActor () -> Bool
        let ownBundleIdentifier: @MainActor () -> String?
        let currentDate: @MainActor () -> Date

        static let live = Dependencies(
            targetProvider: { ActionExecutor.cursorSnapTarget(for: $0) },
            cursorLocationProvider: { ActionExecutor.currentCursorLocation() },
            cursorMover: { ActionExecutor.moveCursor(to: $0, instantly: $1) },
            accessibilityTrusted: { AXIsProcessTrusted() },
            shiftPressed: {
                CGEventSource.flagsState(.combinedSessionState).contains(.maskShift)
            },
            ownBundleIdentifier: { Bundle.main.bundleIdentifier },
            currentDate: { Date() }
        )
    }

    private let dependencies: Dependencies
    private var effectiveSettings = AppSettings.defaultSettings
    private var activeBundleIdentifier: String?
    private var activeDeviceIdentifier: String?
    private var pollTimer: Timer?
    private var snappedContextIdentifier: String?
    private var originalCursorLocation: CGPoint?
    private var missingTargetSince: Date?

    init() {
        dependencies = .live
    }

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    isolated deinit {
        pollTimer?.invalidate()
    }

    func start(settings: AppSettings, activeBundleIdentifier: String?) {
        updateSettings(
            settings,
            activeBundleIdentifier: activeBundleIdentifier,
            restorePreviousLocation: false
        )
        guard pollTimer == nil else { return }

        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollNow()
            }
        }
        pollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        pollNow()
    }

    func handleSettingsChanged(
        _ settings: AppSettings,
        activeBundleIdentifier: String?
    ) {
        updateSettings(
            settings,
            activeBundleIdentifier: activeBundleIdentifier,
            restorePreviousLocation: false
        )
        pollNow()
    }

    func handleFrontmostApplicationChanged(
        _ bundleIdentifier: String?,
        settings: AppSettings
    ) {
        finishCurrentSnap(restorePreviousLocation: true)
        updateSettings(
            settings,
            activeBundleIdentifier: bundleIdentifier,
            restorePreviousLocation: false
        )
        pollNow()
    }

    func handleActiveDeviceChanged(
        _ deviceIdentifier: String?,
        settings: AppSettings,
        activeBundleIdentifier: String?
    ) {
        guard deviceIdentifier != activeDeviceIdentifier else {
            return
        }

        finishCurrentSnap(restorePreviousLocation: true)
        activeDeviceIdentifier = deviceIdentifier
        updateSettings(
            settings,
            activeBundleIdentifier: activeBundleIdentifier,
            restorePreviousLocation: false
        )
        pollNow()
    }

    func stop(restorePreviousLocation: Bool = false) {
        pollTimer?.invalidate()
        pollTimer = nil
        finishCurrentSnap(restorePreviousLocation: restorePreviousLocation)
    }

    private func updateSettings(
        _ settings: AppSettings,
        activeBundleIdentifier: String?,
        restorePreviousLocation: Bool
    ) {
        let nextSettings = settings.effectiveSettings(
            for: activeBundleIdentifier,
            deviceIdentifier: activeDeviceIdentifier
        )
        let destinationChanged =
            nextSettings.cursorAutoSnapDestination
                != effectiveSettings.cursorAutoSnapDestination
        if destinationChanged || !nextSettings.isEnabled {
            finishCurrentSnap(
                restorePreviousLocation: restorePreviousLocation
            )
        }

        self.activeBundleIdentifier = activeBundleIdentifier
        effectiveSettings = nextSettings
    }

    func pollNow() {
        guard shouldPoll else {
            missingTargetSince = nil
            return
        }

        guard let target = dependencies.targetProvider(
            effectiveSettings.cursorAutoSnapDestination
        ) else {
            handleMissingTarget()
            return
        }

        missingTargetSince = nil
        guard target.contextIdentifier != snappedContextIdentifier else {
            return
        }

        // A different focused window replaces the previous target. Returning
        // first would create two competing cursor animations.
        finishCurrentSnap(restorePreviousLocation: false)
        let origin = dependencies.cursorLocationProvider()
        guard dependencies.cursorMover(
            target.point,
            effectiveSettings.cursorAutoSnapMovesInstantly
        ) else {
            return
        }

        originalCursorLocation = origin
        snappedContextIdentifier = target.contextIdentifier
    }

    private var shouldPoll: Bool {
            effectiveSettings.isEnabled
            && effectiveSettings.cursorAutoSnapDestination != .none
            && dependencies.accessibilityTrusted()
            && activeBundleIdentifier != dependencies.ownBundleIdentifier()
    }

    private func handleMissingTarget() {
        guard snappedContextIdentifier != nil else {
            missingTargetSince = nil
            return
        }

        let now = dependencies.currentDate()
        if let missingTargetSince,
           now.timeIntervalSince(missingTargetSince) >= 0.25 {
            finishCurrentSnap(restorePreviousLocation: true)
        } else if missingTargetSince == nil {
            self.missingTargetSince = now
        }
    }

    private func finishCurrentSnap(restorePreviousLocation: Bool) {
        defer {
            snappedContextIdentifier = nil
            originalCursorLocation = nil
            missingTargetSince = nil
        }

        guard restorePreviousLocation,
              effectiveSettings.cursorAutoSnapReturnsToOriginal,
              !dependencies.shiftPressed(),
              let originalCursorLocation else {
            return
        }

        _ = dependencies.cursorMover(
            originalCursorLocation,
            effectiveSettings.cursorAutoSnapMovesInstantly
        )
    }
}

private extension MouseModifierFlags {
    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []

        if contains(.command) {
            flags.insert(.maskCommand)
        }

        if contains(.shift) {
            flags.insert(.maskShift)
        }

        if contains(.option) {
            flags.insert(.maskAlternate)
        }

        if contains(.control) {
            flags.insert(.maskControl)
        }

        return flags
    }
}
