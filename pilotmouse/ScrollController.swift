import AppKit
import Combine
import Foundation

@MainActor
final class ScrollController: ObservableObject {
    @Published private(set) var currentAcceleration: Double?
    @Published private(set) var originalAcceleration: Double?
    @Published private(set) var desiredAcceleration: Double?
    @Published private(set) var currentResolution: Double?
    @Published private(set) var originalResolution: Double?
    @Published private(set) var desiredSensitivityFactor: Double?
    @Published private(set) var deviceCount = 0
    @Published private(set) var deviceNames: [String] = []
    @Published private(set) var reapplyCount = 0
    @Published var lastError: String?

    private struct Configuration: Equatable {
        let defaultDeviceConfiguration: HIDScrollAccelerationController.DeviceConfiguration
        let perDeviceConfigurations: [String: HIDScrollAccelerationController.DeviceConfiguration]

        var hasEnabledConfiguration: Bool {
            defaultDeviceConfiguration.isEnabled
                || perDeviceConfigurations.values.contains(where: \.isEnabled)
        }

        func configuration(
            for deviceIdentifier: String?
        ) -> HIDScrollAccelerationController.DeviceConfiguration {
            guard let deviceIdentifier else { return defaultDeviceConfiguration }
            return perDeviceConfigurations[deviceIdentifier] ?? defaultDeviceConfiguration
        }
    }

    private let hidController = HIDScrollAccelerationController()
    private var applyTimer: Timer?
    private var applyRevision: UInt64 = 0
    private var stickyTimer: Timer?
    private var stickyStartDate: Date?
    private var stickyInterval: TimeInterval = 0.75
    private var lastHandledConfiguration: Configuration?
    private var desiredConfiguration: Configuration?
    private var appliedSensitivityFactors = [String: Double]()
    private var commonAppliedSensitivityFactor: Double?
    private var activeBundleIdentifier: String?
    private var recentReapplyDates: [Date] = []

    init() {
        updateState(from: hidController.readSnapshot())
    }

