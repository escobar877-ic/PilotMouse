import Foundation

struct MouseCursorMapper {
    private static let minimumSensitivityLevel = 5.0
    private static let maximumSensitivityLevel = 1990.0
    private static let defaultSensitivityLevel = 1900.0

    static func hidAccelerationValue(
        accelerationEnabled: Bool,
        accelerationLevel: Double
    ) -> Double {
        let finiteLevel = accelerationLevel.isFinite ? accelerationLevel : 0
        let normalizedLevel = min(max(finiteLevel, 0), 99) / 99.0

        guard accelerationEnabled else {
            return 0
        }

        return 5.0 * normalizedLevel * normalizedLevel
    }

    static func hidPointerResolutionValue(sensitivityLevel: Double) -> Double {
        let finiteSensitivity = sensitivityLevel.isFinite
            ? sensitivityLevel
            : defaultSensitivityLevel
        let sensitivity = min(
            max(finiteSensitivity, minimumSensitivityLevel),
            maximumSensitivityLevel
        )
        return 2000.0 - sensitivity
    }

    static func sensitivityLevel(fromLegacyMouseSpeedLevel level: Double) -> Double {
        let finiteLevel = level.isFinite ? level : 50
        let clamped = min(max(finiteLevel, 0), 100)
        return minimumSensitivityLevel
            + (clamped / 100) * (maximumSensitivityLevel - minimumSensitivityLevel)
    }

    static func legacyMouseSpeedLevel(fromSensitivityLevel sensitivity: Double) -> Double {
        let finiteSensitivity = sensitivity.isFinite
            ? sensitivity
            : defaultSensitivityLevel
        let clamped = min(
            max(finiteSensitivity, minimumSensitivityLevel),
            maximumSensitivityLevel
        )
        return ((clamped - minimumSensitivityLevel)
            / (maximumSensitivityLevel - minimumSensitivityLevel)) * 100
    }

    static func windowsLikeValue(sensitivityLevel: Double) -> Double {
        hidPointerResolutionValue(sensitivityLevel: sensitivityLevel)
    }
}
