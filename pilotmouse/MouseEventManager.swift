import ApplicationServices
import Combine
import CoreGraphics
import Foundation

final class MouseEventManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastEventDescription = "No mouse events seen"
    @Published private(set) var lastErrorReason: String?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let permissionsManager: PermissionsManager
    private let settingsLock = NSLock()
    private let suppressedButtonsLock = NSLock()
    private var currentSettings: AppSettings
    private var suppressedButtons = Set<Int>()
    private var lastPublishedEventTime = Date.distantPast

    init(settings: AppSettings, permissionsManager: PermissionsManager) {
        self.currentSettings = settings
        self.permissionsManager = permissionsManager
    }

    deinit {
        stop()
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
        currentSettings = settings
        settingsLock.unlock()
    }

    func getSettingsSnapshot() -> AppSettings {
        settingsLock.lock()
        let copy = currentSettings
        settingsLock.unlock()
        return copy
    }

    func start() {
        guard eventTap == nil else {
            isRunning = true
            return
        }

        permissionsManager.refresh()
        let permissionStatus = permissionsManager.status
        guard permissionStatus.canUseEventTap else {
            isRunning = false
            lastErrorReason = permissionStatus.accessibilityTrusted ? "Input Monitoring permission missing" : "Accessibility permission missing"
            lastEventDescription = lastErrorReason ?? "Unknown event tap error"
            return
        }

        let eventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: MouseEventManager.eventTapCallback,
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

        clearSuppressedButtons()
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

        if !permissionStatus.listenEventAccess {
            return "Input Monitoring permission missing"
        }

        return "CGEvent.tapCreate returned nil"
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            publishLastEvent("Event tap re-enabled")
            return Unmanaged.passUnretained(event)
        }

        let settings = getSettingsSnapshot()
        guard settings.isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .otherMouseDown:
            return handleOtherMouseDown(event: event, settings: settings)
        case .otherMouseUp:
            return handleOtherMouseUp(event: event)
        case .scrollWheel:
            return handleScrollWheel(event: event, settings: settings)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleOtherMouseDown(event: CGEvent, settings: AppSettings) -> Unmanaged<CGEvent>? {
        let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        publishLastEvent("Button \(buttonNumber) down")

        if buttonNumber == 0 || buttonNumber == 1 {
            return Unmanaged.passUnretained(event)
        }

        let action = settings.actionForButton(buttonNumber)

        switch action {
        case .defaultClick:
            return Unmanaged.passUnretained(event)
        case .disabled:
            insertSuppressedButton(buttonNumber)
            return nil
        case .launchpad, .customShortcut, .openApplication:
            // Placeholder actions must never swallow mouse input in the stable build.
            return Unmanaged.passUnretained(event)
        default:
            insertSuppressedButton(buttonNumber)
            ActionExecutor.execute(action)
            return nil
        }
    }

    private func handleOtherMouseUp(event: CGEvent) -> Unmanaged<CGEvent>? {
        let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        if buttonNumber == 0 || buttonNumber == 1 {
            return Unmanaged.passUnretained(event)
        }

        return removeSuppressedButton(buttonNumber) ? nil : Unmanaged.passUnretained(event)
    }

    private func handleScrollWheel(event: CGEvent, settings: AppSettings) -> Unmanaged<CGEvent>? {
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
        guard isContinuous == 0 else {
            publishLastEvent("Continuous scroll passthrough")
            return Unmanaged.passUnretained(event)
        }

        let changesDirection = settings.scrollDirection == .reversed
        let changesVerticalSpeed = abs(settings.verticalScrollSpeed - 1.0) > 0.001
        let changesHorizontalSpeed = abs(settings.horizontalScrollSpeed - 1.0) > 0.001

        guard changesDirection || changesVerticalSpeed || changesHorizontalSpeed else {
            publishLastEvent("Scroll passthrough")
            return Unmanaged.passUnretained(event)
        }

        let directionMultiplier = changesDirection ? -1.0 : 1.0
        scaleIntegerScrollField(.scrollWheelEventDeltaAxis1, on: event, by: settings.verticalScrollSpeed * directionMultiplier)
        scaleIntegerScrollField(.scrollWheelEventDeltaAxis2, on: event, by: settings.horizontalScrollSpeed * directionMultiplier)
        scaleIntegerScrollField(.scrollWheelEventPointDeltaAxis1, on: event, by: settings.verticalScrollSpeed * directionMultiplier)
        scaleIntegerScrollField(.scrollWheelEventPointDeltaAxis2, on: event, by: settings.horizontalScrollSpeed * directionMultiplier)

        publishLastEvent("Wheel scroll remapped")
        return Unmanaged.passUnretained(event)
    }

    private func insertSuppressedButton(_ buttonNumber: Int) {
        suppressedButtonsLock.lock()
        suppressedButtons.insert(buttonNumber)
        suppressedButtonsLock.unlock()
    }

    private func removeSuppressedButton(_ buttonNumber: Int) -> Bool {
        suppressedButtonsLock.lock()
        let wasRemoved = suppressedButtons.remove(buttonNumber) != nil
        suppressedButtonsLock.unlock()
        return wasRemoved
    }

    private func clearSuppressedButtons() {
        suppressedButtonsLock.lock()
        suppressedButtons.removeAll()
        suppressedButtonsLock.unlock()
    }

    private func scaleIntegerScrollField(_ field: CGEventField, on event: CGEvent, by multiplier: Double) {
        let value = event.getIntegerValueField(field)
        guard value != 0 else { return }
        event.setIntegerValueField(field, value: Int64((Double(value) * multiplier).rounded()))
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

    private static let eventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let manager = Unmanaged<MouseEventManager>.fromOpaque(userInfo).takeUnretainedValue()
        return manager.handleEvent(proxy: proxy, type: type, event: event)
    }
}
