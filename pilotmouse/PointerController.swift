import AppKit
import Combine
import Foundation

@MainActor
final class PointerController: ObservableObject {
    @Published private(set) var currentMouseAcceleration: Double?
    @Published private(set) var originalMouseAcceleration: Double?
    @Published private(set) var lastAppliedValue: Double?
    @Published private(set) var desiredMouseAcceleration: Double?
    @Published private(set) var currentPointerResolution: Double?
    @Published private(set) var originalPointerResolution: Double?
    @Published private(set) var lastAppliedPointerResolution: Double?
    @Published private(set) var pointerDeviceCount = 0
    @Published private(set) var pointerDeviceNames: [String] = []
    @Published private(set) var pointerResolutionApplyCount = 0
    @Published private(set) var isStickyApplyEnabled = false
    @Published private(set) var lastSystemValue: Double?
    @Published private(set) var lastReapplyDate: Date?
    @Published private(set) var reapplyCount = 0
    @Published private(set) var conflictingUtilities: [String] = []
    @Published var lastError: String?

    var hasHIDSystemConnection: Bool {
        pointerDeviceCount > 0
    }

    var overrideWarning: String? {
        if !conflictingUtilities.isEmpty {
            return "Quit or disable \(conflictingUtilities.joined(separator: ", ")) before using cursor control. Both apps change the same mouse settings."
        }
        guard reapplyCount > 0 else { return nil }
        return "macOS or another mouse utility replaced the requested cursor settings; MousePilot reapplied them."
    }

    private struct CursorConfiguration: Equatable {
        let defaultDeviceConfiguration: HIDPointerResolutionController.DeviceConfiguration
        let perDeviceConfigurations: [String: HIDPointerResolutionController.DeviceConfiguration]

        var hasEnabledConfiguration: Bool {
            defaultDeviceConfiguration.isEnabled
                || perDeviceConfigurations.values.contains(where: \.isEnabled)
        }

        func configuration(
            for deviceIdentifier: String
        ) -> HIDPointerResolutionController.DeviceConfiguration {
            perDeviceConfigurations[deviceIdentifier] ?? defaultDeviceConfiguration
        }
    }

    private let hidPointerController = HIDPointerResolutionController()
    private var desiredPointerResolution: Double?
    private var desiredCursorConfiguration: CursorConfiguration?
    private var activeBundleIdentifier: String?
    private var stickyTimer: Timer?
    private var applyTimer: Timer?
    private var applyRevision: UInt64 = 0
    private var stickyStartDate: Date?
    private var stickyInterval: TimeInterval = 0.75
    private var lastHandledConfiguration: CursorConfiguration?
    private var recentReapplyDates: [Date] = []

    init() {
        let snapshot = hidPointerController.readSnapshot()
        updateState(from: snapshot)
        originalMouseAcceleration = snapshot.firstAcceleration
        originalPointerResolution = snapshot.firstResolution
        refreshConflictingUtilities()
    }

    isolated deinit {
        applyTimer?.invalidate()
        stickyTimer?.invalidate()
    }

    @discardableResult
    func readCurrentMouseAcceleration() -> Double? {
        let snapshot = hidPointerController.readSnapshot()
        updateState(from: snapshot)
        lastSystemValue = snapshot.firstAcceleration
        return snapshot.firstAcceleration
    }

    func setMouseAcceleration(_ value: Double) {
        let snapshot = hidPointerController.applyMouseAcceleration(value)
        updateState(from: snapshot)
        guard snapshot.appliedAccelerationDeviceCount > 0 else {
            lastError = snapshot.devices.isEmpty
                ? "No external mouse was found"
                : "The connected mouse rejected the acceleration setting"
            return
        }
        lastAppliedValue = value
        lastError = nil
    }

    func applyPointerSettings(_ settings: AppSettings) {
        applyCursorSettings(settings)
    }

    func applyCursorSettings(_ settings: AppSettings) {
        cancelScheduledApply()
        let configuration = cursorConfiguration(
            for: settings,
            bundleIdentifier: activeBundleIdentifier
        )
        guard configuration.hasEnabledConfiguration else {
            restoreOriginalMouseSettings()
            return
        }

        refreshConflictingUtilities()
        desiredCursorConfiguration = configuration
        updateDesiredValues(from: configuration)

        if !conflictingUtilities.isEmpty {
            isStickyApplyEnabled = true
            lastAppliedValue = nil
            lastAppliedPointerResolution = nil
            lastError = nil
            recentReapplyDates.removeAll()
            startStickyMonitor()
            return
        }

        applyDesiredCursorConfiguration(configuration)
    }

