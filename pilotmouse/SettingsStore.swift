import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            settings = Self.normalized(settings)
            save()
            onSettingsChanged?(settings)
        }
    }

    var onSettingsChanged: ((AppSettings) -> Void)?

    private let userDefaults: UserDefaults
    private let settingsKey = "MousePilot.settings.v2"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.settings = Self.loadSettings(from: userDefaults, key: settingsKey)
    }

    func setEnabled(_ isEnabled: Bool) {
        update { $0.isEnabled = isEnabled }
    }

    func action(for buttonNumber: Int) -> MouseAction {
        settings.action(for: buttonNumber)
    }

    func setButtonAction(_ action: MouseAction, for buttonNumber: Int) {
        update { settings in
            guard let index = settings.buttonMappings.firstIndex(where: { $0.buttonNumber == buttonNumber }) else {
                settings.buttonMappings.append(ButtonMapping(buttonNumber: buttonNumber, action: action))
                return
            }

            settings.buttonMappings[index].action = action
        }
    }

    func update(_ transform: (inout AppSettings) -> Void) {
        var updated = settings
        transform(&updated)
        settings = updated
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        userDefaults.set(data, forKey: settingsKey)
    }

    private static func loadSettings(from userDefaults: UserDefaults, key: String) -> AppSettings {
        guard
            let data = userDefaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return .defaultSettings
        }

        return normalized(decoded)
    }

    private static func normalized(_ settings: AppSettings) -> AppSettings {
        var result = settings
        result.verticalScrollSpeed = min(max(result.verticalScrollSpeed, 0.25), 5.0)
        result.horizontalScrollSpeed = min(max(result.horizontalScrollSpeed, 0.25), 5.0)
        result.pointerSpeed = min(max(result.pointerSpeed, 0.25), 3.0)
        result.preciseModeSpeed = min(max(result.preciseModeSpeed, 0.1), 1.0)

        for defaultMapping in AppSettings.defaultSettings.buttonMappings where !result.buttonMappings.contains(where: { $0.buttonNumber == defaultMapping.buttonNumber }) {
            result.buttonMappings.append(defaultMapping)
        }

        result.buttonMappings.sort { $0.buttonNumber < $1.buttonNumber }
        return result
    }
}
