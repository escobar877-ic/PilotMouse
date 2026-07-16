import AppKit
import Combine
import Foundation
import ServiceManagement

enum SettingsTransferError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            "This settings file uses unsupported format version \(version)."
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    static let storageKey = "MousePilot.AppSettings.v1"
    private static let legacyStorageKeys = ["MousePilot.settings.v2"]
    private static let settingsDocumentVersion = 1

    private struct SettingsDocument: Codable {
        let formatVersion: Int
        let exportedAt: Date
        let settings: AppSettings
    }

    @Published private(set) var settings: AppSettings
    @Published private(set) var lastExternalApplicationName: String?
    @Published private(set) var lastExternalApplicationBundleIdentifier: String?
    @Published private(set) var frontmostApplicationBundleIdentifier: String?
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginRequiresApproval: Bool
    @Published private(set) var launchAtLoginError: String?

    var onSettingsChanged: ((AppSettings) -> Void)?
    var onFrontmostApplicationChanged: ((String?) -> Void)?

    private let userDefaults: UserDefaults
    private var workspaceActivationObserver: NSObjectProtocol?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.settings = Self.loadSettings(from: userDefaults)
        let loginStatus = SMAppService.mainApp.status
        self.launchAtLoginEnabled = loginStatus == .enabled
        self.launchAtLoginRequiresApproval = loginStatus == .requiresApproval
        self.launchAtLoginError = nil
        Self.persist(settings, to: userDefaults)
        recordExternalApplication(NSWorkspace.shared.frontmostApplication)
        startApplicationMonitoring()
    }

    isolated deinit {
        if let workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceActivationObserver)
        }
    }

    func updateSettings(_ transform: (inout AppSettings) -> Void) {
        var updated = settings
        transform(&updated)
        updated = Self.normalized(updated)

        guard updated != settings else {
            return
        }

        settings = updated
        save()
        onSettingsChanged?(updated)
    }

    func setEnabled(_ value: Bool) {
        updateSettings { $0.isEnabled = value }
    }

    func setAppTheme(_ theme: AppTheme) {
        updateSettings { $0.appTheme = theme }
    }

    func setSelectedTab(_ tab: AppTab) {
        updateSettings { $0.selectedTab = tab }
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLaunchAtLoginStatus()
    }

    func refreshLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLoginEnabled = status == .enabled
        launchAtLoginRequiresApproval = status == .requiresApproval
    }

    func openLoginItemsSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.users?LoginItems",
            "x-apple.systempreferences:"
        ]
        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func actionForButton(_ buttonNumber: Int) -> MouseAction {
        settings.actionForButton(buttonNumber)
    }

    func action(for buttonNumber: Int) -> MouseAction {
        actionForButton(buttonNumber)
    }

    func mapping(for buttonNumber: Int, modifierFlags: MouseModifierFlags = []) -> ButtonMapping {
        settings.mapping(for: buttonNumber, modifierFlags: modifierFlags)
    }

    func setButtonAction(_ action: MouseAction, for buttonNumber: Int, modifierFlags: MouseModifierFlags = []) {
        updateSettings { $0.setAction(action, for: buttonNumber, modifierFlags: modifierFlags) }
    }

    func setButtonMapping(_ mapping: ButtonMapping) {
        updateSettings { $0.setMapping(mapping) }
    }

    func addButtonChord() {
        updateSettings { settings in
            if let chord = Self.nextAvailableChord(existing: settings.buttonChords) {
                settings.buttonChords.append(chord)
            }
        }
    }

    func updateButtonChord(_ chord: ButtonChordMapping) {
        updateSettings { settings in
            var chord = chord
            chord.buttons = ButtonChordMapping.normalizedButtons(chord.buttons)
            guard chord.isValid,
                  !settings.buttonChords.contains(where: { $0.id != chord.id && $0.signature == chord.signature }) else {
                return
            }

            guard let index = settings.buttonChords.firstIndex(where: { $0.id == chord.id }) else {
                return
            }

            settings.buttonChords[index] = chord
        }
    }

    func removeButtonChord(id: UUID) {
        updateSettings { $0.buttonChords.removeAll { $0.id == id } }
    }

    func addButtonWheelChord() {
        updateSettings { settings in
            if let chord = Self.nextAvailableButtonWheelChord(existing: settings.buttonWheelChords) {
                settings.buttonWheelChords.append(chord)
            }
        }
    }

    func updateButtonWheelChord(_ chord: ButtonWheelChordMapping) {
        updateSettings { settings in
            guard chord.isValid,
                  !settings.buttonWheelChords.contains(where: { $0.id != chord.id && $0.signature == chord.signature }),
                  let index = settings.buttonWheelChords.firstIndex(where: { $0.id == chord.id }) else {
                return
            }

            settings.buttonWheelChords[index] = chord
        }
    }

    func removeButtonWheelChord(id: UUID) {
        updateSettings { $0.buttonWheelChords.removeAll { $0.id == id } }
    }

    func wheelMapping(
        for wheelDirection: WheelDirection,
        modifierFlags: MouseModifierFlags = []
    ) -> WheelMapping? {
        settings.wheelMappings.first {
            $0.wheelDirection == wheelDirection
                && $0.modifierFlags == modifierFlags
        }
    }

    func setWheelMapping(_ mapping: WheelMapping) {
        updateSettings { settings in
            settings.wheelMappings.removeAll { $0.id == mapping.id }
            settings.wheelMappings.append(mapping)
        }
    }

    func setWheelMappings(_ mappings: [WheelMapping]) {
        updateSettings { $0.wheelMappings = mappings }
    }

    func removeWheelMapping(
        for wheelDirection: WheelDirection,
        modifierFlags: MouseModifierFlags = []
    ) {
        updateSettings {
            $0.wheelMappings.removeAll {
                $0.wheelDirection == wheelDirection
                    && $0.modifierFlags == modifierFlags
            }
        }
    }

    func addButtonChord(toApplicationProfile profileID: UUID) {
        updateSettings { settings in
            guard let profileIndex = settings.applicationProfiles.firstIndex(where: { $0.id == profileID }),
                  let chord = Self.nextAvailableChord(existing: settings.applicationProfiles[profileIndex].buttonChords) else {
                return
            }

            settings.applicationProfiles[profileIndex].buttonChords.append(chord)
        }
    }

    func updateButtonChord(_ chord: ButtonChordMapping, inApplicationProfile profileID: UUID) {
        updateSettings { settings in
            guard let profileIndex = settings.applicationProfiles.firstIndex(where: { $0.id == profileID }) else {
                return
            }

            var chord = chord
            chord.buttons = ButtonChordMapping.normalizedButtons(chord.buttons)
            let profileChords = settings.applicationProfiles[profileIndex].buttonChords
            guard chord.isValid,
                  !profileChords.contains(where: { $0.id != chord.id && $0.signature == chord.signature }),
                  let chordIndex = profileChords.firstIndex(where: { $0.id == chord.id }) else {
                return
            }

            settings.applicationProfiles[profileIndex].buttonChords[chordIndex] = chord
        }
    }

    func removeButtonChord(id chordID: UUID, fromApplicationProfile profileID: UUID) {
        updateSettings { settings in
            guard let profileIndex = settings.applicationProfiles.firstIndex(where: { $0.id == profileID }) else {
                return
            }

            settings.applicationProfiles[profileIndex].buttonChords.removeAll { $0.id == chordID }
        }
    }

    func addButtonWheelChord(toApplicationProfile profileID: UUID) {
        updateSettings { settings in
            guard let profileIndex = settings.applicationProfiles.firstIndex(where: { $0.id == profileID }),
                  let chord = Self.nextAvailableButtonWheelChord(
                    existing: settings.applicationProfiles[profileIndex].buttonWheelChords
                  ) else {
                return
            }

            settings.applicationProfiles[profileIndex].buttonWheelChords.append(chord)
        }
    }

    func updateButtonWheelChord(_ chord: ButtonWheelChordMapping, inApplicationProfile profileID: UUID) {
        updateSettings { settings in
            guard let profileIndex = settings.applicationProfiles.firstIndex(where: { $0.id == profileID }) else {
                return
            }

            let profileChords = settings.applicationProfiles[profileIndex].buttonWheelChords
            guard chord.isValid,
                  !profileChords.contains(where: { $0.id != chord.id && $0.signature == chord.signature }),
                  let chordIndex = profileChords.firstIndex(where: { $0.id == chord.id }) else {
                return
            }

            settings.applicationProfiles[profileIndex].buttonWheelChords[chordIndex] = chord
        }
    }

    func removeButtonWheelChord(id chordID: UUID, fromApplicationProfile profileID: UUID) {
        updateSettings { settings in
            guard let profileIndex = settings.applicationProfiles.firstIndex(where: { $0.id == profileID }) else {
                return
            }

            settings.applicationProfiles[profileIndex].buttonWheelChords.removeAll { $0.id == chordID }
        }
    }

    func setCustomShortcut(_ shortcut: KeyboardShortcutDefinition?, for buttonNumber: Int, modifierFlags: MouseModifierFlags = []) {
        updateSettings {
            var mapping = $0.mapping(for: buttonNumber, modifierFlags: modifierFlags)
            mapping.customShortcut = shortcut
            if !mapping.action.needsCustomShortcut {
                mapping.action = .customShortcut
            }
            $0.setMapping(mapping)
        }
    }

    func setOpenTarget(_ target: String?, for buttonNumber: Int, modifierFlags: MouseModifierFlags = []) {
        updateSettings {
            var mapping = $0.mapping(for: buttonNumber, modifierFlags: modifierFlags)
            mapping.openTarget = target
            mapping.openTargets = target.map { [$0] } ?? []
            $0.setMapping(mapping)
        }
    }

    func setOpenTargets(
        _ targets: [String],
        for buttonNumber: Int,
        modifierFlags: MouseModifierFlags = []
    ) {
        updateSettings {
            var mapping = $0.mapping(for: buttonNumber, modifierFlags: modifierFlags)
            mapping.openTargets = targets
            mapping.openTarget = targets.first
            $0.setMapping(mapping)
        }
    }

    func addApplicationProfile(name: String, bundleIdentifier: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedBundleIdentifier.isEmpty else {
            return
        }

        updateSettings {
            if let index = $0.applicationProfiles.firstIndex(where: {
                $0.bundleIdentifier.caseInsensitiveCompare(trimmedBundleIdentifier) == .orderedSame
            }) {
                $0.applicationProfiles[index].name = trimmedName
                $0.applicationProfiles[index].isEnabled = true
                return
            }

            $0.applicationProfiles.append(
                ApplicationProfile(
                    name: trimmedName,
                    bundleIdentifier: trimmedBundleIdentifier,
                    buttonMappings: $0.buttonMappings,
                    buttonChords: $0.buttonChords,
                    buttonWheelChords: $0.buttonWheelChords,
                    wheelMappings: $0.wheelMappings,
                    middleClickBehavior: $0.middleClickBehavior,
                    scrollDirection: $0.scrollDirection,
                    verticalScrollSpeed: $0.verticalScrollSpeed,
                    horizontalScrollSpeed: $0.horizontalScrollSpeed,
                    scrollAccelerationEnabled: $0.scrollAccelerationEnabled,
                    scrollAcceleration: $0.scrollAcceleration,
                    verticalScrollSensitivity: $0.verticalScrollSensitivity,
                    horizontalScrollSensitivity: $0.horizontalScrollSensitivity,
                    smoothScrollingEnabled: $0.smoothScrollingEnabled,
                    cursorControlEnabled: $0.cursorControlEnabled,
                    accelerationEnabled: $0.accelerationEnabled,
                    accelerationLevel: $0.accelerationLevel,
                    sensitivityLevel: $0.sensitivityLevel,
                    cursorAutoSnapDestination: $0.cursorAutoSnapDestination,
                    cursorAutoSnapReturnsToOriginal: $0.cursorAutoSnapReturnsToOriginal,
                    cursorAutoSnapMovesInstantly: $0.cursorAutoSnapMovesInstantly
                )
            )
        }
    }

    func addLastActiveApplicationProfile() {
        guard
            let name = lastExternalApplicationName,
            let bundleIdentifier = lastExternalApplicationBundleIdentifier
        else {
            return
        }

        addApplicationProfile(name: name, bundleIdentifier: bundleIdentifier)
    }

    func updateApplicationProfile(_ profile: ApplicationProfile) {
        updateSettings {
            guard let index = $0.applicationProfiles.firstIndex(where: { $0.id == profile.id }) else {
                return
            }

            $0.applicationProfiles[index] = profile
        }
    }

    func removeApplicationProfile(id: UUID) {
        updateSettings { $0.applicationProfiles.removeAll { $0.id == id } }
    }

    func addDeviceProfile(name: String, deviceIdentifier: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIdentifier = deviceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedIdentifier.isEmpty else {
            return
        }

        updateSettings {
            if let index = $0.deviceProfiles.firstIndex(where: { $0.deviceIdentifier == trimmedIdentifier }) {
                $0.deviceProfiles[index].name = trimmedName
                $0.deviceProfiles[index].isEnabled = true
                return
            }

            $0.deviceProfiles.append(
                MouseDeviceProfile(
                    name: trimmedName,
                    deviceIdentifier: trimmedIdentifier,
                    buttonMappings: $0.buttonMappings,
                    buttonChords: $0.buttonChords,
                    buttonWheelChords: $0.buttonWheelChords,
                    wheelMappings: $0.wheelMappings,
                    middleClickBehavior: $0.middleClickBehavior,
                    scrollDirection: $0.scrollDirection,
                    verticalScrollSpeed: $0.verticalScrollSpeed,
                    horizontalScrollSpeed: $0.horizontalScrollSpeed,
                    scrollAccelerationEnabled: $0.scrollAccelerationEnabled,
                    scrollAcceleration: $0.scrollAcceleration,
                    verticalScrollSensitivity: $0.verticalScrollSensitivity,
                    horizontalScrollSensitivity: $0.horizontalScrollSensitivity,
                    smoothScrollingEnabled: $0.smoothScrollingEnabled,
                    cursorControlEnabled: $0.cursorControlEnabled,
                    accelerationEnabled: $0.accelerationEnabled,
                    accelerationLevel: $0.accelerationLevel,
                    sensitivityLevel: $0.sensitivityLevel,
                    cursorAutoSnapDestination: $0.cursorAutoSnapDestination,
                    cursorAutoSnapReturnsToOriginal: $0.cursorAutoSnapReturnsToOriginal,
                    cursorAutoSnapMovesInstantly: $0.cursorAutoSnapMovesInstantly
                )
            )
        }
    }

    func updateDeviceProfile(_ profile: MouseDeviceProfile) {
        updateSettings {
            guard let index = $0.deviceProfiles.firstIndex(where: { $0.id == profile.id }) else {
                return
            }
            $0.deviceProfiles[index] = profile
        }
    }

    func removeDeviceProfile(id: UUID) {
        updateSettings { $0.deviceProfiles.removeAll { $0.id == id } }
    }

    func migrateDeviceProfileIdentifier(
        from legacyIdentifier: String,
        to deviceIdentifier: String
    ) {
        guard legacyIdentifier != deviceIdentifier else {
            return
        }

        updateSettings { settings in
            guard let profileIndex = settings.deviceProfiles.firstIndex(where: {
                $0.deviceIdentifier == legacyIdentifier
            }) else {
                return
            }

            if settings.deviceProfiles.contains(where: {
                $0.deviceIdentifier == deviceIdentifier
            }) {
                settings.deviceProfiles.remove(at: profileIndex)
            } else {
                settings.deviceProfiles[profileIndex].deviceIdentifier = deviceIdentifier
            }
        }
    }

    func setScrollDirection(_ direction: ScrollDirection) {
        updateSettings { $0.scrollDirection = direction }
    }

    func setVerticalScrollSpeed(_ value: Double) {
        updateSettings {
            $0.verticalScrollSpeed = value
            $0.verticalScrollSensitivity = ScrollSensitivityMapper.factor(forMultiplier: value)
        }
    }

    func setHorizontalScrollSpeed(_ value: Double) {
        updateSettings {
            $0.horizontalScrollSpeed = value
            $0.horizontalScrollSensitivity = ScrollSensitivityMapper.factor(forMultiplier: value)
        }
    }

    func setScrollAccelerationEnabled(_ value: Bool) {
        updateSettings { $0.scrollAccelerationEnabled = value }
    }

    func setScrollAcceleration(_ value: Double) {
        updateSettings { $0.scrollAcceleration = value }
    }

    func setVerticalScrollSensitivity(_ value: Double) {
        updateSettings {
            $0.verticalScrollSensitivity = value
            $0.verticalScrollSpeed = ScrollSensitivityMapper.multiplier(for: value)
        }
    }

    func setHorizontalScrollSensitivity(_ value: Double) {
        updateSettings {
            $0.horizontalScrollSensitivity = value
            $0.horizontalScrollSpeed = ScrollSensitivityMapper.multiplier(for: value)
        }
    }

    func setSmoothScrollingEnabled(_ value: Bool) {
        updateSettings { $0.smoothScrollingEnabled = value }
    }

    func setMiddleClickBehavior(_ value: MiddleClickBehavior) {
        updateSettings { $0.middleClickBehavior = value }
    }

    func setPointerSpeed(_ value: Double) {
        updateSettings { $0.pointerSpeed = value }
    }

    func setPointerAccelerationEnabled(_ value: Bool) {
        updateSettings { $0.pointerAccelerationEnabled = value }
    }

    func setPreciseModeEnabled(_ value: Bool) {
        updateSettings { $0.preciseModeEnabled = value }
    }

    func setPreciseModeSpeed(_ value: Double) {
        updateSettings { $0.preciseModeSpeed = value }
    }

    @discardableResult
    func setPointerControlEnabled(_ value: Bool) -> AppSettings {
        updateSettings {
            $0.pointerControlEnabled = value
            $0.cursorControlEnabled = value
        }
        return settings
    }

    @discardableResult
    func setMouseTrackingSpeed(_ value: Double) -> AppSettings {
        updateSettings {
            $0.mouseTrackingSpeed = value
            $0.windowsLikeModeEnabled = false
        }
        return settings
    }

    @discardableResult
    func setMouseSpeedLevel(_ value: Double) -> AppSettings {
        updateSettings {
            $0.mouseSpeedLevel = value
            $0.sensitivityLevel = MouseCursorMapper.sensitivityLevel(
                fromLegacyMouseSpeedLevel: value
            )
            $0.windowsLikeModeEnabled = false
        }
        return settings
    }

    @discardableResult
    func setMouseAccelerationEnabled(_ value: Bool) -> AppSettings {
        updateSettings {
            $0.mouseAccelerationEnabled = value
            $0.accelerationEnabled = value
            $0.windowsLikeModeEnabled = false
        }
        return settings
    }

    @discardableResult
    func setCursorControlEnabled(_ value: Bool) -> AppSettings {
        updateSettings {
            $0.cursorControlEnabled = value
            $0.pointerControlEnabled = value
        }
        return settings
    }

    @discardableResult
    func setAccelerationEnabled(_ value: Bool) -> AppSettings {
        updateSettings {
            $0.accelerationEnabled = value
            $0.mouseAccelerationEnabled = value
            $0.windowsLikeModeEnabled = false
        }
        return settings
    }

    @discardableResult
    func setAccelerationLevel(_ value: Double) -> AppSettings {
        updateSettings {
            $0.accelerationLevel = value
            $0.windowsLikeModeEnabled = false
        }
        return settings
    }

    @discardableResult
    func setSensitivityLevel(_ value: Double) -> AppSettings {
        updateSettings {
            $0.sensitivityLevel = value
            $0.mouseSpeedLevel = MouseCursorMapper.legacyMouseSpeedLevel(
                fromSensitivityLevel: value
            )
            $0.windowsLikeModeEnabled = false
        }
        return settings
    }

    func setCursorAutoSnapDestination(_ destination: CursorAutoSnapDestination) {
        updateSettings { $0.cursorAutoSnapDestination = destination }
    }

    func setCursorAutoSnapReturnsToOriginal(_ value: Bool) {
        updateSettings { $0.cursorAutoSnapReturnsToOriginal = value }
    }

    func setCursorAutoSnapMovesInstantly(_ value: Bool) {
        updateSettings { $0.cursorAutoSnapMovesInstantly = value }
    }

    @discardableResult
    func setWindowsLikeModeEnabled(_ value: Bool) -> AppSettings {
        updateSettings { $0.windowsLikeModeEnabled = value }
        return settings
    }

    @discardableResult
    func applyRecommendedCursorPreset() -> AppSettings {
        updateSettings {
            $0.cursorControlEnabled = true
            $0.pointerControlEnabled = true
            $0.accelerationEnabled = true
            $0.mouseAccelerationEnabled = true
            $0.accelerationLevel = 44
            $0.sensitivityLevel = 1900
            $0.mouseSpeedLevel = MouseCursorMapper.legacyMouseSpeedLevel(
                fromSensitivityLevel: 1900
            )
            $0.windowsLikeModeEnabled = false
        }
        return settings
    }

    @discardableResult
    func applyWindowsLikeCursorPreset() -> AppSettings {
        updateSettings {
            $0.cursorControlEnabled = true
            $0.pointerControlEnabled = true
            $0.accelerationEnabled = false
            $0.mouseAccelerationEnabled = false
            $0.accelerationLevel = 0
            $0.sensitivityLevel = 1200
            $0.mouseSpeedLevel = MouseCursorMapper.legacyMouseSpeedLevel(
                fromSensitivityLevel: 1200
            )
            $0.windowsLikeModeEnabled = true
        }
        return settings
    }

    @discardableResult
    func restoreSystemCursorDefaults() -> AppSettings {
        updateSettings {
            $0.cursorControlEnabled = false
            $0.pointerControlEnabled = false
            $0.windowsLikeModeEnabled = false
        }
        return settings
    }

    @discardableResult
    func applyWindowsLikePointerPreset() -> AppSettings {
        applyWindowsLikeCursorPreset()
    }

    func resetToDefaults() {
        settings = .defaultSettings
        save()
        onSettingsChanged?(settings)
    }

    func exportSettings(to url: URL) throws {
        let document = SettingsDocument(
            formatVersion: Self.settingsDocumentVersion,
            exportedAt: Date(),
            settings: settings
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(document).write(to: url, options: .atomic)
    }

    func importSettings(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let importedSettings: AppSettings
        if let document = try? decoder.decode(SettingsDocument.self, from: data) {
            guard document.formatVersion <= Self.settingsDocumentVersion else {
                throw SettingsTransferError.unsupportedVersion(document.formatVersion)
            }
            importedSettings = document.settings
        } else {
            // Accept an older raw AppSettings JSON backup as a migration path.
            importedSettings = try decoder.decode(AppSettings.self, from: data)
        }

        let updated = Self.normalized(importedSettings)
        settings = updated
        save()
        onSettingsChanged?(updated)
    }

    private func save() {
        Self.persist(settings, to: userDefaults)
    }

    private static func persist(_ settings: AppSettings, to userDefaults: UserDefaults) {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: Self.storageKey)
        } catch {
            print("MousePilot settings save failed:", error)
        }
    }

    private static func loadSettings(from userDefaults: UserDefaults) -> AppSettings {
        if let settings = loadSettings(from: userDefaults, key: storageKey) {
            return settings
        }

        for legacyKey in legacyStorageKeys {
            if let settings = loadSettings(from: userDefaults, key: legacyKey) {
                return settings
            }
        }

        return .defaultSettings
    }

    private static func loadSettings(from userDefaults: UserDefaults, key: String) -> AppSettings? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        do {
            return normalized(try JSONDecoder().decode(AppSettings.self, from: data))
        } catch {
            print("MousePilot settings load failed for \(key), using fallback:", error)
            return nil
        }
    }

    private static func normalized(_ settings: AppSettings) -> AppSettings {
        var result = settings
        let defaults = AppSettings.defaultSettings
        result.scrollAcceleration = clampedFinite(
            result.scrollAcceleration,
            to: 0...20,
            fallback: defaults.scrollAcceleration
        )
        result.verticalScrollSensitivity = clampedFinite(
            result.verticalScrollSensitivity,
            to: -100...1,
            fallback: defaults.verticalScrollSensitivity
        )
        result.horizontalScrollSensitivity = clampedFinite(
            result.horizontalScrollSensitivity,
            to: -100...1,
            fallback: defaults.horizontalScrollSensitivity
        )
        result.verticalScrollSpeed = ScrollSensitivityMapper.multiplier(for: result.verticalScrollSensitivity)
        result.horizontalScrollSpeed = ScrollSensitivityMapper.multiplier(for: result.horizontalScrollSensitivity)
        result.pointerSpeed = clampedFinite(result.pointerSpeed, to: 0.25...3, fallback: defaults.pointerSpeed)
        result.preciseModeSpeed = clampedFinite(result.preciseModeSpeed, to: 0.1...1, fallback: defaults.preciseModeSpeed)
        result.mouseTrackingSpeed = clampedFinite(result.mouseTrackingSpeed, to: 0...5, fallback: defaults.mouseTrackingSpeed)
        result.mouseSpeedLevel = clampedFinite(result.mouseSpeedLevel, to: 0...100, fallback: defaults.mouseSpeedLevel)
        result.accelerationLevel = clampedFinite(result.accelerationLevel, to: 0...99, fallback: defaults.accelerationLevel)
        result.sensitivityLevel = clampedFinite(result.sensitivityLevel, to: 5...1990, fallback: defaults.sensitivityLevel)

        result.pointerControlEnabled = result.cursorControlEnabled
        result.mouseAccelerationEnabled = result.accelerationEnabled
        result.mouseSpeedLevel = MouseCursorMapper.legacyMouseSpeedLevel(
            fromSensitivityLevel: result.sensitivityLevel
        )

        for defaultMapping in AppSettings.defaultSettings.buttonMappings where !result.buttonMappings.contains(where: { $0.buttonNumber == defaultMapping.buttonNumber }) {
            result.buttonMappings.append(defaultMapping)
        }

        result.buttonMappings = normalizedMappings(result.buttonMappings)
        result.buttonChords = normalizedChords(result.buttonChords)
        result.buttonWheelChords = normalizedButtonWheelChords(result.buttonWheelChords)
        result.wheelMappings = normalizedWheelMappings(result.wheelMappings)
        var applicationProfilesByBundleIdentifier = [String: ApplicationProfile]()
        var applicationProfileIDs = Set<UUID>()
        for var profile in result.applicationProfiles {
            if !applicationProfileIDs.insert(profile.id).inserted {
                profile.id = UUID()
                applicationProfileIDs.insert(profile.id)
            }
            profile.configurationVersion = ApplicationProfile.currentConfigurationVersion
            profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.bundleIdentifier = profile.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !profile.name.isEmpty, !profile.bundleIdentifier.isEmpty else {
                continue
            }
            profile.scrollAcceleration = clampedFinite(profile.scrollAcceleration, to: 0...20, fallback: defaults.scrollAcceleration)
            profile.verticalScrollSensitivity = clampedFinite(profile.verticalScrollSensitivity, to: -100...1, fallback: defaults.verticalScrollSensitivity)
            profile.horizontalScrollSensitivity = clampedFinite(profile.horizontalScrollSensitivity, to: -100...1, fallback: defaults.horizontalScrollSensitivity)
            profile.verticalScrollSpeed = ScrollSensitivityMapper.multiplier(
                for: profile.verticalScrollSensitivity
            )
            profile.horizontalScrollSpeed = ScrollSensitivityMapper.multiplier(
                for: profile.horizontalScrollSensitivity
            )
            profile.buttonMappings = normalizedMappings(profile.buttonMappings)
            profile.buttonChords = normalizedChords(profile.buttonChords)
            profile.buttonWheelChords = normalizedButtonWheelChords(profile.buttonWheelChords)
            profile.wheelMappings = normalizedWheelMappings(profile.wheelMappings)
            profile.accelerationLevel = clampedFinite(profile.accelerationLevel, to: 0...99, fallback: defaults.accelerationLevel)
            profile.sensitivityLevel = clampedFinite(profile.sensitivityLevel, to: 5...1990, fallback: defaults.sensitivityLevel)
            applicationProfilesByBundleIdentifier[profile.bundleIdentifier.lowercased()] = profile
        }
        result.applicationProfiles = applicationProfilesByBundleIdentifier.values.sorted {
            if $0.name == $1.name {
                return $0.bundleIdentifier.localizedStandardCompare($1.bundleIdentifier) == .orderedAscending
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        var deviceProfilesByIdentifier = [String: MouseDeviceProfile]()
        var deviceProfileIDs = Set<UUID>()
        for var profile in result.deviceProfiles {
            if !deviceProfileIDs.insert(profile.id).inserted {
                profile.id = UUID()
                deviceProfileIDs.insert(profile.id)
            }
            profile.configurationVersion = MouseDeviceProfile.currentConfigurationVersion
            profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.deviceIdentifier = profile.deviceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !profile.name.isEmpty, !profile.deviceIdentifier.isEmpty else {
                continue
            }
            profile.scrollAcceleration = clampedFinite(profile.scrollAcceleration, to: 0...20, fallback: defaults.scrollAcceleration)
            profile.verticalScrollSensitivity = clampedFinite(profile.verticalScrollSensitivity, to: -100...1, fallback: defaults.verticalScrollSensitivity)
            profile.horizontalScrollSensitivity = clampedFinite(profile.horizontalScrollSensitivity, to: -100...1, fallback: defaults.horizontalScrollSensitivity)
            profile.verticalScrollSpeed = ScrollSensitivityMapper.multiplier(for: profile.verticalScrollSensitivity)
            profile.horizontalScrollSpeed = ScrollSensitivityMapper.multiplier(for: profile.horizontalScrollSensitivity)
            profile.accelerationLevel = clampedFinite(profile.accelerationLevel, to: 0...99, fallback: defaults.accelerationLevel)
            profile.sensitivityLevel = clampedFinite(profile.sensitivityLevel, to: 5...1990, fallback: defaults.sensitivityLevel)
            profile.buttonMappings = normalizedMappings(profile.buttonMappings)
            profile.buttonChords = normalizedChords(profile.buttonChords)
            profile.buttonWheelChords = normalizedButtonWheelChords(profile.buttonWheelChords)
            profile.wheelMappings = normalizedWheelMappings(profile.wheelMappings)
            deviceProfilesByIdentifier[profile.deviceIdentifier] = profile
        }
        result.deviceProfiles = deviceProfilesByIdentifier.values.sorted {
            if $0.name == $1.name {
                return $0.deviceIdentifier < $1.deviceIdentifier
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        return result
    }

    private static func normalizedMappings(_ mappings: [ButtonMapping]) -> [ButtonMapping] {
        var mappingsByID = [String: ButtonMapping]()

        for var mapping in mappings where (0...31).contains(mapping.buttonNumber) {
            mapping.modifierFlags = normalizedModifierFlags(
                mapping.modifierFlags
            )
            normalizeActionPayload(&mapping)
            mappingsByID[mapping.id] = mapping
        }

        for defaultMapping in AppSettings.defaultSettings.buttonMappings where mappingsByID[defaultMapping.id] == nil {
            mappingsByID[defaultMapping.id] = defaultMapping
        }

        return mappingsByID.values.sorted {
            if $0.buttonNumber == $1.buttonNumber {
                return $0.modifierFlags.rawValue < $1.modifierFlags.rawValue
            }

            return $0.buttonNumber < $1.buttonNumber
        }
    }

    private static func normalizedWheelMappings(
        _ mappings: [WheelMapping]
    ) -> [WheelMapping] {
        var mappingsByID = [String: WheelMapping]()

        for var mapping in mappings where mapping.action == .defaultClick
            || MouseAction.wheelAssignableActions.contains(mapping.action) {
            mapping.modifierFlags = normalizedModifierFlags(mapping.modifierFlags)
            normalizeActionPayload(&mapping)
            mappingsByID[mapping.id] = mapping
        }

        return mappingsByID.values.sorted { left, right in
            let leftDirection = WheelDirection.allCases.firstIndex(of: left.wheelDirection) ?? 0
            let rightDirection = WheelDirection.allCases.firstIndex(of: right.wheelDirection) ?? 0
            if leftDirection != rightDirection {
                return leftDirection < rightDirection
            }

            return left.modifierFlags.rawValue < right.modifierFlags.rawValue
        }
    }

    private static func nextAvailableChord(existing: [ButtonChordMapping]) -> ButtonChordMapping? {
        let availableButtons = MouseButtonDefinition.preferredChordButtonNumbers
        let existingSignatures = Set(existing.map(\.signature))

        for modifierFlags in MouseModifierFlags.visiblePresets {
            for firstIndex in availableButtons.indices {
                for secondIndex in availableButtons.indices where secondIndex > firstIndex {
                    let chord = ButtonChordMapping(
                        buttons: [availableButtons[firstIndex], availableButtons[secondIndex]],
                        modifierFlags: modifierFlags,
                        action: .missionControl
                    )
                    if !existingSignatures.contains(chord.signature) {
                        return chord
                    }
                }
            }
        }

        return nil
    }

    private static func normalizedChords(_ chords: [ButtonChordMapping]) -> [ButtonChordMapping] {
        var chordsBySignature = [String: ButtonChordMapping]()
        var chordIDs = Set<UUID>()

        for var chord in chords {
            if !chordIDs.insert(chord.id).inserted {
                chord.id = UUID()
                chordIDs.insert(chord.id)
            }
            chord.buttons = ButtonChordMapping.normalizedButtons(chord.buttons)
            chord.modifierFlags = normalizedModifierFlags(
                chord.modifierFlags
            )
            guard chord.isValid else {
                continue
            }

            normalizeActionPayload(&chord)

            chordsBySignature[chord.signature] = chord
        }

        return chordsBySignature.values.sorted {
            if $0.buttons != $1.buttons {
                return $0.buttons.lexicographicallyPrecedes($1.buttons)
            }

            return $0.modifierFlags.rawValue < $1.modifierFlags.rawValue
        }
    }

    private static func nextAvailableButtonWheelChord(
        existing: [ButtonWheelChordMapping]
    ) -> ButtonWheelChordMapping? {
        let availableButtons = MouseButtonDefinition.preferredChordButtonNumbers
        let existingSignatures = Set(existing.map(\.signature))

        for modifierFlags in MouseModifierFlags.visiblePresets {
            for buttonNumber in availableButtons {
                for wheelDirection in WheelDirection.allCases {
                    let chord = ButtonWheelChordMapping(
                        buttonNumber: buttonNumber,
                        wheelDirection: wheelDirection,
                        modifierFlags: modifierFlags,
                        action: .missionControl
                    )
                    if !existingSignatures.contains(chord.signature) {
                        return chord
                    }
                }
            }
        }

        return nil
    }

    private static func normalizedButtonWheelChords(
        _ chords: [ButtonWheelChordMapping]
    ) -> [ButtonWheelChordMapping] {
        var chordsBySignature = [String: ButtonWheelChordMapping]()
        var chordIDs = Set<UUID>()

        for var chord in chords where chord.isValid {
            if !chordIDs.insert(chord.id).inserted {
                chord.id = UUID()
                chordIDs.insert(chord.id)
            }
            chord.modifierFlags = normalizedModifierFlags(
                chord.modifierFlags
            )
            normalizeActionPayload(&chord)
            chordsBySignature[chord.signature] = chord
        }

        return chordsBySignature.values.sorted { $0.signature < $1.signature }
    }

    private static func normalizeActionPayload(_ mapping: inout ButtonMapping) {
        if mapping.action.needsCustomShortcut {
            mapping.customShortcut = mapping.customShortcut.map(normalizedShortcut)
        } else {
            mapping.customShortcut = nil
        }
        if mapping.action.needsShortcutSequence {
            mapping.shortcutSequence = normalizedShortcutSequence(mapping.shortcutSequence)
        } else {
            mapping.shortcutSequence = nil
        }
        if !mapping.action.supportsShortcutRepeat {
            mapping.shortcutRepeatEnabled = false
        }
        if mapping.action.needsTargetMouseButton {
            mapping.targetMouseButtonNumber = min(
                max(mapping.targetMouseButtonNumber ?? 3, 3),
                31
            )
        } else {
            mapping.targetMouseButtonNumber = nil
        }
        if mapping.action.needsOpenTarget {
            mapping.openTargets = normalizedOpenTargets(
                mapping.openTargets,
                legacyTarget: mapping.openTarget
            )
            mapping.openTarget = mapping.openTargets.first
        } else {
            mapping.openTarget = nil
            mapping.openTargets = []
        }
    }

    private static func normalizeActionPayload(_ chord: inout ButtonChordMapping) {
        if chord.action.needsCustomShortcut {
            chord.customShortcut = chord.customShortcut.map(normalizedShortcut)
        } else {
            chord.customShortcut = nil
        }
        if chord.action.needsShortcutSequence {
            chord.shortcutSequence = normalizedShortcutSequence(chord.shortcutSequence)
        } else {
            chord.shortcutSequence = nil
        }
        if !chord.action.supportsShortcutRepeat {
            chord.shortcutRepeatEnabled = false
        }
        if chord.action.needsTargetMouseButton {
            chord.targetMouseButtonNumber = min(
                max(chord.targetMouseButtonNumber ?? 3, 3),
                31
            )
        } else {
            chord.targetMouseButtonNumber = nil
        }
        if chord.action.needsOpenTarget {
            chord.openTargets = normalizedOpenTargets(
                chord.openTargets,
                legacyTarget: chord.openTarget
            )
            chord.openTarget = chord.openTargets.first
        } else {
            chord.openTarget = nil
            chord.openTargets = []
        }
    }

    private static func normalizeActionPayload(_ chord: inout ButtonWheelChordMapping) {
        if chord.action.needsCustomShortcut {
            chord.customShortcut = chord.customShortcut.map(normalizedShortcut)
        } else {
            chord.customShortcut = nil
        }
        if chord.action.needsShortcutSequence {
            chord.shortcutSequence = normalizedShortcutSequence(chord.shortcutSequence)
        } else {
            chord.shortcutSequence = nil
        }
        if chord.action.needsTargetMouseButton {
            chord.targetMouseButtonNumber = min(
                max(chord.targetMouseButtonNumber ?? 3, 3),
                31
            )
        } else {
            chord.targetMouseButtonNumber = nil
        }
        if chord.action.needsOpenTarget {
            chord.openTargets = normalizedOpenTargets(
                chord.openTargets,
                legacyTarget: chord.openTarget
            )
            chord.openTarget = chord.openTargets.first
        } else {
            chord.openTarget = nil
            chord.openTargets = []
        }
    }

    private static func normalizeActionPayload(_ mapping: inout WheelMapping) {
        if mapping.action.needsCustomShortcut {
            mapping.customShortcut = mapping.customShortcut.map(normalizedShortcut)
        } else {
            mapping.customShortcut = nil
        }
        if mapping.action.needsShortcutSequence {
            mapping.shortcutSequence = normalizedShortcutSequence(mapping.shortcutSequence)
        } else {
            mapping.shortcutSequence = nil
        }
        if !mapping.action.supportsShortcutRepeat {
            mapping.shortcutOnlyAtScrollStart = false
        }
    }

    private static func normalizedShortcutSequence(
        _ sequence: [ShortcutSequenceStep]?
    ) -> [ShortcutSequenceStep]? {
        guard let sequence else {
            return nil
        }

        var seenIDs = Set<UUID>()
        return sequence.prefix(32).enumerated().map { index, originalStep in
            var step = originalStep
            if !seenIDs.insert(step.id).inserted {
                step.id = UUID()
                seenIDs.insert(step.id)
            }
            if !step.operation.needsShortcut {
                step.shortcut = nil
            } else {
                step.shortcut = step.shortcut.map(normalizedShortcut)
            }
            let finiteDelay = step.delayBefore.isFinite ? step.delayBefore : 0
            step.delayBefore = index == 0 ? 0 : min(max(finiteDelay, 0), 5)
            return step
        }
    }

    private static func normalizedOpenTargets(
        _ targets: [String],
        legacyTarget: String?
    ) -> [String] {
        var seen = Set<String>()
        var result = [String]()

        for candidate in targets + (legacyTarget.map { [$0] } ?? []) {
            let target = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !target.isEmpty, seen.insert(target).inserted else {
                continue
            }
            result.append(target)
            if result.count == 32 {
                break
            }
        }

        return result
    }

    private static func normalizedShortcut(
        _ shortcut: KeyboardShortcutDefinition
    ) -> KeyboardShortcutDefinition {
        var shortcut = shortcut
        shortcut.modifiers = normalizedModifierFlags(shortcut.modifiers)
        shortcut.displayText = shortcut.displayText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if shortcut.displayText.isEmpty {
            shortcut.displayText = "Key code \(shortcut.keyCode)"
        }
        return shortcut
    }

    private static func clampedFinite(
        _ value: Double,
        to range: ClosedRange<Double>,
        fallback: Double
    ) -> Double {
        let finiteValue = value.isFinite ? value : fallback
        return min(max(finiteValue, range.lowerBound), range.upperBound)
    }

    private static func normalizedModifierFlags(
        _ flags: MouseModifierFlags
    ) -> MouseModifierFlags {
        MouseModifierFlags(rawValue: flags.rawValue & 0x0F)
    }

    private func startApplicationMonitoring() {
        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            Task { @MainActor [weak self] in
                self?.recordExternalApplication(application)
            }
        }
    }

    private func recordExternalApplication(_ application: NSRunningApplication?) {
        frontmostApplicationBundleIdentifier = application?.bundleIdentifier
        onFrontmostApplicationChanged?(frontmostApplicationBundleIdentifier)

        guard
            let application,
            application.bundleIdentifier != Bundle.main.bundleIdentifier,
            let bundleIdentifier = application.bundleIdentifier,
            !bundleIdentifier.isEmpty
        else {
            return
        }

        lastExternalApplicationName = application.localizedName ?? bundleIdentifier
        lastExternalApplicationBundleIdentifier = bundleIdentifier
    }
}
