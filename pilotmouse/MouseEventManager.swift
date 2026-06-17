import ApplicationServices
import Combine
import CoreGraphics
import Foundation

final class MouseEventManager: ObservableObject {
    @Published private(set) var isRunning = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let settingsQueue = DispatchQueue(label: "MousePilot.MouseEventManager.settings")
    private var settings: AppSettings
    private var suppressedButtons = Set<Int>()

    init(settings: AppSettings) {
        self.settings = settings
    }

    deinit {
        stop()
    }

    func updateSettings(_ settings: AppSettings) {
        settingsQueue.sync {
            self.settings = settings
        }

        if settings.isEnabled {
            start()
        } else {
            stop()
        }
    }

    func start() {
        guard eventTap == nil else {
            isRunning = true
            return
        }

        let eventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue)
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
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        settingsQueue.sync {
            suppressedButtons.removeAll()
        }

        runLoopSource = nil
        eventTap = nil
        isRunning = false
    }

    func restart() {
        stop()
        let shouldStart = settingsQueue.sync { settings.isEnabled }
        if shouldStart {
            start()
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let currentSettings = settingsQueue.sync { settings }
        guard currentSettings.isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .otherMouseDown:
            return handleOtherMouseDown(event: event, settings: currentSettings)
        case .otherMouseUp:
            return handleOtherMouseUp(event: event)
        case .scrollWheel:
            return handleScrollWheel(event: event, settings: currentSettings)
        case .mouseMoved:
            return handleMouseMoved(event: event, settings: currentSettings)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleOtherMouseDown(event: CGEvent, settings: AppSettings) -> Unmanaged<CGEvent>? {
        let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber))

        // Never interfere with primary buttons; losing left/right click would make recovery difficult.
        guard buttonNumber > 1 else {
            return Unmanaged.passUnretained(event)
        }

        let action = settings.action(for: buttonNumber)

        switch action {
        case .defaultClick:
            return Unmanaged.passUnretained(event)
        case .disabled:
            settingsQueue.sync { _ = suppressedButtons.insert(buttonNumber) }
            return nil
        default:
            settingsQueue.sync { _ = suppressedButtons.insert(buttonNumber) }
            ActionExecutor.execute(action)
            return nil
        }
    }

    private func handleOtherMouseUp(event: CGEvent) -> Unmanaged<CGEvent>? {
        let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        guard buttonNumber > 1 else {
            return Unmanaged.passUnretained(event)
        }

        let shouldSuppress = settingsQueue.sync { suppressedButtons.remove(buttonNumber) != nil }
        return shouldSuppress ? nil : Unmanaged.passUnretained(event)
    }

    private func handleScrollWheel(event: CGEvent, settings: AppSettings) -> Unmanaged<CGEvent>? {
        let changesDirection = settings.scrollDirection == .reversed
        let changesVerticalSpeed = abs(settings.verticalScrollSpeed - 1.0) > 0.001
        let changesHorizontalSpeed = abs(settings.horizontalScrollSpeed - 1.0) > 0.001

        guard changesDirection || changesVerticalSpeed || changesHorizontalSpeed else {
            return Unmanaged.passUnretained(event)
        }

        let directionMultiplier = changesDirection ? -1.0 : 1.0
        scaleIntegerScrollField(.scrollWheelEventDeltaAxis1, on: event, by: settings.verticalScrollSpeed * directionMultiplier)
        scaleIntegerScrollField(.scrollWheelEventDeltaAxis2, on: event, by: settings.horizontalScrollSpeed * directionMultiplier)
        scaleIntegerScrollField(.scrollWheelEventPointDeltaAxis1, on: event, by: settings.verticalScrollSpeed * directionMultiplier)
        scaleIntegerScrollField(.scrollWheelEventPointDeltaAxis2, on: event, by: settings.horizontalScrollSpeed * directionMultiplier)

        // TODO: Tune fixed-point delta handling after device testing across wheels and trackpads.
        return Unmanaged.passUnretained(event)
    }

    private func handleMouseMoved(event: CGEvent, settings: AppSettings) -> Unmanaged<CGEvent>? {
        let preciseMultiplier = settings.preciseModeEnabled ? settings.preciseModeSpeed : 1.0
        let multiplier = settings.pointerSpeed * preciseMultiplier

        guard abs(multiplier - 1.0) > 0.001 else {
            return Unmanaged.passUnretained(event)
        }

        // CGEvent delta edits are intentionally conservative; the system still owns actual acceleration.
        scaleIntegerMouseField(.mouseEventDeltaX, on: event, by: multiplier)
        scaleIntegerMouseField(.mouseEventDeltaY, on: event, by: multiplier)
        return Unmanaged.passUnretained(event)
    }

    private func scaleIntegerScrollField(_ field: CGEventField, on event: CGEvent, by multiplier: Double) {
        let value = event.getIntegerValueField(field)
        guard value != 0 else { return }
        event.setIntegerValueField(field, value: Int64((Double(value) * multiplier).rounded()))
    }

    private func scaleIntegerMouseField(_ field: CGEventField, on event: CGEvent, by multiplier: Double) {
        let value = event.getIntegerValueField(field)
        guard value != 0 else { return }
        event.setIntegerValueField(field, value: Int64((Double(value) * multiplier).rounded()))
    }

    private static let eventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let manager = Unmanaged<MouseEventManager>.fromOpaque(userInfo).takeUnretainedValue()
        return manager.handleEvent(proxy: proxy, type: type, event: event)
    }
}
