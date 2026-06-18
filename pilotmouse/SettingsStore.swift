import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    static let storageKey = "MousePilot.AppSettings.v1"
    private static let legacyStorageKeys = ["MousePilot.settings.v2"]

    @Published private(set) var settings: AppSettings

    var onSettingsChanged: ((AppSettings) -> Void)?

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.settings = Self.loadSettings(from: userDefaults)
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

    func actionForButton(_ buttonNumber: Int) -> MouseAction {
        settings.actionForButton(buttonNumber)
    }

    func action(for buttonNumber: Int) -> MouseAction {
        actionForButton(buttonNumber)
    }

    func setButtonAction(_ action: MouseAction, for buttonNumber: Int) {
        updateSettings { $0.setAction(action, for: buttonNumber) }
    }

    func setScrollDirection(_ direction: ScrollDirection) {
        updateSettings { $0.scrollDirection = direction }
    }

    func setVerticalScrollSpeed(_ value: Double) {
        updateSettings { $0.verticalScrollSpeed = value }
    }

    func setHorizontalScrollSpeed(_ value: Double) {
        updateSettings { $0.horizontalScrollSpeed = value }
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
        updateSettings { $0.pointerControlEnabled = value }
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
            $0.windowsLikeModeEnabled = false
        }
        return settings
    }

    @discardableResult
    func setMouseAccelerationEnabled(_ value: Bool) -> AppSettings {
        updateSettings {
            $0.mouseAccelerationEnabled = value
            $0.windowsLikeModeEnabled = false
        }
        return settings
    }

    func setWindowsLikeModeEnabled(_ value: Bool) {
        updateSettings { $0.windowsLikeModeEnabled = value }
    }

    @discardableResult
    func applyWindowsLikePointerPreset() -> AppSettings {
        updateSettings {
            $0.pointerControlEnabled = true
            $0.windowsLikeModeEnabled = true
            $0.mouseSpeedLevel = 72
            $0.mouseTrackingSpeed = MouseSpeedMapper.hidValue(from: 72)
            $0.mouseAccelerationEnabled = true
        }
        return settings
    }

    func resetToDefaults() {
        settings = .defaultSettings
        save()
        onSettingsChanged?(settings)
    }

    private func save() {
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
        result.verticalScrollSpeed = min(max(result.verticalScrollSpeed, 0.25), 5.0)
        result.horizontalScrollSpeed = min(max(result.horizontalScrollSpeed, 0.25), 5.0)
        result.pointerSpeed = min(max(result.pointerSpeed, 0.25), 3.0)
        result.preciseModeSpeed = min(max(result.preciseModeSpeed, 0.1), 1.0)
        result.mouseTrackingSpeed = min(max(result.mouseTrackingSpeed, 0.0), 5.0)
        result.mouseSpeedLevel = min(max(result.mouseSpeedLevel, 0.0), 100.0)

        for defaultMapping in AppSettings.defaultSettings.buttonMappings where !result.buttonMappings.contains(where: { $0.buttonNumber == defaultMapping.buttonNumber }) {
            result.buttonMappings.append(defaultMapping)
        }

        result.buttonMappings.sort { $0.buttonNumber < $1.buttonNumber }
        return result
    }
}
