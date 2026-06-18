import Combine
import Foundation
import IOKit
import IOKit.hidsystem

struct MouseSpeedMapper {
    static func hidValue(from level: Double) -> Double {
        let clamped = min(max(level, 0), 100)
        let t = clamped / 100.0
        let minValue = 0.35
        let maxValue = 2.80
        let curved = pow(t, 1.7)
        return minValue + (maxValue - minValue) * curved
    }

    static func label(for level: Double) -> String {
        switch level {
        case 0..<26:
            "Slow"
        case 26..<61:
            "Normal"
        case 61..<86:
            "Fast"
        default:
            "Very Fast"
        }
    }
}

@MainActor
final class PointerController: ObservableObject {
    @Published private(set) var currentMouseAcceleration: Double?
    @Published private(set) var originalMouseAcceleration: Double?
    @Published private(set) var lastAppliedValue: Double?
    @Published private(set) var desiredMouseAcceleration: Double?
    @Published private(set) var isStickyApplyEnabled = false
    @Published private(set) var lastSystemValue: Double?
    @Published private(set) var lastReapplyDate: Date?
    @Published private(set) var reapplyCount = 0
    @Published var lastError: String?

    var hasHIDSystemConnection: Bool {
        hidSystemConnection != 0
    }

    var overrideWarning: String? {
        guard reapplyCount > 0 else { return nil }
        return "Another mouse utility or macOS settings may be overriding MousePilot."
    }

    private let mouseAccelerationKey = kIOHIDMouseAccelerationType as CFString
    private var hidSystemConnection: io_connect_t = 0
    private var stickyTimer: Timer?
    private var applyTimer: Timer?
    private var stickyStartDate: Date?
    private var stickyInterval: TimeInterval = 0.75

    init() {
        openHIDSystem()
        let currentValue = readCurrentMouseAcceleration()
        originalMouseAcceleration = currentValue
        currentMouseAcceleration = currentValue
    }

    deinit {
        applyTimer?.invalidate()
        stickyTimer?.invalidate()
        if hidSystemConnection != 0 {
            IOServiceClose(hidSystemConnection)
        }
    }

    @discardableResult
    func readCurrentMouseAcceleration() -> Double? {
        guard ensureConnection() else {
            return nil
        }

        var value = 0.0
        let result = IOHIDGetAccelerationWithKey(hidSystemConnection, mouseAccelerationKey, &value)

        guard result == kIOReturnSuccess else {
            lastError = "IOHIDGetAccelerationWithKey failed: \(result)"
            return nil
        }

        lastError = nil
        currentMouseAcceleration = value
        lastSystemValue = value
        return value
    }

    func setMouseAcceleration(_ value: Double) {
        guard ensureConnection() else {
            lastError = "No IOHIDSystem connection"
            return
        }

        let result = IOHIDSetAccelerationWithKey(hidSystemConnection, mouseAccelerationKey, value)

        guard result == kIOReturnSuccess else {
            lastError = "IOHIDSetAccelerationWithKey failed: \(result)"
            currentMouseAcceleration = readCurrentMouseAcceleration()
            return
        }

        lastAppliedValue = value
        lastError = nil
        currentMouseAcceleration = readCurrentMouseAcceleration()
    }

    func applyPointerSettings(_ settings: AppSettings) {
        guard settings.pointerControlEnabled else {
            stopStickyMonitor(clearDesiredValue: false)
            lastError = "Pointer control is disabled"
            currentMouseAcceleration = readCurrentMouseAcceleration()
            return
        }

        applyDesiredMouseAcceleration(MouseSpeedMapper.hidValue(from: settings.mouseSpeedLevel))
    }

    func scheduleApplySpeedLevel(_ level: Double) {
        applyTimer?.invalidate()
        applyTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                let hidValue = MouseSpeedMapper.hidValue(from: level)
                self?.applyDesiredMouseAcceleration(hidValue)
            }
        }
    }

    func applyStickyMouseAcceleration(_ value: Double) {
        applyDesiredMouseAcceleration(value)
    }

    func applyDesiredMouseAcceleration(_ value: Double) {
        desiredMouseAcceleration = value
        isStickyApplyEnabled = true
        setMouseAcceleration(value)
        startStickyMonitor()
    }

    func restoreOriginalMouseSettings() {
        stopStickyMonitor(clearDesiredValue: true)

        guard let originalMouseAcceleration else {
            lastError = "No original mouse acceleration value saved"
            currentMouseAcceleration = readCurrentMouseAcceleration()
            return
        }

        setMouseAcceleration(originalMouseAcceleration)
    }

    func handlePointerControlEnabledChanged(_ isEnabled: Bool) {
        if !isEnabled {
            stopStickyMonitor(clearDesiredValue: false)
        }
    }

    func handleSettingsChanged(_ settings: AppSettings) {
        if !settings.pointerControlEnabled {
            stopStickyMonitor(clearDesiredValue: false)
        }
    }

    private func startStickyMonitor() {
        stopTimerOnly()
        stickyStartDate = Date()
        stickyInterval = 0.75
        scheduleStickyTimer(interval: stickyInterval)
    }

    private func stopStickyMonitor(clearDesiredValue: Bool) {
        stopTimerOnly()
        isStickyApplyEnabled = false
        stickyStartDate = nil
        if clearDesiredValue {
            desiredMouseAcceleration = nil
        }
    }

    private func stopTimerOnly() {
        stickyTimer?.invalidate()
        stickyTimer = nil
    }

    private func scheduleStickyTimer(interval: TimeInterval) {
        stickyTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.verifyAndReapplyIfNeeded()
            }
        }
    }

    private func verifyAndReapplyIfNeeded() {
        guard isStickyApplyEnabled, let desiredMouseAcceleration else {
            stopStickyMonitor(clearDesiredValue: false)
            return
        }

        let current = readCurrentMouseAcceleration()
        lastSystemValue = current

        guard let current else {
            return
        }

        if abs(current - desiredMouseAcceleration) > 0.05 {
            setMouseAcceleration(desiredMouseAcceleration)
            lastReapplyDate = Date()
            reapplyCount += 1
        }

        if stickyInterval < 5.0, let stickyStartDate, Date().timeIntervalSince(stickyStartDate) > 10.0 {
            stickyInterval = 5.0
            stopTimerOnly()
            scheduleStickyTimer(interval: stickyInterval)
        }
    }

    private func openHIDSystem() {
        if hidSystemConnection != 0 {
            return
        }

        guard let matchingDict = IOServiceMatching(kIOHIDSystemClass) else {
            lastError = "IOServiceMatching failed for IOHIDSystem"
            return
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, matchingDict)
        guard service != IO_OBJECT_NULL else {
            lastError = "IOHIDSystem service not found"
            return
        }
        defer { IOObjectRelease(service) }

        var connect: io_connect_t = 0
        let result = IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect)

        guard result == kIOReturnSuccess else {
            lastError = "IOServiceOpen failed: \(result)"
            return
        }

        hidSystemConnection = connect
    }

    private func ensureConnection() -> Bool {
        if hidSystemConnection != 0 {
            return true
        }

        openHIDSystem()
        return hidSystemConnection != 0
    }
}