    isolated deinit {
        applyTimer?.invalidate()
        stickyTimer?.invalidate()
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
        let configuration = scrollConfiguration(
            for: settings,
            bundleIdentifier: activeBundleIdentifier
        )

        guard configuration != lastHandledConfiguration else {
            return
        }

        lastHandledConfiguration = configuration

        if configuration.hasEnabledConfiguration {
            if debounce {
                scheduleApply(configuration)
            } else {
                cancelScheduledApply()
                applyDesiredSettings(configuration)
            }
        } else {
            restoreOriginalScrollSettings()
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
        hidController.refreshConnection()
        lastHandledConfiguration = nil
        handleSettingsChanged(
            settings,
            activeBundleIdentifier: activeBundleIdentifier,
            debounce: false
        )
    }

    func nativeSensitivityFactor(for deviceIdentifier: String?) -> Double? {
        if let deviceIdentifier,
           let factor = appliedSensitivityFactors[deviceIdentifier] {
            return factor
        }

        return commonAppliedSensitivityFactor
    }

    func restoreOriginalScrollSettings() {
        cancelScheduledApply()
        stopStickyMonitor(clearDesiredValue: true)

        let snapshot = hidController.restoreOriginalScrollSettings()
        updateState(from: snapshot)
        appliedSensitivityFactors.removeAll()
        commonAppliedSensitivityFactor = nil
        lastError = nil
    }

    private func scheduleApply(_ configuration: Configuration) {
        cancelScheduledApply()
        let revision = applyRevision
        applyTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.applyRevision == revision else { return }
                self.applyTimer = nil
                self.applyDesiredSettings(configuration)
            }
        }
    }

    private func cancelScheduledApply() {
        applyRevision &+= 1
        applyTimer?.invalidate()
        applyTimer = nil
    }

    private func applyDesiredSettings(_ configuration: Configuration) {
        desiredConfiguration = configuration
        updateDesiredValues(from: configuration)

        if hasConflictingMouseUtility {
            lastError = nil
            recentReapplyDates.removeAll()
            startStickyMonitor()
            return
        }

        let snapshot = hidController.applyScrollSettings(
            defaultConfiguration: configuration.defaultDeviceConfiguration,
            perDeviceConfigurations: configuration.perDeviceConfigurations
        )
        updateState(from: snapshot)
        updateError(for: snapshot, configuration: configuration)
        let activeCount = activeDeviceCount(
            in: snapshot,
            configuration: configuration
        )
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
        stickyTimer?.invalidate()
        stickyStartDate = Date()
        stickyInterval = 0.75
        scheduleStickyTimer(interval: stickyInterval)
    }

    private func scheduleStickyTimer(interval: TimeInterval) {
        stickyTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.verifyAndReapplyIfNeeded()
            }
        }
    }

    private func stopStickyMonitor(clearDesiredValue: Bool) {
        stickyTimer?.invalidate()
        stickyTimer = nil
        stickyStartDate = nil

        if clearDesiredValue {
            desiredAcceleration = nil
            desiredSensitivityFactor = nil
            desiredConfiguration = nil
            recentReapplyDates.removeAll()
        }
    }

    private func verifyAndReapplyIfNeeded() {
        guard let desiredConfiguration else {
            stopStickyMonitor(clearDesiredValue: false)
            return
        }

        let snapshot = hidController.readSnapshot()
        updateState(from: snapshot)

        guard !snapshot.devices.isEmpty else {
            lastError = "No external USB or Bluetooth mouse was found"
            slowStickyMonitorIfNeeded()
            return
        }
        guard !hasConflictingMouseUtility else {
            lastError = nil
            slowStickyMonitorIfNeeded()
            return
        }
        guard !snapshotMatches(snapshot, configuration: desiredConfiguration) else {
            lastError = nil
            slowStickyMonitorIfNeeded()
            return
        }

        let now = Date()
        recentReapplyDates.removeAll {
            now.timeIntervalSince($0) > 30
        }
        guard recentReapplyDates.count < 3 else {
            lastError = "Another process or the mouse driver keeps replacing wheel settings"
            stopStickyMonitor(clearDesiredValue: false)
            return
        }

        let appliedSnapshot = hidController.applyScrollSettings(
            defaultConfiguration: desiredConfiguration.defaultDeviceConfiguration,
            perDeviceConfigurations: desiredConfiguration.perDeviceConfigurations
        )
        updateState(from: appliedSnapshot)
        reapplyCount += 1
        updateError(for: appliedSnapshot, configuration: desiredConfiguration)
        if snapshotMatches(
            appliedSnapshot,
            configuration: desiredConfiguration
        ) {
            recentReapplyDates.append(now)
            slowStickyMonitorIfNeeded()
        } else {
            stopStickyMonitor(clearDesiredValue: false)
        }
    }

    private func updateError(
        for snapshot: HIDScrollAccelerationController.Snapshot,
        configuration: Configuration
    ) {
        let activeCount = activeDeviceCount(in: snapshot, configuration: configuration)
        if snapshot.devices.isEmpty {
            lastError = "No external USB or Bluetooth mouse was found"
        } else if snapshot.appliedAccelerationDeviceCount < activeCount {
            lastError = "Wheel acceleration was not accepted by every configured mouse"
        } else if snapshot.appliedResolutionDeviceCount < activeCount {
            lastError = "Hardware wheel sensitivity is unavailable; event scaling remains active"
        } else if !snapshotMatches(snapshot, configuration: configuration) {
            lastError = "The mouse driver replaced the requested wheel settings"
        } else {
            lastError = nil
        }
    }

    private func slowStickyMonitorIfNeeded() {
        guard stickyInterval < 5,
              let stickyStartDate,
              Date().timeIntervalSince(stickyStartDate) > 10 else {
            return
        }
        stickyInterval = 5
        stickyTimer?.invalidate()
        scheduleStickyTimer(interval: stickyInterval)
    }

    private func scrollConfiguration(
        for settings: AppSettings,
        bundleIdentifier: String?
    ) -> Configuration {
        let defaultSettings = settings.effectiveSettings(
            for: bundleIdentifier,
            deviceIdentifier: nil
        )
        var perDevice = [String: HIDScrollAccelerationController.DeviceConfiguration]()
        for profile in settings.deviceProfiles where profile.isEnabled {
            let effective = settings.effectiveSettings(
                for: bundleIdentifier,
                deviceIdentifier: profile.deviceIdentifier
            )
            perDevice[profile.deviceIdentifier] = deviceConfiguration(for: effective)
        }
        return Configuration(
            defaultDeviceConfiguration: deviceConfiguration(for: defaultSettings),
            perDeviceConfigurations: perDevice
        )
    }

    private func deviceConfiguration(
        for settings: AppSettings
    ) -> HIDScrollAccelerationController.DeviceConfiguration {
        HIDScrollAccelerationController.DeviceConfiguration(
            isEnabled: settings.isEnabled,
            acceleration: settings.scrollAccelerationEnabled
                ? min(max(settings.scrollAcceleration, 0), 20)
                : -1,
            sensitivityFactor: min(max(settings.verticalScrollSensitivity, -100), 1)
        )
    }

    private func representativeConfiguration(
        in configuration: Configuration
    ) -> HIDScrollAccelerationController.DeviceConfiguration? {
        if configuration.defaultDeviceConfiguration.isEnabled {
            return configuration.defaultDeviceConfiguration
        }
        return configuration.perDeviceConfigurations.values.first(where: \.isEnabled)
    }

    private func updateDesiredValues(from configuration: Configuration) {
        let representative = representativeConfiguration(in: configuration)
        desiredAcceleration = representative?.acceleration
        desiredSensitivityFactor = representative?.sensitivityFactor
    }

    private func activeDeviceCount(
        in snapshot: HIDScrollAccelerationController.Snapshot,
        configuration: Configuration
    ) -> Int {
        snapshot.devices.filter {
            configuration.configuration(for: $0.profileIdentifier).isEnabled
        }.count
    }

    private func snapshotMatches(
        _ snapshot: HIDScrollAccelerationController.Snapshot,
        configuration: Configuration
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
                  let currentResolution = device.resolution,
                  let originalResolution = device.originalResolution else {
                return false
            }

            let expected = configuration.configuration(for: device.profileIdentifier)
            let expectedResolution = ScrollSensitivityMapper.resolution(
                forBaseResolution: originalResolution,
                factor: expected.sensitivityFactor
            )
            return abs(currentAcceleration - expected.acceleration) <= 0.001
                && abs(currentResolution - expectedResolution) <= 0.01
        }
    }

    private func updateState(from snapshot: HIDScrollAccelerationController.Snapshot) {
        currentAcceleration = snapshot.firstAcceleration
        currentResolution = snapshot.firstResolution
        deviceCount = snapshot.discoveredDeviceCount
        deviceNames = snapshot.deviceNames
        updateAppliedSensitivityFactors(from: snapshot)

        if let originalAcceleration = snapshot.originalFirstAcceleration {
            self.originalAcceleration = originalAcceleration
        }
        if let originalResolution = snapshot.originalFirstResolution {
            self.originalResolution = originalResolution
        }
    }

    private func updateAppliedSensitivityFactors(
        from snapshot: HIDScrollAccelerationController.Snapshot
    ) {
        let measuredFactors = snapshot.devices.compactMap { device -> (String, Double)? in
            guard let resolution = device.resolution,
                  let originalResolution = device.originalResolution,
                  resolution > 0,
                  originalResolution > 0 else {
                return nil
            }

            let multiplier = originalResolution / resolution
            return (
                device.profileIdentifier,
                ScrollSensitivityMapper.factor(forMultiplier: multiplier)
            )
        }

        var factorsByIdentifier = [String: [Double]]()
        for (identifier, factor) in measuredFactors {
            factorsByIdentifier[identifier, default: []].append(factor)
        }

        appliedSensitivityFactors = factorsByIdentifier.compactMapValues { factors in
            guard let first = factors.first,
                  factors.allSatisfy({ abs($0 - first) <= 0.001 }) else {
                return nil
            }
            return first
        }

        guard let first = measuredFactors.first?.1,
              measuredFactors.allSatisfy({ abs($0.1 - first) <= 0.001 }) else {
            commonAppliedSensitivityFactor = nil
            return
        }
        commonAppliedSensitivityFactor = first
    }

    private var hasConflictingMouseUtility: Bool {
        let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.contains { application in
            guard application.processIdentifier != ownProcessIdentifier else { return false }

            let bundleIdentifier = application.bundleIdentifier?.lowercased() ?? ""
            let name = application.localizedName?.lowercased() ?? ""
            return bundleIdentifier.contains("steermouse")
                || bundleIdentifier.contains("cursorsense")
                || bundleIdentifier.contains("linearmouse")
                || bundleIdentifier.contains("bettermouse")
                || bundleIdentifier.contains("macmousefix")
                || bundleIdentifier.contains("usboverdrive")
                || name.contains("steermouse")
                || name.contains("cursor sense")
                || name.contains("linear mouse")
                || name.contains("better mouse")
                || name.contains("mac mouse fix")
                || name.contains("usb overdrive")
        }
    }
}