    func scheduleApplyCursorSettings(_ settings: AppSettings) {
        scheduleApplyCursorConfiguration(
            cursorConfiguration(for: settings, bundleIdentifier: activeBundleIdentifier)
        )
    }

    func applyStickyMouseAcceleration(_ value: Double) {
        let resolution = currentPointerResolution ?? originalPointerResolution ?? 400
        applyDesiredMouseSettings(acceleration: value, pointerResolution: resolution)
    }

    func applyDesiredMouseSettings(acceleration: Double, pointerResolution: Double) {
        cancelScheduledApply()
        let configuration = CursorConfiguration(
            defaultDeviceConfiguration: HIDPointerResolutionController.DeviceConfiguration(
                isEnabled: true,
                acceleration: acceleration,
                resolution: pointerResolution
            ),
            perDeviceConfigurations: [:]
        )
        applyDesiredCursorConfiguration(configuration)
    }

    func restoreOriginalMouseSettings() {
        cancelScheduledApply()
        stopStickyMonitor(clearDesiredValue: true)

        let snapshot = hidPointerController.restoreOriginalPointerSettings()
        updateState(from: snapshot)
        lastAppliedValue = nil
        lastAppliedPointerResolution = nil
        lastError = nil
    }

    func stopStickyMonitor() {
        stopStickyMonitor(clearDesiredValue: false)
    }

    func handlePointerControlEnabledChanged(_ isEnabled: Bool) {
        if !isEnabled {
            restoreOriginalMouseSettings()
        }
    }

    func handleSettingsChanged(
        _ settings: AppSettings,
        activeBundleIdentifier: String? = nil
    ) {
        handleSettingsChanged(
            settings,
            activeBundleIdentifier: activeBundleIdentifier,
            debounce: true
        )
    }

    private func handleSettingsChanged(
        _ settings: AppSettings,
        activeBundleIdentifier: String?,
        debounce: Bool
    ) {
        self.activeBundleIdentifier = activeBundleIdentifier
        let configuration = cursorConfiguration(
            for: settings,
            bundleIdentifier: activeBundleIdentifier
        )

        guard configuration != lastHandledConfiguration else {
            return
        }

        lastHandledConfiguration = configuration

        if configuration.hasEnabledConfiguration {
            if debounce {
                scheduleApplyCursorConfiguration(configuration)
            } else {
                cancelScheduledApply()
                applyCursorSettings(settings)
            }
        } else {
            restoreOriginalMouseSettings()
        }
    }

    func handleFrontmostApplicationChanged(_ bundleIdentifier: String?, settings: AppSettings) {
        handleSettingsChanged(
            settings,
            activeBundleIdentifier: bundleIdentifier,
            debounce: false
        )
    }

    func refreshAuthorizationAndReapply(
        _ settings: AppSettings,
        activeBundleIdentifier: String?
    ) {
        hidPointerController.refreshConnection()
        lastHandledConfiguration = nil
        handleSettingsChanged(
            settings,
            activeBundleIdentifier: activeBundleIdentifier,
            debounce: false
        )
    }

    func refreshConflictingUtilities() {
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        var names = Set<String>()

        for application in NSWorkspace.shared.runningApplications {
            guard application.processIdentifier != ownProcessIdentifier else { continue }

            let bundleIdentifier = application.bundleIdentifier?.lowercased() ?? ""
            let applicationName = application.localizedName ?? ""
            let lowercasedName = applicationName.lowercased()

            if application.bundleIdentifier == ownBundleIdentifier {
                names.insert("another MousePilot copy")
            } else if bundleIdentifier.contains("steermouse") || lowercasedName.contains("steermouse") {
                names.insert("SteerMouse")
            } else if bundleIdentifier.contains("cursorsense") || lowercasedName.contains("cursorsense") {
                names.insert("CursorSense")
            } else if bundleIdentifier.contains("linearmouse") || lowercasedName.contains("linearmouse") {
                names.insert("LinearMouse")
            } else if bundleIdentifier.contains("bettermouse") || lowercasedName.contains("bettermouse") {
                names.insert("BetterMouse")
            } else if bundleIdentifier.contains("macmousefix") || lowercasedName.contains("mac mouse fix") {
                names.insert("Mac Mouse Fix")
            } else if bundleIdentifier.contains("usboverdrive") || lowercasedName.contains("usb overdrive") {
                names.insert("USB Overdrive")
            }
        }

        conflictingUtilities = names.sorted()
    }

