import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import Foundation

enum MousePilotSyntheticEvent {
    private static let marker: Int64 = 0x4D_50_49_4C_4F_54

    static func mark(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: marker)
    }

    static func isMarked(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == marker
    }
}

private nonisolated struct MouseEventTapInvocation: @unchecked Sendable {
    let proxy: CGEventTapProxy
    let type: CGEventType
    let event: CGEvent
}

private nonisolated struct MouseEventTapResult: @unchecked Sendable {
    let event: Unmanaged<CGEvent>?
}

@MainActor
final class MouseEventManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastEventDescription = "No mouse events seen"
    @Published private(set) var lastErrorReason: String?
    @Published private(set) var lastDetectedButtonNumber: Int?
    @Published private(set) var lastDetectedModifierFlags: MouseModifierFlags = []
    @Published private(set) var lastDetectedDeviceIdentifier: String?
    @Published private(set) var lastScrollEventIsContinuous: Bool?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let permissionsManager: PermissionsManager
    private let deviceMonitor: MouseDeviceMonitor?
    private let nativeScrollController: ScrollController?
    private let autoScrollController = AutoScrollController()
    private let settingsLock = NSLock()
    private let suppressedButtonsLock = NSLock()
    private let chordStateLock = NSLock()
    private let continuousActionStateLock = NSLock()
    private let scrollStateLock = NSLock()
    private var currentSettings: AppSettings
    private var suppressedButtons = Set<ButtonEventKey>()
    private var pendingButtonPresses = [ButtonEventKey: PendingButtonPress]()
    private var replayedButtons = Set<ButtonEventKey>()
    private var continuousActionOwners = [UUID: Set<ButtonEventKey>]()
    private var continuousActionSessionsByButton = [ButtonEventKey: Set<UUID>]()
    private var wheelRollTracker = WheelRollTracker()
    private var scrollRemainders = [ScrollRemainderKey: Double]()
    private var lastScrollConfigurations = [ScrollDeviceKey: ScrollConfiguration]()
    private var lastPublishedEventTime = Date.distantPast

    private static let chordPassthroughDelay: TimeInterval = 0.12

    private nonisolated struct ButtonEventKey: Hashable {
        let buttonNumber: Int
        let deviceIdentifier: String?
    }

    private final class PendingButtonPress {
        let buttonNumber: Int
        let deviceIdentifier: String?
        let modifierFlags: MouseModifierFlags
        let mapping: ButtonMapping
        let downEvent: CGEvent
        var passthroughTimer: Timer?
        var wasConsumedByWheelChord = false

        init(
            buttonNumber: Int,
            deviceIdentifier: String?,
            modifierFlags: MouseModifierFlags,
            mapping: ButtonMapping,
            downEvent: CGEvent
        ) {
            self.buttonNumber = buttonNumber
            self.deviceIdentifier = deviceIdentifier
            self.modifierFlags = modifierFlags
            self.mapping = mapping
            self.downEvent = downEvent
        }

        var key: ButtonEventKey {
            ButtonEventKey(buttonNumber: buttonNumber, deviceIdentifier: deviceIdentifier)
        }
    }

    private struct ScrollConfiguration: Equatable {
        let direction: ScrollDirection
        let verticalSensitivity: Double
        let horizontalSensitivity: Double
        let nativeSensitivity: Double
        let continuousEnabled: Bool
    }

    private struct ScrollDeviceKey: Hashable {
        let deviceIdentifier: String?
    }

    private struct ScrollRemainderKey: Hashable {
        let device: ScrollDeviceKey
        let field: UInt32
    }

    init(
        settings: AppSettings,
        permissionsManager: PermissionsManager,
        deviceMonitor: MouseDeviceMonitor? = nil,
        nativeScrollController: ScrollController? = nil
    ) {
        self.currentSettings = settings
        self.permissionsManager = permissionsManager
        self.deviceMonitor = deviceMonitor
        self.nativeScrollController = nativeScrollController
    }

    func updateSettings(_ settings: AppSettings) {
        let wasEnabled = getSettingsSnapshot().isEnabled
        updateSettingsSnapshot(settings)

        guard wasEnabled != settings.isEnabled else {
            return
        }

        if settings.isEnabled {
            start()
        } else {
            stop()
        }
    }

    func updateSettingsSnapshot(_ settings: AppSettings) {
        settingsLock.lock()
        let previousSettings = currentSettings
        currentSettings = settings
        settingsLock.unlock()

        let buttonConfigurationChanged =
            previousSettings.buttonMappings != settings.buttonMappings
            || previousSettings.buttonChords != settings.buttonChords
            || previousSettings.buttonWheelChords != settings.buttonWheelChords
            || previousSettings.wheelMappings != settings.wheelMappings
            || previousSettings.deviceProfiles != settings.deviceProfiles
            || previousSettings.applicationProfiles != settings.applicationProfiles
            || previousSettings.middleClickBehavior != settings.middleClickBehavior
        if buttonConfigurationChanged {
            clearChordState(replayPendingDowns: true)
            clearContinuousActionSessions()
            autoScrollController.stop()
            ActionExecutor.releaseHeldInputs()
        }
        clearScrollState()
    }

    func getSettingsSnapshot() -> AppSettings {
        settingsLock.lock()
        let copy = currentSettings
        settingsLock.unlock()
        return copy
    }

    func handleFrontmostApplicationChanged() {
        clearChordState(replayPendingDowns: true)
        clearContinuousActionSessions()
        autoScrollController.stop()
        ActionExecutor.releaseHeldInputs()
        clearScrollState()
    }

    func handleHardwareDevicesChanged() {
        // A removed device cannot provide the matching button-up event. Never
        // replay its pending down event during a hot-plug reset.
        clearChordState(replayPendingDowns: false)
        clearSuppressedButtons()
        clearContinuousActionSessions()
        autoScrollController.stop()
        ActionExecutor.releaseHeldInputs()
        clearScrollState()
    }

    func start() {
        guard eventTap == nil else {
            isRunning = true
            return
        }

        permissionsManager.refresh()
        let permissionStatus = permissionsManager.status
        guard permissionStatus.isReady else {
            isRunning = false
            lastErrorReason = eventTapFailureReason(permissionStatus: permissionStatus)
            lastEventDescription = lastErrorReason ?? "Unknown event tap error"
            return
        }
        if let deviceMonitor, !deviceMonitor.isMonitoring {
            isRunning = false
            lastErrorReason = "Direct HID mouse input unavailable"
            lastEventDescription = lastErrorReason ?? "Unknown HID input error"
            return
        }

        let eventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: mouseEventTapCallback,
            userInfo: opaqueSelf
        ) else {
            isRunning = false
            lastErrorReason = eventTapFailureReason(permissionStatus: permissionStatus)
            lastEventDescription = lastErrorReason ?? "Unknown event tap error"
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        lastErrorReason = nil
        lastEventDescription = "Event tap active"
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        clearChordState(replayPendingDowns: true)
        clearSuppressedButtons()
        clearContinuousActionSessions()
        autoScrollController.stop()
        ActionExecutor.releaseHeldInputs()
        runLoopSource = nil
        eventTap = nil
        isRunning = false
        lastEventDescription = "Event tap stopped"
    }

    func restart() {
        stop()
        if getSettingsSnapshot().isEnabled {
            start()
        }
    }

    private func eventTapFailureReason(permissionStatus: MousePilotPermissionStatus) -> String {
        if !permissionStatus.accessibilityTrusted {
            return "Accessibility permission missing"
        }

        if !permissionStatus.hidListenEventAccess {
            return "Input Monitoring permission missing"
        }

        if !permissionStatus.postEventAccess {
            return "Event-posting permission missing"
        }

        return "CGEvent.tapCreate returned nil"
    }

    fileprivate func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            clearChordState(replayPendingDowns: true)
            clearSuppressedButtons()
            clearContinuousActionSessions()
            autoScrollController.stop()
            ActionExecutor.releaseHeldInputs()
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            publishLastEvent("Event tap re-enabled")
            return Unmanaged.passUnretained(event)
        }

        if MousePilotSyntheticEvent.isMarked(event) {
            return Unmanaged.passUnretained(event)
        }

        let baseSettings = getSettingsSnapshot()
        guard baseSettings.isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        let bundleIdentifier = activeBundleIdentifier()

        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            let buttonNumber = mouseButtonNumber(for: type, event: event)
            let deviceIdentifier = deviceMonitor?.deviceIdentifier(
                for: type,
                event: event,
                buttonNumber: buttonNumber
            )
            if buttonNumber <= 1, deviceIdentifier == nil {
                autoScrollController.stop()
                return Unmanaged.passUnretained(event)
            }
            let settings = baseSettings.effectiveSettings(
                for: bundleIdentifier,
                deviceIdentifier: deviceIdentifier
            )
            return handleMouseButtonDown(
                event: event,
                buttonNumber: buttonNumber,
                settings: settings,
                deviceIdentifier: deviceIdentifier
            )
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            let buttonNumber = mouseButtonNumber(for: type, event: event)
            let deviceIdentifier = deviceMonitor?.deviceIdentifier(
                for: type,
                event: event,
                buttonNumber: buttonNumber
            )
            if buttonNumber <= 1,
               deviceIdentifier == nil,
               !shouldResolveUnattributedButtonUp(buttonNumber) {
                return Unmanaged.passUnretained(event)
            }
            return handleMouseButtonUp(
                event: event,
                buttonNumber: buttonNumber,
                deviceIdentifier: deviceIdentifier
            )
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            let buttonNumber = mouseButtonNumber(for: type, event: event)
            let deviceIdentifier = deviceMonitor?.deviceIdentifier(
                for: type,
                event: event,
                buttonNumber: buttonNumber
            )
            if buttonNumber <= 1, deviceIdentifier == nil {
                return Unmanaged.passUnretained(event)
            }
            return handleMouseButtonDragged(
                event: event,
                buttonNumber: buttonNumber,
                deviceIdentifier: deviceIdentifier
            )
        case .scrollWheel:
            let deviceIdentifier = deviceMonitor?.deviceIdentifier(for: type, event: event)
            let settings = baseSettings.effectiveSettings(
                for: bundleIdentifier,
                deviceIdentifier: deviceIdentifier
            )
            return handleScrollWheel(
                event: event,
                settings: settings,
                deviceIdentifier: deviceIdentifier
            )
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleMouseButtonDown(
        event: CGEvent,
        buttonNumber: Int,
        settings: AppSettings,
        deviceIdentifier: String?
    ) -> Unmanaged<CGEvent>? {
        publishLastEvent("Button \(buttonNumber) down")

        if autoScrollController.isActive {
            autoScrollController.stop()
            if buttonNumber <= 1 {
                publishLastEvent("Auto scroll stopped")
                return Unmanaged.passUnretained(event)
            }
            insertSuppressedButton(buttonNumber, deviceIdentifier: deviceIdentifier)
            publishLastEvent("Auto scroll stopped")
            return nil
        }

        let modifierFlags = mouseModifierFlags(from: event.flags)
        publishDetectedButton(
            buttonNumber,
            modifierFlags: modifierFlags,
            deviceIdentifier: deviceIdentifier
        )
        let mapping = settings.resolvedMapping(for: buttonNumber, modifierFlags: modifierFlags)

        let hasChordCandidate = settings.hasChordCandidate(
            containing: buttonNumber,
            modifierFlags: modifierFlags
        ) || settings.hasButtonWheelChordCandidate(
            containing: buttonNumber,
            modifierFlags: modifierFlags
        )
        if permissionsManager.status.canPostActions, hasChordCandidate {
            return deferButtonForChord(
                event: event,
                buttonNumber: buttonNumber,
                deviceIdentifier: deviceIdentifier,
                modifierFlags: modifierFlags,
                mapping: mapping,
                settings: settings
            )
        }

        return handleImmediateButtonDown(
            event: event,
            buttonNumber: buttonNumber,
            deviceIdentifier: deviceIdentifier,
            mapping: mapping,
            settings: settings
        )
    }

    private func handleImmediateButtonDown(
        event: CGEvent,
        buttonNumber: Int,
        deviceIdentifier: String?,
        mapping: ButtonMapping,
        settings: AppSettings
    ) -> Unmanaged<CGEvent>? {
        switch mapping.action {
        case .defaultClick:
            return Unmanaged.passUnretained(event)
        case .disabled:
            insertSuppressedButton(buttonNumber, deviceIdentifier: deviceIdentifier)
            return nil
        default:
            guard !mapping.action.requiresPostEventAccess || permissionsManager.status.canPostActions else {
                publishLastEvent("Button \(buttonNumber) needs event-posting permission")
                return Unmanaged.passUnretained(event)
            }

            let repeatOwner = ButtonEventKey(
                buttonNumber: buttonNumber,
                deviceIdentifier: deviceIdentifier
            )
            guard execute(
                mapping,
                settings: settings,
                repeatOwnerKeys: [repeatOwner]
            ) else {
                publishLastEvent("Button \(buttonNumber) action unavailable")
                return Unmanaged.passUnretained(event)
            }

            insertSuppressedButton(buttonNumber, deviceIdentifier: deviceIdentifier)
            return nil
        }
    }

    private func deferButtonForChord(
        event: CGEvent,
        buttonNumber: Int,
        deviceIdentifier: String?,
        modifierFlags: MouseModifierFlags,
        mapping: ButtonMapping,
        settings: AppSettings
    ) -> Unmanaged<CGEvent>? {
        guard let downEvent = event.copy() else {
            return Unmanaged.passUnretained(event)
        }

        let pending = PendingButtonPress(
            buttonNumber: buttonNumber,
            deviceIdentifier: deviceIdentifier,
            modifierFlags: modifierFlags,
            mapping: mapping,
            downEvent: downEvent
        )

        chordStateLock.lock()
        let key = pending.key
        let alreadyPending = pendingButtonPresses[key] != nil
        if !alreadyPending {
            pendingButtonPresses[key] = pending
        }
        let pendingButtons = Set(
            pendingButtonPresses.values
                .filter { $0.modifierFlags == modifierFlags }
                .filter { $0.deviceIdentifier == deviceIdentifier }
                .filter { !$0.wasConsumedByWheelChord }
                .map(\.buttonNumber)
        )
        chordStateLock.unlock()

        guard !alreadyPending else {
            return nil
        }

        if let chord = settings.resolvedChord(for: pendingButtons, modifierFlags: modifierFlags) {
            resolveChord(chord, deviceIdentifier: deviceIdentifier, settings: settings)
            return nil
        }

        let waitsForWheel = settings.hasButtonWheelChordCandidate(
            containing: buttonNumber,
            modifierFlags: modifierFlags
        )
        if !waitsForWheel {
            let timer = Timer(timeInterval: Self.chordPassthroughDelay, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.resolvePendingTimeout(key: key)
                }
            }
            pending.passthroughTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        return nil
    }

    private func resolveChord(
        _ chord: ButtonChordMapping,
        deviceIdentifier: String?,
        settings: AppSettings
    ) {
        chordStateLock.lock()
        let presses = chord.buttons.compactMap { buttonNumber -> PendingButtonPress? in
            let key = ButtonEventKey(buttonNumber: buttonNumber, deviceIdentifier: deviceIdentifier)
            let pending = pendingButtonPresses.removeValue(forKey: key)
            pending?.passthroughTimer?.invalidate()
            return pending
        }
        chordStateLock.unlock()

        guard presses.count == chord.buttons.count else {
            presses.forEach { _ = resolvePendingPress($0, hasCurrentUpEvent: false) }
            return
        }

        let mapping = chord.actionMapping
        let canPost = !mapping.action.requiresPostEventAccess || permissionsManager.status.canPostActions
        let executed = mapping.action != .defaultClick
            && canPost
            && execute(
                mapping,
                settings: settings,
                repeatOwnerKeys: Set(presses.map(\.key))
            )

        guard executed else {
            if !canPost {
                publishLastEvent("Chord needs event-posting permission")
            } else if mapping.action != .defaultClick {
                publishLastEvent("Chord action unavailable")
            }

            chordStateLock.lock()
            replayedButtons.formUnion(presses.map(\.key))
            chordStateLock.unlock()
            presses.forEach { postReplayedEvent($0.downEvent) }
            return
        }

        presses.forEach {
            insertSuppressedButton($0.buttonNumber, deviceIdentifier: $0.deviceIdentifier)
        }
        publishLastEvent("Chord \(chord.buttons.map(String.init).joined(separator: "+"))")
    }

    private func resolvePendingTimeout(key: ButtonEventKey) {
        chordStateLock.lock()
        guard let pending = pendingButtonPresses.removeValue(forKey: key) else {
            chordStateLock.unlock()
            return
        }
        chordStateLock.unlock()

        pending.passthroughTimer?.invalidate()
        let mapping = pending.mapping
        let canPost = !mapping.action.requiresPostEventAccess
            || permissionsManager.status.canPostActions
        let settings = getSettingsSnapshot().effectiveSettings(
            for: activeBundleIdentifier(),
            deviceIdentifier: pending.deviceIdentifier
        )
        let executed = mapping.action != .defaultClick
            && canPost
            && execute(
                mapping,
                settings: settings,
                repeatOwnerKeys: [pending.key]
            )

        if executed {
            insertSuppressedButton(
                pending.buttonNumber,
                deviceIdentifier: pending.deviceIdentifier
            )
            publishLastEvent("Button \(pending.buttonNumber) action")
            return
        }

        chordStateLock.lock()
        replayedButtons.insert(key)
        chordStateLock.unlock()
        postReplayedEvent(pending.downEvent)
    }

    private func handleMouseButtonUp(
        event: CGEvent,
        buttonNumber: Int,
        deviceIdentifier: String?
    ) -> Unmanaged<CGEvent>? {
        stopContinuousActions(
            buttonNumber: buttonNumber,
            deviceIdentifier: deviceIdentifier
        )

        chordStateLock.lock()
        let key = resolvedButtonKeyLocked(buttonNumber: buttonNumber, deviceIdentifier: deviceIdentifier)
        let pending = key.flatMap { pendingButtonPresses.removeValue(forKey: $0) }
        let wasReplayed = key.map { replayedButtons.remove($0) != nil } ?? false
        chordStateLock.unlock()

        if let pending {
            pending.passthroughTimer?.invalidate()
            if pending.wasConsumedByWheelChord {
                _ = removeSuppressedButton(
                    pending.buttonNumber,
                    deviceIdentifier: pending.deviceIdentifier
                )
                return nil
            }
            return resolvePendingPress(pending, hasCurrentUpEvent: true)
                ? Unmanaged.passUnretained(event)
                : nil
        }

        if wasReplayed {
            return Unmanaged.passUnretained(event)
        }

        return removeSuppressedButton(buttonNumber, deviceIdentifier: deviceIdentifier)
            ? nil
            : Unmanaged.passUnretained(event)
    }

    private func handleMouseButtonDragged(
        event: CGEvent,
        buttonNumber: Int,
        deviceIdentifier: String?
    ) -> Unmanaged<CGEvent>? {
        chordStateLock.lock()
        let key = resolvedButtonKeyLocked(buttonNumber: buttonNumber, deviceIdentifier: deviceIdentifier)
        let matchingPending = key.flatMap { pendingButtonPresses[$0] }
        let pending: PendingButtonPress?
        if matchingPending?.wasConsumedByWheelChord == true {
            pending = nil
        } else {
            pending = key.flatMap { pendingButtonPresses.removeValue(forKey: $0) }
        }
        if let key, pending != nil {
            replayedButtons.insert(key)
        }
        chordStateLock.unlock()

        if let pending {
            pending.passthroughTimer?.invalidate()
            postReplayedEvent(pending.downEvent)
        }

        if containsSuppressedButton(
            buttonNumber,
            deviceIdentifier: deviceIdentifier
        ) {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func resolvePendingPress(
        _ pending: PendingButtonPress,
        hasCurrentUpEvent: Bool
    ) -> Bool {
        let mapping = pending.mapping
        let canPost = !mapping.action.requiresPostEventAccess || permissionsManager.status.canPostActions

        let settings = getSettingsSnapshot().effectiveSettings(
            for: activeBundleIdentifier(),
            deviceIdentifier: pending.deviceIdentifier
        )
        let repeatOwnerKeys: Set<ButtonEventKey> = hasCurrentUpEvent
            ? []
            : [pending.key]
        if mapping.action == .defaultClick
            || !canPost
            || !execute(
                mapping,
                settings: settings,
                repeatOwnerKeys: repeatOwnerKeys
            ) {
            postReplayedEvent(pending.downEvent)
            if !hasCurrentUpEvent {
                chordStateLock.lock()
                replayedButtons.insert(pending.key)
                chordStateLock.unlock()
            }
            return hasCurrentUpEvent
        }

        if !hasCurrentUpEvent {
            insertSuppressedButton(
                pending.buttonNumber,
                deviceIdentifier: pending.deviceIdentifier
            )
        }
        return false
    }

    private func postReplayedEvent(_ event: CGEvent) {
        guard let replayedEvent = event.copy() else {
            return
        }

        MousePilotSyntheticEvent.mark(replayedEvent)
        replayedEvent.post(tap: .cghidEventTap)
    }

    private func clearChordState(replayPendingDowns: Bool) {
        chordStateLock.lock()
        let pending = Array(pendingButtonPresses.values)
        pendingButtonPresses.removeAll()
        replayedButtons.removeAll()
        chordStateLock.unlock()

        pending.forEach { press in
            press.passthroughTimer?.invalidate()
            if replayPendingDowns, !press.wasConsumedByWheelChord {
                postReplayedEvent(press.downEvent)
            }
        }
    }

    private func handleScrollWheel(
        event: CGEvent,
        settings: AppSettings,
        deviceIdentifier: String?
    ) -> Unmanaged<CGEvent>? {
        if autoScrollController.isActive {
            autoScrollController.stop()
            publishLastEvent("Auto scroll stopped")
        }

        if deviceMonitor != nil, deviceIdentifier == nil {
            publishScrollType(
                event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
            )
            publishLastEvent("Non-mouse scroll passthrough")
            return Unmanaged.passUnretained(event)
        }

        if let chordResult = resolveButtonWheelChord(
            event: event,
            settings: settings,
            deviceIdentifier: deviceIdentifier
        ) {
            return chordResult ? nil : Unmanaged.passUnretained(event)
        }

        if let wheelMappingResult = resolveWheelMapping(
            event: event,
            settings: settings,
            deviceIdentifier: deviceIdentifier
        ) {
            return wheelMappingResult ? nil : Unmanaged.passUnretained(event)
        }

        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
        publishScrollType(isContinuous != 0)
        guard isContinuous == 0 || settings.smoothScrollingEnabled else {
            publishLastEvent("Continuous scroll passthrough")
            return Unmanaged.passUnretained(event)
        }

        let nativeSensitivity = nativeScrollController?.nativeSensitivityFactor(
            for: deviceIdentifier
        ) ?? 0
        prepareScrollState(
            for: settings,
            nativeSensitivity: nativeSensitivity,
            deviceIdentifier: deviceIdentifier
        )

        let changesDirection = settings.scrollDirection == .reversed
        let nativeMultiplier = ScrollSensitivityMapper.multiplier(for: nativeSensitivity)
        let verticalMultiplier = ScrollSensitivityMapper.multiplier(
            for: settings.verticalScrollSensitivity
        ) / nativeMultiplier
        let horizontalMultiplier = ScrollSensitivityMapper.multiplier(
            for: settings.horizontalScrollSensitivity
        ) / nativeMultiplier
        let changesVerticalSpeed = abs(verticalMultiplier - 1.0) > 0.001
        let changesHorizontalSpeed = abs(horizontalMultiplier - 1.0) > 0.001

        guard changesDirection || changesVerticalSpeed || changesHorizontalSpeed else {
            publishLastEvent("Scroll passthrough")
            return Unmanaged.passUnretained(event)
        }

        let directionMultiplier = changesDirection ? -1.0 : 1.0
        scaleIntegerScrollField(.scrollWheelEventDeltaAxis1, on: event, by: verticalMultiplier * directionMultiplier, deviceIdentifier: deviceIdentifier)
        scaleIntegerScrollField(.scrollWheelEventDeltaAxis2, on: event, by: horizontalMultiplier * directionMultiplier, deviceIdentifier: deviceIdentifier)
        scaleIntegerScrollField(.scrollWheelEventPointDeltaAxis1, on: event, by: verticalMultiplier * directionMultiplier, deviceIdentifier: deviceIdentifier)
        scaleIntegerScrollField(.scrollWheelEventPointDeltaAxis2, on: event, by: horizontalMultiplier * directionMultiplier, deviceIdentifier: deviceIdentifier)
        scaleDoubleScrollField(.scrollWheelEventFixedPtDeltaAxis1, on: event, by: verticalMultiplier * directionMultiplier)
        scaleDoubleScrollField(.scrollWheelEventFixedPtDeltaAxis2, on: event, by: horizontalMultiplier * directionMultiplier)

        publishLastEvent(isContinuous == 0 ? "Wheel scroll remapped" : "Continuous wheel remapped")
        return Unmanaged.passUnretained(event)
    }

    private func resolveButtonWheelChord(
        event: CGEvent,
        settings: AppSettings,
        deviceIdentifier: String?
    ) -> Bool? {
        guard let wheelDirection = wheelDirection(from: event) else {
            return nil
        }

        let modifierFlags = mouseModifierFlags(from: event.flags)
        chordStateLock.lock()
        let pendingButtons = Set(
            pendingButtonPresses.values
                .filter { $0.deviceIdentifier == deviceIdentifier }
                .map(\.buttonNumber)
        )
        guard let chord = settings.resolvedButtonWheelChord(
            for: pendingButtons,
            wheelDirection: wheelDirection,
            modifierFlags: modifierFlags
        ) else {
            chordStateLock.unlock()
            return nil
        }
        let key = ButtonEventKey(
            buttonNumber: chord.buttonNumber,
            deviceIdentifier: deviceIdentifier
        )
        guard let pending = pendingButtonPresses[key] else {
            chordStateLock.unlock()
            return nil
        }
        pending.passthroughTimer?.invalidate()
        let wasAlreadyConsumed = pending.wasConsumedByWheelChord
        chordStateLock.unlock()

        let mapping = chord.actionMapping
        let canPost = !mapping.action.requiresPostEventAccess || permissionsManager.status.canPostActions
        let executed = mapping.action != .defaultClick && canPost && execute(mapping, settings: settings)

        guard executed else {
            if !wasAlreadyConsumed {
                chordStateLock.lock()
                pendingButtonPresses.removeValue(forKey: key)
                replayedButtons.insert(key)
                chordStateLock.unlock()
                postReplayedEvent(pending.downEvent)
            }

            if !canPost {
                publishLastEvent("Button and wheel chord needs event-posting permission")
            } else if mapping.action != .defaultClick {
                publishLastEvent("Button and wheel chord action unavailable")
            }
            return false
        }

        chordStateLock.lock()
        pending.wasConsumedByWheelChord = true
        chordStateLock.unlock()
        insertSuppressedButton(chord.buttonNumber, deviceIdentifier: deviceIdentifier)
        publishLastEvent("Button \(chord.buttonNumber) + \(wheelDirection.displayName)")
        return true
    }

    private func resolveWheelMapping(
        event: CGEvent,
        settings: AppSettings,
        deviceIdentifier: String?
    ) -> Bool? {
        guard let wheelDirection = wheelDirection(from: event) else {
            return nil
        }

        let modifierFlags = mouseModifierFlags(from: event.flags)
        guard let mapping = settings.resolvedWheelMapping(
            for: wheelDirection,
            modifierFlags: modifierFlags
        ) else {
            return nil
        }
        guard mapping.action != .defaultClick else {
            return nil
        }

        if mapping.shortcutOnlyAtScrollStart {
            let stream = WheelRollStreamKey(
                wheelDirection: wheelDirection,
                modifierFlags: modifierFlags,
                deviceIdentifier: deviceIdentifier
            )
            scrollStateLock.lock()
            let isBeginning = wheelRollTracker.isBeginning(
                stream: stream,
                timestamp: Date.timeIntervalSinceReferenceDate,
                scrollPhase: event.getIntegerValueField(.scrollWheelEventScrollPhase),
                momentumPhase: event.getIntegerValueField(.scrollWheelEventMomentumPhase)
            )
            scrollStateLock.unlock()

            guard isBeginning else {
                publishLastEvent("Wheel shortcut continuation suppressed")
                return true
            }
        }

        if mapping.action == .disabled {
            publishLastEvent("\(wheelDirection.displayName) disabled")
            return true
        }

        guard !mapping.action.requiresPostEventAccess
            || permissionsManager.status.canPostActions else {
            publishLastEvent("Wheel action needs event-posting permission")
            return false
        }

        guard execute(mapping.actionMapping, settings: settings) else {
            publishLastEvent("Wheel action unavailable")
            return false
        }

        publishLastEvent("\(wheelDirection.displayName) action")
        return true
    }

    private func wheelDirection(from event: CGEvent) -> WheelDirection? {
        let vertical = nonzeroScrollValue(
            fixed: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1),
            point: event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1),
            line: event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        )
        let horizontal = nonzeroScrollValue(
            fixed: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2),
            point: event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2),
            line: event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        )

        guard vertical != 0 || horizontal != 0 else {
            return nil
        }

        if abs(vertical) >= abs(horizontal) {
            return vertical > 0 ? .up : .down
        }

        return horizontal > 0 ? .left : .right
    }

    private func nonzeroScrollValue(fixed: Double, point: Int64, line: Int64) -> Double {
        if fixed.isFinite, fixed != 0 {
            return fixed
        }
        if point != 0 {
            return Double(point)
        }
        return Double(line)
    }

    private func execute(
        _ mapping: ButtonMapping,
        settings: AppSettings,
        repeatOwnerKeys: Set<ButtonEventKey> = []
    ) -> Bool {
        if mapping.action == .autoScroll {
            return autoScrollController.toggle(direction: settings.scrollDirection)
        }

        if mapping.action == .appSwitcher, !repeatOwnerKeys.isEmpty {
            guard let sessionID = ActionExecutor.startAppSwitcherSession() else {
                return false
            }

            registerContinuousAction(sessionID, ownerKeys: repeatOwnerKeys)
            return true
        }

        if mapping.shortcutRepeatEnabled,
           mapping.action.supportsShortcutRepeat,
           !repeatOwnerKeys.isEmpty {
            guard let repeatID = ActionExecutor.startShortcutRepeat(mapping) else {
                return false
            }

            registerContinuousAction(repeatID, ownerKeys: repeatOwnerKeys)
            return true
        }

        return ActionExecutor.execute(mapping)
    }

    private func registerContinuousAction(
        _ repeatID: UUID,
        ownerKeys: Set<ButtonEventKey>
    ) {
        continuousActionStateLock.lock()
        continuousActionOwners[repeatID] = ownerKeys
        for ownerKey in ownerKeys {
            continuousActionSessionsByButton[ownerKey, default: []].insert(repeatID)
        }
        continuousActionStateLock.unlock()
    }

    private func stopContinuousActions(
        buttonNumber: Int,
        deviceIdentifier: String?
    ) {
        continuousActionStateLock.lock()
        let exactKey = ButtonEventKey(
            buttonNumber: buttonNumber,
            deviceIdentifier: deviceIdentifier
        )
        let matchingKeys: [ButtonEventKey]
        if continuousActionSessionsByButton[exactKey] != nil {
            matchingKeys = [exactKey]
        } else if deviceIdentifier == nil {
            matchingKeys = continuousActionSessionsByButton.keys.filter {
                $0.buttonNumber == buttonNumber
            }
        } else {
            matchingKeys = []
        }

        let repeatIDs = Set(
            matchingKeys.flatMap { continuousActionSessionsByButton[$0] ?? [] }
        )
        for repeatID in repeatIDs {
            removeContinuousActionLocked(repeatID)
        }
        continuousActionStateLock.unlock()

        repeatIDs.forEach(ActionExecutor.stopContinuousAction)
    }

    private func clearContinuousActionSessions() {
        continuousActionStateLock.lock()
        let repeatIDs = Array(continuousActionOwners.keys)
        continuousActionOwners.removeAll()
        continuousActionSessionsByButton.removeAll()
        continuousActionStateLock.unlock()

        repeatIDs.forEach(ActionExecutor.stopContinuousAction)
    }

    private func removeContinuousActionLocked(_ repeatID: UUID) {
        guard let ownerKeys = continuousActionOwners.removeValue(forKey: repeatID) else {
            return
        }

        for ownerKey in ownerKeys {
            continuousActionSessionsByButton[ownerKey]?.remove(repeatID)
            if continuousActionSessionsByButton[ownerKey]?.isEmpty == true {
                continuousActionSessionsByButton[ownerKey] = nil
            }
        }
    }

    private func insertSuppressedButton(_ buttonNumber: Int, deviceIdentifier: String?) {
        suppressedButtonsLock.lock()
        suppressedButtons.insert(
            ButtonEventKey(buttonNumber: buttonNumber, deviceIdentifier: deviceIdentifier)
        )
        suppressedButtonsLock.unlock()
    }

    private func removeSuppressedButton(_ buttonNumber: Int, deviceIdentifier: String?) -> Bool {
        suppressedButtonsLock.lock()
        let exactKey = ButtonEventKey(
            buttonNumber: buttonNumber,
            deviceIdentifier: deviceIdentifier
        )
        let candidates = suppressedButtons.filter { $0.buttonNumber == buttonNumber }
        let key: ButtonEventKey?
        if suppressedButtons.contains(exactKey) {
            key = exactKey
        } else if deviceIdentifier == nil, candidates.count == 1 {
            key = candidates.first
        } else {
            key = nil
        }
        let wasRemoved = key.map { suppressedButtons.remove($0) != nil } ?? false
        suppressedButtonsLock.unlock()
        return wasRemoved
    }

    private func containsSuppressedButton(
        _ buttonNumber: Int,
        deviceIdentifier: String?
    ) -> Bool {
        suppressedButtonsLock.lock()
        let exactKey = ButtonEventKey(
            buttonNumber: buttonNumber,
            deviceIdentifier: deviceIdentifier
        )
        let candidates = suppressedButtons.filter { $0.buttonNumber == buttonNumber }
        let isSuppressed = suppressedButtons.contains(exactKey)
            || (deviceIdentifier == nil && candidates.count == 1)
        suppressedButtonsLock.unlock()
        return isSuppressed
    }

    private func resolvedButtonKeyLocked(
        buttonNumber: Int,
        deviceIdentifier: String?
    ) -> ButtonEventKey? {
        let exactKey = ButtonEventKey(
            buttonNumber: buttonNumber,
            deviceIdentifier: deviceIdentifier
        )
        if pendingButtonPresses[exactKey] != nil || replayedButtons.contains(exactKey) {
            return exactKey
        }

        let candidates = Set(
            pendingButtonPresses.keys.filter { $0.buttonNumber == buttonNumber }
                + replayedButtons.filter { $0.buttonNumber == buttonNumber }
        )
        return candidates.count == 1 ? candidates.first : exactKey
    }

    private func clearSuppressedButtons() {
        suppressedButtonsLock.lock()
        suppressedButtons.removeAll()
        suppressedButtonsLock.unlock()
    }

    private func shouldResolveUnattributedButtonUp(_ buttonNumber: Int) -> Bool {
        guard deviceMonitor?.hasHeldButton(number: buttonNumber) != true else {
            return false
        }

        chordStateLock.lock()
        let hasChordState = pendingButtonPresses.keys.contains {
            $0.buttonNumber == buttonNumber
        } || replayedButtons.contains {
            $0.buttonNumber == buttonNumber
        }
        chordStateLock.unlock()
        if hasChordState {
            return true
        }

        continuousActionStateLock.lock()
        let hasContinuousAction = continuousActionSessionsByButton.keys.contains {
            $0.buttonNumber == buttonNumber
        }
        continuousActionStateLock.unlock()
        if hasContinuousAction {
            return true
        }

        suppressedButtonsLock.lock()
        let hasSuppressedState = suppressedButtons.contains {
            $0.buttonNumber == buttonNumber
        }
        suppressedButtonsLock.unlock()
        return hasSuppressedState
    }

    private func scaleIntegerScrollField(
        _ field: CGEventField,
        on event: CGEvent,
        by multiplier: Double,
        deviceIdentifier: String?
    ) {
        let value = event.getIntegerValueField(field)
        guard value != 0, multiplier.isFinite else { return }

        scrollStateLock.lock()
        let key = ScrollRemainderKey(
            device: ScrollDeviceKey(deviceIdentifier: deviceIdentifier),
            field: field.rawValue
        )
        let accumulated = Double(value) * multiplier + (scrollRemainders[key] ?? 0)
        let emitted = accumulated.isFinite
            ? accumulated.rounded(.towardZero)
            : 0
        scrollRemainders[key] = accumulated.isFinite ? accumulated - emitted : 0
        scrollStateLock.unlock()

        let bounded = min(
            max(emitted, Double(Int32.min)),
            Double(Int32.max)
        )
        event.setIntegerValueField(field, value: Int64(bounded))
    }

    private func scaleDoubleScrollField(_ field: CGEventField, on event: CGEvent, by multiplier: Double) {
        let value = event.getDoubleValueField(field)
        guard value.isFinite, multiplier.isFinite, value != 0 else { return }
        let scaledValue = value * multiplier
        guard scaledValue.isFinite else { return }
        event.setDoubleValueField(field, value: scaledValue)
    }

    private func prepareScrollState(
        for settings: AppSettings,
        nativeSensitivity: Double,
        deviceIdentifier: String?
    ) {
        let configuration = ScrollConfiguration(
            direction: settings.scrollDirection,
            verticalSensitivity: settings.verticalScrollSensitivity,
            horizontalSensitivity: settings.horizontalScrollSensitivity,
            nativeSensitivity: nativeSensitivity,
            continuousEnabled: settings.smoothScrollingEnabled
        )
        let deviceKey = ScrollDeviceKey(deviceIdentifier: deviceIdentifier)

        scrollStateLock.lock()
        if configuration != lastScrollConfigurations[deviceKey] {
            scrollRemainders = scrollRemainders.filter { $0.key.device != deviceKey }
            lastScrollConfigurations[deviceKey] = configuration
        }
        scrollStateLock.unlock()
    }

    private func clearScrollState() {
        scrollStateLock.lock()
        wheelRollTracker.clear()
        scrollRemainders.removeAll()
        lastScrollConfigurations.removeAll()
        scrollStateLock.unlock()
    }

    private func activeBundleIdentifier() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private func mouseButtonNumber(for eventType: CGEventType, event: CGEvent) -> Int {
        switch eventType {
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged:
            return 0
        case .rightMouseDown, .rightMouseUp, .rightMouseDragged:
            return 1
        default:
            return Int(event.getIntegerValueField(.mouseEventButtonNumber))
        }
    }

    private func mouseModifierFlags(from eventFlags: CGEventFlags) -> MouseModifierFlags {
        var result: MouseModifierFlags = []

        if eventFlags.contains(.maskCommand) {
            result.insert(.command)
        }

        if eventFlags.contains(.maskShift) {
            result.insert(.shift)
        }

        if eventFlags.contains(.maskAlternate) {
            result.insert(.option)
        }

        if eventFlags.contains(.maskControl) {
            result.insert(.control)
        }

        return result
    }

    private func publishLastEvent(_ description: String) {
        let now = Date()
        guard now.timeIntervalSince(lastPublishedEventTime) > 0.15 else {
            return
        }

        lastPublishedEventTime = now
        DispatchQueue.main.async { [weak self] in
            self?.lastEventDescription = description
        }
    }

    private func publishDetectedButton(
        _ buttonNumber: Int,
        modifierFlags: MouseModifierFlags,
        deviceIdentifier: String?
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.lastDetectedButtonNumber = buttonNumber
            self?.lastDetectedModifierFlags = modifierFlags
            self?.lastDetectedDeviceIdentifier = deviceIdentifier
        }
    }

    private func publishScrollType(_ isContinuous: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.lastScrollEventIsContinuous = isContinuous
        }
    }

}

private nonisolated func mouseEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<MouseEventManager>.fromOpaque(userInfo).takeUnretainedValue()
    let invocation = MouseEventTapInvocation(
        proxy: proxy,
        type: type,
        event: event
    )
    return MainActor.assumeIsolated {
        MouseEventTapResult(
            event: manager.handleEvent(
                proxy: invocation.proxy,
                type: invocation.type,
                event: invocation.event
            )
        )
    }.event
}