    private func scheduleApplyCursorConfiguration(_ configuration: CursorConfiguration) {
        cancelScheduledApply()
        let revision = applyRevision
        applyTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.applyRevision == revision else { return }
                self.applyTimer = nil
                if configuration.hasEnabledConfiguration {
                    self.refreshConflictingUtilities()
                    self.desiredCursorConfiguration = configuration
                    self.updateDesiredValues(from: configuration)
                    if self.conflictingUtilities.isEmpty {
                        self.applyDesiredCursorConfiguration(configuration)
                    } else {
                        self.isStickyApplyEnabled = true
                        self.lastError = nil
                        self.recentReapplyDates.removeAll()
                        self.startStickyMonitor()
                    }
                } else {
                    self.restoreOriginalMouseSettings()
                }
            }
        }
    }

    private func cancelScheduledApply() {
        applyRevision &+= 1
        applyTimer?.invalidate()
        applyTimer = nil
    }

    private func applyDesiredCursorConfiguration(_ configuration: CursorConfiguration) {
        desiredCursorConfiguration = configuration
        updateDesiredValues(from: configuration)

        let snapshot = hidPointerController.applyPointerSettings(
            defaultConfiguration: configuration.defaultDeviceConfiguration,
            perDeviceConfigurations: configuration.perDeviceConfigurations
        )
        updateState(from: snapshot)
        pointerResolutionApplyCount += snapshot.appliedResolutionDeviceCount
        let representative = representativeConfiguration(in: configuration)
        lastAppliedValue = snapshot.appliedAccelerationDeviceCount > 0
            ? representative?.acceleration
            : nil
        lastAppliedPointerResolution = snapshot.appliedResolutionDeviceCount > 0
            ? representative?.resolution
            : nil
        isStickyApplyEnabled = true

        let activeCount = activeDeviceCount(in: snapshot, configuration: configuration)
        if snapshot.devices.isEmpty {
            lastError = "No external USB or Bluetooth mouse was found"
        } else if snapshot.appliedAccelerationDeviceCount < activeCount {
            lastError = "Acceleration was not accepted by every configured mouse"
        } else if snapshot.appliedResolutionDeviceCount < activeCount {
            lastError = "Sensitivity was not accepted by every configured mouse"
        } else if !snapshotMatches(snapshot, configuration: configuration) {
            lastError = "The mouse driver replaced the requested cursor values"
        } else {
            lastError = nil
        }

        if activeCount > 0,
           snapshot.appliedAccelerationDeviceCount >= activeCount,
           snapshot.appliedResolutionDeviceCount >= activeCount,
           snapshotMatches(snapshot, configuration: configuration) {
            recentReapplyDates.removeAll()
            startStickyMonitor()
        } else {
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
            desiredPointerResolution = nil
            desiredCursorConfiguration = nil
            recentReapplyDates.removeAll()
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
        guard isStickyApplyEnabled, let desiredCursorConfiguration else {
            stopStickyMonitor(clearDesiredValue: false)
            return
        }

        refreshConflictingUtilities()
        let snapshot = hidPointerController.readSnapshot()
        updateState(from: snapshot)
        lastSystemValue = snapshot.firstAcceleration

        guard !snapshot.devices.isEmpty else {
            lastError = "No external USB or Bluetooth mouse was found"
            slowStickyMonitorIfNeeded()
            return
        }
        if !conflictingUtilities.isEmpty {
            lastError = nil
            slowStickyMonitorIfNeeded()
            return
        }
        guard !snapshotMatches(snapshot, configuration: desiredCursorConfiguration) else {
            lastError = nil
            slowStickyMonitorIfNeeded()
            return
        }

        let now = Date()
        recentReapplyDates.removeAll {
            now.timeIntervalSince($0) > 30
        }
        guard recentReapplyDates.count < 3 else {
            lastError = "Another process or the mouse driver keeps replacing cursor settings"
            stopStickyMonitor(clearDesiredValue: false)
            return
        }

        let appliedSnapshot = hidPointerController.applyPointerSettings(
            defaultConfiguration: desiredCursorConfiguration.defaultDeviceConfiguration,
            perDeviceConfigurations: desiredCursorConfiguration.perDeviceConfigurations
        )
        updateState(from: appliedSnapshot)
        pointerResolutionApplyCount += appliedSnapshot.appliedResolutionDeviceCount
        let representative = representativeConfiguration(in: desiredCursorConfiguration)
        lastAppliedValue = appliedSnapshot.appliedAccelerationDeviceCount > 0
            ? representative?.acceleration
            : nil
        lastAppliedPointerResolution = appliedSnapshot.appliedResolutionDeviceCount > 0
            ? representative?.resolution
            : nil
        lastReapplyDate = now
        reapplyCount += 1
        if snapshotMatches(
            appliedSnapshot,
            configuration: desiredCursorConfiguration
        ) {
            recentReapplyDates.append(now)
            lastError = nil
            slowStickyMonitorIfNeeded()
        } else {
            lastError = "The mouse driver rejected or replaced the requested cursor values"
            stopStickyMonitor(clearDesiredValue: false)
        }
    }

    private func slowStickyMonitorIfNeeded() {
        guard stickyInterval < 5,
              let stickyStartDate,
              Date().timeIntervalSince(stickyStartDate) > 10 else {
            return
        }
        stickyInterval = 5
        stopTimerOnly()
        scheduleStickyTimer(interval: stickyInterval)
    }

    private func cursorConfiguration(
        for settings: AppSettings,
        bundleIdentifier: String?
    ) -> CursorConfiguration {
        let defaultSettings = settings.effectiveSettings(
            for: bundleIdentifier,
            deviceIdentifier: nil
        )
        var perDevice = [String: HIDPointerResolutionController.DeviceConfiguration]()
        for profile in settings.deviceProfiles where profile.isEnabled {
            let effective = settings.effectiveSettings(
                for: bundleIdentifier,
                deviceIdentifier: profile.deviceIdentifier
            )
            perDevice[profile.deviceIdentifier] = deviceConfiguration(for: effective)
        }
        return CursorConfiguration(
            defaultDeviceConfiguration: deviceConfiguration(for: defaultSettings),
            perDeviceConfigurations: perDevice
        )
    }

    private func deviceConfiguration(
        for settings: AppSettings
    ) -> HIDPointerResolutionController.DeviceConfiguration {
        HIDPointerResolutionController.DeviceConfiguration(
            isEnabled: settings.isEnabled && settings.cursorControlEnabled,
            acceleration: MouseCursorMapper.hidAccelerationValue(
                accelerationEnabled: settings.accelerationEnabled,
                accelerationLevel: settings.accelerationLevel
            ),
            resolution: MouseCursorMapper.hidPointerResolutionValue(
                sensitivityLevel: settings.sensitivityLevel
            )
        )
    }

    private func representativeConfiguration(
        in configuration: CursorConfiguration
    ) -> HIDPointerResolutionController.DeviceConfiguration? {
        if configuration.defaultDeviceConfiguration.isEnabled {
            return configuration.defaultDeviceConfiguration
        }
        return configuration.perDeviceConfigurations.values.first(where: \.isEnabled)
    }

    private func updateDesiredValues(from configuration: CursorConfiguration) {
        let representative = representativeConfiguration(in: configuration)
        desiredMouseAcceleration = representative?.acceleration
        desiredPointerResolution = representative?.resolution
    }

    private func activeDeviceCount(
        in snapshot: HIDPointerResolutionController.Snapshot,
        configuration: CursorConfiguration
    ) -> Int {
        snapshot.devices.filter {
            configuration.configuration(for: $0.profileIdentifier).isEnabled
        }.count
    }

    private func snapshotMatches(
        _ snapshot: HIDPointerResolutionController.Snapshot,
        configuration: CursorConfiguration
    ) -> Bool {
        let activeDevices = snapshot.devices.filter {
            configuration.configuration(for: $0.profileIdentifier).isEnabled
        }
        if activeDevices.isEmpty {
            return snapshot.devices.isEmpty
                ? !configuration.hasEnabledConfiguration
                : true
        }

        return activeDevices.allSatisfy { device in
            guard let currentAcceleration = device.acceleration,
                  let currentResolution = device.resolution else {
                return false
            }
            let expected = configuration.configuration(for: device.profileIdentifier)
            return abs(currentAcceleration - expected.acceleration) <= 0.01
                && abs(currentResolution - expected.resolution) <= 0.5
        }
    }

    private func updateState(from snapshot: HIDPointerResolutionController.Snapshot) {
        currentMouseAcceleration = snapshot.firstAcceleration
        currentPointerResolution = snapshot.firstResolution
        pointerDeviceCount = snapshot.discoveredDeviceCount
        pointerDeviceNames = snapshot.deviceNames

        if let originalAcceleration = snapshot.originalFirstAcceleration {
            originalMouseAcceleration = originalAcceleration
        }
        if let originalResolution = snapshot.originalFirstResolution {
            originalPointerResolution = originalResolution
        }
    }
}
