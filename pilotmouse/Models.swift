import Foundation

enum MouseAction: String, Codable, CaseIterable, Identifiable {
    case disabled
    case defaultClick
    case leftClick
    case rightClick
    case middleClick
    case doubleClick
    case tripleClick
    case otherMouseClick
    case clickLock
    case keyLeftClick
    case keyRightClick
    case keyDoubleClick
    case back
    case forward
    case missionControl
    case showDesktop
    case launchpad
    case moveSpaceLeft
    case moveSpaceRight
    case desktop1
    case desktop2
    case desktop3
    case desktop4
    case desktop5
    case notificationCenter
    case lookUp
    case spotlight
    case siri
    case quickNote
    case lockScreen
    case appSwitcher
    case previousApplication
    case applicationWindows
    case nextWindow
    case previousWindow
    case closeWindow
    case newTab
    case closeTab
    case copy
    case paste
    case zoomIn
    case zoomOut
    case scrollUp
    case scrollDown
    case scrollLeft
    case scrollRight
    case autoScroll
    case volumeUp
    case volumeDown
    case mute
    case playPause
    case nextTrack
    case previousTrack
    case eject
    case snapToDefaultButton
    case snapToCancelButton
    case snapToCloseButton
    case snapToMinimizeButton
    case snapToFullScreenButton
    case snapToDock
    case snapToScreenCenter
    case customShortcut
    case shortcutSequence
    case openApplication
    case openFile
    case openURL

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .disabled: "Disabled"
        case .defaultClick: "Default Click"
        case .leftClick: "Left Click"
        case .rightClick: "Right Click"
        case .middleClick: "Middle Click"
        case .doubleClick: "Double Click"
        case .tripleClick: "Triple Click"
        case .otherMouseClick: "4th - 32nd Click"
        case .clickLock: "Click Lock"
        case .keyLeftClick: "Key + Left Click"
        case .keyRightClick: "Key + Right Click"
        case .keyDoubleClick: "Key + Double Click"
        case .back: "Back"
        case .forward: "Forward"
        case .missionControl: "Mission Control"
        case .showDesktop: "Show Desktop"
        case .launchpad: "Launchpad"
        case .moveSpaceLeft: "Move Space Left"
        case .moveSpaceRight: "Move Space Right"
        case .desktop1: "Desktop 1"
        case .desktop2: "Desktop 2"
        case .desktop3: "Desktop 3"
        case .desktop4: "Desktop 4"
        case .desktop5: "Desktop 5"
        case .notificationCenter: "Notification Center"
        case .lookUp: "Look Up"
        case .spotlight: "Spotlight"
        case .siri: "Siri"
        case .quickNote: "Quick Note"
        case .lockScreen: "Lock Screen"
        case .appSwitcher: "App Switcher"
        case .previousApplication: "Previous Application"
        case .applicationWindows: "Application Windows"
        case .nextWindow: "Next Window"
        case .previousWindow: "Previous Window"
        case .closeWindow: "Close Window"
        case .newTab: "New Tab"
        case .closeTab: "Close Tab"
        case .copy: "Copy"
        case .paste: "Paste"
        case .zoomIn: "Zoom In"
        case .zoomOut: "Zoom Out"
        case .scrollUp: "Scroll Up"
        case .scrollDown: "Scroll Down"
        case .scrollLeft: "Scroll Left"
        case .scrollRight: "Scroll Right"
        case .autoScroll: "Auto Scroll"
        case .volumeUp: "Volume Up"
        case .volumeDown: "Volume Down"
        case .mute: "Mute"
        case .playPause: "Play / Pause"
        case .nextTrack: "Next Track"
        case .previousTrack: "Previous Track"
        case .eject: "Eject"
        case .snapToDefaultButton: "Snap to Default Button"
        case .snapToCancelButton: "Snap to Cancel Button"
        case .snapToCloseButton: "Snap to Close Button"
        case .snapToMinimizeButton: "Snap to Minimize Button"
        case .snapToFullScreenButton: "Snap to Fullscreen Button"
        case .snapToDock: "Snap to Dock"
        case .snapToScreenCenter: "Snap to Screen Center"
        case .customShortcut: "Custom Keyboard Shortcut"
        case .shortcutSequence: "Keyboard Shortcut Sequence"
        case .openApplication: "Open Application"
        case .openFile: "Open File"
        case .openURL: "Open URL"
        }
    }

    var needsCustomShortcut: Bool {
        switch self {
        case .customShortcut, .keyLeftClick, .keyRightClick, .keyDoubleClick:
            true
        default:
            false
        }
    }

    var needsShortcutSequence: Bool {
        self == .shortcutSequence
    }

    var needsTargetMouseButton: Bool {
        self == .otherMouseClick
    }

    var supportsShortcutRepeat: Bool {
        self == .customShortcut || self == .shortcutSequence
    }

    var needsOpenTarget: Bool {
        switch self {
        case .openApplication, .openFile, .openURL:
            true
        default:
            false
        }
    }

    var requiresPostEventAccess: Bool {
        switch self {
        case .disabled, .defaultClick, .launchpad, .siri, .closeWindow, .snapToDefaultButton, .snapToCancelButton, .snapToCloseButton, .snapToMinimizeButton, .snapToFullScreenButton, .snapToDock, .snapToScreenCenter, .openApplication, .openFile, .openURL:
            false
        default:
            true
        }
    }

    var isImplemented: Bool {
        switch self {
        case .disabled, .defaultClick, .leftClick, .rightClick, .middleClick, .doubleClick, .tripleClick, .otherMouseClick, .clickLock, .keyLeftClick, .keyRightClick, .keyDoubleClick, .back, .forward, .missionControl, .showDesktop, .launchpad, .moveSpaceLeft, .moveSpaceRight, .desktop1, .desktop2, .desktop3, .desktop4, .desktop5, .notificationCenter, .lookUp, .spotlight, .siri, .quickNote, .lockScreen, .appSwitcher, .previousApplication, .applicationWindows, .nextWindow, .previousWindow, .closeWindow, .newTab, .closeTab, .copy, .paste, .zoomIn, .zoomOut, .scrollUp, .scrollDown, .scrollLeft, .scrollRight, .autoScroll, .volumeUp, .volumeDown, .mute, .playPause, .nextTrack, .previousTrack, .eject, .snapToDefaultButton, .snapToCancelButton, .snapToCloseButton, .snapToMinimizeButton, .snapToFullScreenButton, .snapToDock, .snapToScreenCenter, .customShortcut, .shortcutSequence, .openApplication, .openFile, .openURL:
            true
        }
    }

    static let stableActions: [MouseAction] = allCases.filter(\.isImplemented)

    static let wheelAssignableActions: [MouseAction] = [
        .disabled,
        .back,
        .forward,
        .missionControl,
        .showDesktop,
        .launchpad,
        .moveSpaceLeft,
        .moveSpaceRight,
        .desktop1,
        .desktop2,
        .desktop3,
        .desktop4,
        .desktop5,
        .notificationCenter,
        .lookUp,
        .spotlight,
        .quickNote,
        .appSwitcher,
        .previousApplication,
        .applicationWindows,
        .nextWindow,
        .previousWindow,
        .newTab,
        .closeTab,
        .copy,
        .paste,
        .zoomIn,
        .zoomOut,
        .scrollUp,
        .scrollDown,
        .scrollLeft,
        .scrollRight,
        .volumeUp,
        .volumeDown,
        .mute,
        .playPause,
        .nextTrack,
        .previousTrack,
        .eject,
        .customShortcut,
        .shortcutSequence
    ]
}

struct MouseModifierFlags: OptionSet, Codable, Hashable {
    let rawValue: Int

    static let command = MouseModifierFlags(rawValue: 1 << 0)
    static let shift = MouseModifierFlags(rawValue: 1 << 1)
    static let option = MouseModifierFlags(rawValue: 1 << 2)
    static let control = MouseModifierFlags(rawValue: 1 << 3)

    static let supportedFlags: [(flag: MouseModifierFlags, title: String)] = [
        (.command, "Command"),
        (.shift, "Shift"),
        (.option, "Option"),
        (.control, "Control")
    ]

    static let visiblePresets: [MouseModifierFlags] = [
        [],
        .command,
        .shift,
        .option,
        .control,
        [.command, .shift],
        [.command, .option],
        [.shift, .option],
        [.command, .control],
        [.shift, .control],
        [.option, .control],
        [.command, .shift, .option],
        [.command, .shift, .control],
        [.command, .option, .control],
        [.shift, .option, .control],
        [.command, .shift, .option, .control]
    ]

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var displayName: String {
        if isEmpty {
            return "No modifier"
        }

        return Self.supportedFlags
            .filter { contains($0.flag) }
            .map(\.title)
            .joined(separator: " + ")
    }
}

struct KeyboardShortcutDefinition: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: MouseModifierFlags
    var displayText: String

    init(keyCode: UInt16, modifiers: MouseModifierFlags, displayText: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayText = displayText
    }
}

enum ShortcutSequenceOperation: String, Codable, CaseIterable, Identifiable {
    case keyboardShortcut
    case leftClick
    case rightClick
    case middleClick
    case doubleClick

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .keyboardShortcut: "Keyboard Shortcut"
        case .leftClick: "Left Click"
        case .rightClick: "Right Click"
        case .middleClick: "Middle Click"
        case .doubleClick: "Double Click"
        }
    }

    var needsShortcut: Bool {
        self == .keyboardShortcut
    }
}

struct ShortcutSequenceStep: Codable, Identifiable, Equatable {
    var id: UUID
    var operation: ShortcutSequenceOperation
    var shortcut: KeyboardShortcutDefinition?
    var delayBefore: Double

    init(
        id: UUID = UUID(),
        operation: ShortcutSequenceOperation = .keyboardShortcut,
        shortcut: KeyboardShortcutDefinition? = nil,
        delayBefore: Double = 0
    ) {
        self.id = id
        self.operation = operation
        self.shortcut = shortcut
        self.delayBefore = delayBefore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        operation = try container.decodeIfPresent(ShortcutSequenceOperation.self, forKey: .operation) ?? .keyboardShortcut
        shortcut = try container.decodeIfPresent(KeyboardShortcutDefinition.self, forKey: .shortcut)
        delayBefore = try container.decodeIfPresent(Double.self, forKey: .delayBefore) ?? 0
    }

    var isValid: Bool {
        !operation.needsShortcut || shortcut != nil
    }
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

enum AppTab: String, Codable, CaseIterable, Identifiable {
    case buttons
    case wheel
    case pointer
    case profiles
    case permissions
    case about

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .buttons: "Buttons"
        case .wheel: "Wheel"
        case .pointer: "Cursor"
        case .profiles: "Profiles"
        case .permissions: "Permissions"
        case .about: "About"
        }
    }
}

enum ScrollDirection: String, Codable, CaseIterable, Identifiable {
    case natural
    case reversed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .natural: "Natural"
        case .reversed: "Reversed"
        }
    }
}

enum WheelDirection: String, Codable, CaseIterable, Identifiable {
    case up
    case down
    case left
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .up: "Wheel Up"
        case .down: "Wheel Down"
        case .left: "Wheel Left"
        case .right: "Wheel Right"
        }
    }

    var systemImage: String {
        switch self {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .left: "arrow.left"
        case .right: "arrow.right"
        }
    }
}

enum ScrollSensitivityMapper {
    static let supportedFactorRange = -100.0...1.0
    static let sliderPositionRange = -1.0...1.0

    static func multiplier(for factor: Double) -> Double {
        let finiteFactor = factor.isFinite ? factor : 0
        let factor = min(max(finiteFactor, supportedFactorRange.lowerBound), supportedFactorRange.upperBound)
        return factor >= 1.0 ? 1_000.0 : 1.0 / (1.0 - factor)
    }

    static func factor(forMultiplier multiplier: Double) -> Double {
        let finiteMultiplier = multiplier.isFinite ? multiplier : 1
        let clampedMultiplier = max(finiteMultiplier, self.multiplier(for: supportedFactorRange.lowerBound))
        let factor = clampedMultiplier >= 1_000.0 ? 1.0 : 1.0 - (1.0 / clampedMultiplier)
        return min(max(factor, supportedFactorRange.lowerBound), supportedFactorRange.upperBound)
    }

    static func resolution(forBaseResolution baseResolution: Double, factor: Double) -> Double {
        let finiteBaseResolution = baseResolution.isFinite ? max(baseResolution, 0) : 0
        let finiteFactor = factor.isFinite ? factor : 0
        let factor = min(max(finiteFactor, supportedFactorRange.lowerBound), supportedFactorRange.upperBound)
        let coefficient = factor >= 1.0 ? 0.001 : 1.0 - factor
        return min(finiteBaseResolution * coefficient, 1_000.0)
    }

    static func factor(forSliderPosition position: Double) -> Double {
        let finitePosition = position.isFinite ? position : 0
        let position = min(
            max(finitePosition, sliderPositionRange.lowerBound),
            sliderPositionRange.upperBound
        )
        guard position < 0 else {
            return position
        }

        return -(pow(101.0, -position) - 1.0)
    }

    static func sliderPosition(forFactor factor: Double) -> Double {
        let finiteFactor = factor.isFinite ? factor : 0
        let factor = min(
            max(finiteFactor, supportedFactorRange.lowerBound),
            supportedFactorRange.upperBound
        )
        guard factor < 0 else {
            return factor
        }

        return -log(1.0 - factor) / log(101.0)
    }
}

enum ScrollAccelerationMapper {
    static let anchors = [0.0, 0.1, 0.5, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0]
    static let sliderPositionRange = 0.0...Double(anchors.count - 1)

    static func value(forSliderPosition position: Double) -> Double {
        let finitePosition = position.isFinite ? position : 0
        let position = min(
            max(finitePosition, sliderPositionRange.lowerBound),
            sliderPositionRange.upperBound
        )
        let lowerIndex = Int(position.rounded(.down))
        let upperIndex = min(lowerIndex + 1, anchors.count - 1)
        let fraction = position - Double(lowerIndex)
        return anchors[lowerIndex] + ((anchors[upperIndex] - anchors[lowerIndex]) * fraction)
    }

    static func sliderPosition(forValue value: Double) -> Double {
        let finiteValue = value.isFinite ? value : anchors[0]
        let value = min(max(finiteValue, anchors[0]), anchors[anchors.count - 1])

        for index in 0..<(anchors.count - 1) where value <= anchors[index + 1] {
            let span = anchors[index + 1] - anchors[index]
            return Double(index) + ((value - anchors[index]) / span)
        }

        return sliderPositionRange.upperBound
    }
}

enum MiddleClickBehavior: String, Codable, CaseIterable, Identifiable {
    case defaultClick
    case missionControl
    case appSwitcher
    case launchpad

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .defaultClick: "Default"
        case .missionControl: "Mission Control"
        case .appSwitcher: "App Switcher"
        case .launchpad: "Launchpad"
        }
    }

    var action: MouseAction {
        switch self {
        case .defaultClick: .defaultClick
        case .missionControl: .missionControl
        case .appSwitcher: .appSwitcher
        case .launchpad: .launchpad
        }
    }

    static let stableBehaviors: [MiddleClickBehavior] = allCases
}

enum CursorAutoSnapDestination: String, Codable, CaseIterable, Identifiable {
    case none
    case defaultButton
    case cancelButton
    case closeButton
    case minimizeButton
    case fullScreenButton

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "None"
        case .defaultButton: "Default Button"
        case .cancelButton: "Cancel Button"
        case .closeButton: "Close Button"
        case .minimizeButton: "Minimize Button"
        case .fullScreenButton: "Fullscreen Button"
        }
    }

    var accessibilityAttribute: String? {
        switch self {
        case .none: nil
        case .defaultButton: "AXDefaultButton"
        case .cancelButton: "AXCancelButton"
        case .closeButton: "AXCloseButton"
        case .minimizeButton: "AXMinimizeButton"
        case .fullScreenButton: "AXFullScreenButton"
        }
    }
}

struct ButtonMapping: Codable, Identifiable, Equatable {
    var buttonNumber: Int
    var modifierFlags: MouseModifierFlags
    var action: MouseAction
    var customShortcut: KeyboardShortcutDefinition?
    var shortcutSequence: [ShortcutSequenceStep]?
    var shortcutRepeatEnabled: Bool
    var targetMouseButtonNumber: Int?
    var openTarget: String?
    var openTargets: [String]

    var id: String { "\(buttonNumber)-\(modifierFlags.rawValue)" }

    init(
        buttonNumber: Int,
        modifierFlags: MouseModifierFlags = [],
        action: MouseAction,
        customShortcut: KeyboardShortcutDefinition? = nil,
        shortcutSequence: [ShortcutSequenceStep]? = nil,
        shortcutRepeatEnabled: Bool = false,
        targetMouseButtonNumber: Int? = nil,
        openTarget: String? = nil,
        openTargets: [String]? = nil
    ) {
        self.buttonNumber = buttonNumber
        self.modifierFlags = modifierFlags
        self.action = action
        self.customShortcut = customShortcut
        self.shortcutSequence = shortcutSequence
        self.shortcutRepeatEnabled = shortcutRepeatEnabled
        self.targetMouseButtonNumber = targetMouseButtonNumber
        self.openTarget = openTarget
        self.openTargets = openTargets ?? openTarget.map { [$0] } ?? []
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        buttonNumber = try container.decode(Int.self, forKey: .buttonNumber)
        modifierFlags = try container.decodeIfPresent(MouseModifierFlags.self, forKey: .modifierFlags) ?? []
        action = try container.decode(MouseAction.self, forKey: .action)
        customShortcut = try container.decodeIfPresent(KeyboardShortcutDefinition.self, forKey: .customShortcut)
        shortcutSequence = try container.decodeIfPresent([ShortcutSequenceStep].self, forKey: .shortcutSequence)
        shortcutRepeatEnabled = try container.decodeIfPresent(Bool.self, forKey: .shortcutRepeatEnabled) ?? false
        targetMouseButtonNumber = try container.decodeIfPresent(Int.self, forKey: .targetMouseButtonNumber)
        openTarget = try container.decodeIfPresent(String.self, forKey: .openTarget)
        openTargets = try container.decodeIfPresent([String].self, forKey: .openTargets)
            ?? openTarget.map { [$0] }
            ?? []
    }
}

struct ButtonChordMapping: Codable, Identifiable, Equatable {
    var id: UUID
    var buttons: [Int]
    var modifierFlags: MouseModifierFlags
    var action: MouseAction
    var customShortcut: KeyboardShortcutDefinition?
    var shortcutSequence: [ShortcutSequenceStep]?
    var shortcutRepeatEnabled: Bool
    var targetMouseButtonNumber: Int?
    var openTarget: String?
    var openTargets: [String]

    init(
        id: UUID = UUID(),
        buttons: [Int],
        modifierFlags: MouseModifierFlags = [],
        action: MouseAction,
        customShortcut: KeyboardShortcutDefinition? = nil,
        shortcutSequence: [ShortcutSequenceStep]? = nil,
        shortcutRepeatEnabled: Bool = false,
        targetMouseButtonNumber: Int? = nil,
        openTarget: String? = nil,
        openTargets: [String]? = nil
    ) {
        self.id = id
        self.buttons = Self.normalizedButtons(buttons)
        self.modifierFlags = modifierFlags
        self.action = action
        self.customShortcut = customShortcut
        self.shortcutSequence = shortcutSequence
        self.shortcutRepeatEnabled = shortcutRepeatEnabled
        self.targetMouseButtonNumber = targetMouseButtonNumber
        self.openTarget = openTarget
        self.openTargets = openTargets ?? openTarget.map { [$0] } ?? []
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        buttons = Self.normalizedButtons(try container.decode([Int].self, forKey: .buttons))
        modifierFlags = try container.decodeIfPresent(MouseModifierFlags.self, forKey: .modifierFlags) ?? []
        action = try container.decode(MouseAction.self, forKey: .action)
        customShortcut = try container.decodeIfPresent(KeyboardShortcutDefinition.self, forKey: .customShortcut)
        shortcutSequence = try container.decodeIfPresent([ShortcutSequenceStep].self, forKey: .shortcutSequence)
        shortcutRepeatEnabled = try container.decodeIfPresent(Bool.self, forKey: .shortcutRepeatEnabled) ?? false
        targetMouseButtonNumber = try container.decodeIfPresent(Int.self, forKey: .targetMouseButtonNumber)
        openTarget = try container.decodeIfPresent(String.self, forKey: .openTarget)
        openTargets = try container.decodeIfPresent([String].self, forKey: .openTargets)
            ?? openTarget.map { [$0] }
            ?? []
    }

    var signature: String {
        "\(buttons.map(String.init).joined(separator: "+"))|\(modifierFlags.rawValue)"
    }

    var isValid: Bool {
        buttons.count == 2
    }

    var actionMapping: ButtonMapping {
        ButtonMapping(
            buttonNumber: buttons.first ?? 2,
            modifierFlags: modifierFlags,
            action: action,
            customShortcut: customShortcut,
            shortcutSequence: shortcutSequence,
            shortcutRepeatEnabled: shortcutRepeatEnabled,
            targetMouseButtonNumber: targetMouseButtonNumber,
            openTarget: openTarget,
            openTargets: openTargets
        )
    }

    static func normalizedButtons(_ buttons: [Int]) -> [Int] {
        Array(Set(buttons.filter { (0...31).contains($0) })).sorted()
    }
}

struct ButtonWheelChordMapping: Codable, Identifiable, Equatable {
    var id: UUID
    var buttonNumber: Int
    var wheelDirection: WheelDirection
    var modifierFlags: MouseModifierFlags
    var action: MouseAction
    var customShortcut: KeyboardShortcutDefinition?
    var shortcutSequence: [ShortcutSequenceStep]?
    var targetMouseButtonNumber: Int?
    var openTarget: String?
    var openTargets: [String]

    init(
        id: UUID = UUID(),
        buttonNumber: Int,
        wheelDirection: WheelDirection,
        modifierFlags: MouseModifierFlags = [],
        action: MouseAction,
        customShortcut: KeyboardShortcutDefinition? = nil,
        shortcutSequence: [ShortcutSequenceStep]? = nil,
        targetMouseButtonNumber: Int? = nil,
        openTarget: String? = nil,
        openTargets: [String]? = nil
    ) {
        self.id = id
        self.buttonNumber = buttonNumber
        self.wheelDirection = wheelDirection
        self.modifierFlags = modifierFlags
        self.action = action
        self.customShortcut = customShortcut
        self.shortcutSequence = shortcutSequence
        self.targetMouseButtonNumber = targetMouseButtonNumber
        self.openTarget = openTarget
        self.openTargets = openTargets ?? openTarget.map { [$0] } ?? []
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        buttonNumber = try container.decode(Int.self, forKey: .buttonNumber)
        wheelDirection = try container.decode(WheelDirection.self, forKey: .wheelDirection)
        modifierFlags = try container.decodeIfPresent(MouseModifierFlags.self, forKey: .modifierFlags) ?? []
        action = try container.decode(MouseAction.self, forKey: .action)
        customShortcut = try container.decodeIfPresent(KeyboardShortcutDefinition.self, forKey: .customShortcut)
        shortcutSequence = try container.decodeIfPresent([ShortcutSequenceStep].self, forKey: .shortcutSequence)
        targetMouseButtonNumber = try container.decodeIfPresent(Int.self, forKey: .targetMouseButtonNumber)
        openTarget = try container.decodeIfPresent(String.self, forKey: .openTarget)
        openTargets = try container.decodeIfPresent([String].self, forKey: .openTargets)
            ?? openTarget.map { [$0] }
            ?? []
    }

    var signature: String {
        "\(buttonNumber)|\(wheelDirection.rawValue)|\(modifierFlags.rawValue)"
    }

    var isValid: Bool {
        (0...31).contains(buttonNumber)
    }

    var actionMapping: ButtonMapping {
        ButtonMapping(
            buttonNumber: buttonNumber,
            modifierFlags: modifierFlags,
            action: action,
            customShortcut: customShortcut,
            shortcutSequence: shortcutSequence,
            targetMouseButtonNumber: targetMouseButtonNumber,
            openTarget: openTarget,
            openTargets: openTargets
        )
    }
}

struct WheelMapping: Codable, Identifiable, Equatable {
    var wheelDirection: WheelDirection
    var modifierFlags: MouseModifierFlags
    var action: MouseAction
    var customShortcut: KeyboardShortcutDefinition?
    var shortcutSequence: [ShortcutSequenceStep]?
    var shortcutOnlyAtScrollStart: Bool

    var id: String {
        "\(wheelDirection.rawValue)|\(modifierFlags.rawValue)"
    }

    init(
        wheelDirection: WheelDirection,
        modifierFlags: MouseModifierFlags = [],
        action: MouseAction,
        customShortcut: KeyboardShortcutDefinition? = nil,
        shortcutSequence: [ShortcutSequenceStep]? = nil,
        shortcutOnlyAtScrollStart: Bool = false
    ) {
        self.wheelDirection = wheelDirection
        self.modifierFlags = modifierFlags
        self.action = action
        self.customShortcut = customShortcut
        self.shortcutSequence = shortcutSequence
        self.shortcutOnlyAtScrollStart = shortcutOnlyAtScrollStart
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wheelDirection = try container.decode(WheelDirection.self, forKey: .wheelDirection)
        modifierFlags = try container.decodeIfPresent(MouseModifierFlags.self, forKey: .modifierFlags) ?? []
        action = try container.decode(MouseAction.self, forKey: .action)
        customShortcut = try container.decodeIfPresent(KeyboardShortcutDefinition.self, forKey: .customShortcut)
        shortcutSequence = try container.decodeIfPresent([ShortcutSequenceStep].self, forKey: .shortcutSequence)
        shortcutOnlyAtScrollStart = try container.decodeIfPresent(
            Bool.self,
            forKey: .shortcutOnlyAtScrollStart
        ) ?? false
    }

    var actionMapping: ButtonMapping {
        ButtonMapping(
            buttonNumber: 0,
            modifierFlags: modifierFlags,
            action: action,
            customShortcut: customShortcut,
            shortcutSequence: shortcutSequence
        )
    }
}

struct WheelRollStreamKey: Hashable {
    let wheelDirection: WheelDirection
    let modifierFlags: MouseModifierFlags
    let deviceIdentifier: String?
}

struct WheelRollTracker {
    static let discreteIdleThreshold: TimeInterval = 0.18

    private var lastEventTimes = [WheelRollStreamKey: TimeInterval]()

    mutating func isBeginning(
        stream: WheelRollStreamKey,
        timestamp: TimeInterval,
        scrollPhase: Int64,
        momentumPhase: Int64
    ) -> Bool {
        let finiteTimestamp = timestamp.isFinite ? timestamp : 0
        let didEnd = (scrollPhase & 0x0C) != 0
        if didEnd {
            lastEventTimes[stream] = nil
            return false
        }

        // Momentum belongs to the direct gesture that preceded it and must not
        // execute a shortcut a second time.
        if momentumPhase != 0 {
            return false
        }

        let previousTimestamp = lastEventTimes[stream]
        lastEventTimes[stream] = finiteTimestamp

        if (scrollPhase & 0x01) != 0 {
            return true
        }
        if (scrollPhase & 0x02) != 0 {
            return previousTimestamp == nil
        }

        guard let previousTimestamp else {
            return true
        }
        return finiteTimestamp - previousTimestamp >= Self.discreteIdleThreshold
    }

    mutating func clear() {
        lastEventTimes.removeAll()
    }
}

struct MouseButtonDefinition: Identifiable, Equatable {
    let buttonNumber: Int
    let name: String
    let isRemappable: Bool

    var id: Int { buttonNumber }

    static let all: [MouseButtonDefinition] = [
        MouseButtonDefinition(buttonNumber: 0, name: "Left Button", isRemappable: true),
        MouseButtonDefinition(buttonNumber: 1, name: "Right Button", isRemappable: true),
        MouseButtonDefinition(buttonNumber: 2, name: "Middle Button", isRemappable: true)
    ] + (3...31).map {
        MouseButtonDefinition(buttonNumber: $0, name: "Button \($0 + 1)", isRemappable: true)
    }

    static let preferredChordButtonNumbers = Array(2...31) + [0, 1]
}

struct ApplicationProfile: Codable, Identifiable, Equatable {
    static let currentConfigurationVersion = 4

    var id: UUID
    var configurationVersion: Int
    var name: String
    var bundleIdentifier: String
    var isEnabled: Bool
    var buttonMappings: [ButtonMapping]
    var buttonChords: [ButtonChordMapping]
    var buttonWheelChords: [ButtonWheelChordMapping]
    var wheelMappings: [WheelMapping]
    var middleClickBehavior: MiddleClickBehavior
    var scrollDirection: ScrollDirection
    var verticalScrollSpeed: Double
    var horizontalScrollSpeed: Double
    var scrollAccelerationEnabled: Bool
    var scrollAcceleration: Double
    var verticalScrollSensitivity: Double
    var horizontalScrollSensitivity: Double
    var smoothScrollingEnabled: Bool
    var cursorControlEnabled: Bool
    var accelerationEnabled: Bool
    var accelerationLevel: Double
    var sensitivityLevel: Double
    var cursorAutoSnapDestination: CursorAutoSnapDestination
    var cursorAutoSnapReturnsToOriginal: Bool
    var cursorAutoSnapMovesInstantly: Bool

    init(
        id: UUID = UUID(),
        configurationVersion: Int = ApplicationProfile.currentConfigurationVersion,
        name: String,
        bundleIdentifier: String,
        isEnabled: Bool = true,
        buttonMappings: [ButtonMapping],
        buttonChords: [ButtonChordMapping] = [],
        buttonWheelChords: [ButtonWheelChordMapping] = [],
        wheelMappings: [WheelMapping] = [],
        middleClickBehavior: MiddleClickBehavior = .defaultClick,
        scrollDirection: ScrollDirection,
        verticalScrollSpeed: Double,
        horizontalScrollSpeed: Double,
        scrollAccelerationEnabled: Bool = true,
        scrollAcceleration: Double = 0.3125,
        verticalScrollSensitivity: Double? = nil,
        horizontalScrollSensitivity: Double? = nil,
        smoothScrollingEnabled: Bool = false,
        cursorControlEnabled: Bool = false,
        accelerationEnabled: Bool = true,
        accelerationLevel: Double = 44,
        sensitivityLevel: Double = 1900,
        cursorAutoSnapDestination: CursorAutoSnapDestination = .none,
        cursorAutoSnapReturnsToOriginal: Bool = false,
        cursorAutoSnapMovesInstantly: Bool = false
    ) {
        self.id = id
        self.configurationVersion = configurationVersion
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.isEnabled = isEnabled
        self.buttonMappings = buttonMappings
        self.buttonChords = buttonChords
        self.buttonWheelChords = buttonWheelChords
        self.wheelMappings = wheelMappings
        self.middleClickBehavior = middleClickBehavior
        self.scrollDirection = scrollDirection
        self.verticalScrollSpeed = verticalScrollSpeed
        self.horizontalScrollSpeed = horizontalScrollSpeed
        self.scrollAccelerationEnabled = scrollAccelerationEnabled
        self.scrollAcceleration = scrollAcceleration
        self.verticalScrollSensitivity = verticalScrollSensitivity
            ?? ScrollSensitivityMapper.factor(forMultiplier: verticalScrollSpeed)
        self.horizontalScrollSensitivity = horizontalScrollSensitivity
            ?? ScrollSensitivityMapper.factor(forMultiplier: horizontalScrollSpeed)
        self.smoothScrollingEnabled = smoothScrollingEnabled
        self.cursorControlEnabled = cursorControlEnabled
        self.accelerationEnabled = accelerationEnabled
        self.accelerationLevel = accelerationLevel
        self.sensitivityLevel = sensitivityLevel
        self.cursorAutoSnapDestination = cursorAutoSnapDestination
        self.cursorAutoSnapReturnsToOriginal = cursorAutoSnapReturnsToOriginal
        self.cursorAutoSnapMovesInstantly = cursorAutoSnapMovesInstantly
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        configurationVersion = try container.decodeIfPresent(Int.self, forKey: .configurationVersion) ?? 0
        name = try container.decode(String.self, forKey: .name)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        buttonMappings = try container.decode([ButtonMapping].self, forKey: .buttonMappings)
        buttonChords = try container.decodeIfPresent([ButtonChordMapping].self, forKey: .buttonChords) ?? []
        buttonWheelChords = try container.decodeIfPresent([ButtonWheelChordMapping].self, forKey: .buttonWheelChords) ?? []
        wheelMappings = try container.decodeIfPresent([WheelMapping].self, forKey: .wheelMappings) ?? []
        middleClickBehavior = try container.decodeIfPresent(MiddleClickBehavior.self, forKey: .middleClickBehavior) ?? .defaultClick
        scrollDirection = try container.decode(ScrollDirection.self, forKey: .scrollDirection)
        verticalScrollSpeed = try container.decode(Double.self, forKey: .verticalScrollSpeed)
        horizontalScrollSpeed = try container.decode(Double.self, forKey: .horizontalScrollSpeed)
        scrollAccelerationEnabled = try container.decodeIfPresent(Bool.self, forKey: .scrollAccelerationEnabled) ?? true
        scrollAcceleration = try container.decodeIfPresent(Double.self, forKey: .scrollAcceleration) ?? 0.3125
        verticalScrollSensitivity = try container.decodeIfPresent(Double.self, forKey: .verticalScrollSensitivity)
            ?? ScrollSensitivityMapper.factor(forMultiplier: verticalScrollSpeed)
        horizontalScrollSensitivity = try container.decodeIfPresent(Double.self, forKey: .horizontalScrollSensitivity)
            ?? ScrollSensitivityMapper.factor(forMultiplier: horizontalScrollSpeed)
        smoothScrollingEnabled = try container.decodeIfPresent(Bool.self, forKey: .smoothScrollingEnabled) ?? false
        cursorControlEnabled = try container.decodeIfPresent(Bool.self, forKey: .cursorControlEnabled) ?? false
        accelerationEnabled = try container.decodeIfPresent(Bool.self, forKey: .accelerationEnabled) ?? true
        accelerationLevel = try container.decodeIfPresent(Double.self, forKey: .accelerationLevel) ?? 44
        sensitivityLevel = try container.decodeIfPresent(Double.self, forKey: .sensitivityLevel) ?? 1900
        cursorAutoSnapDestination = try container.decodeIfPresent(
            CursorAutoSnapDestination.self,
            forKey: .cursorAutoSnapDestination
        ) ?? .none
        cursorAutoSnapReturnsToOriginal = try container.decodeIfPresent(
            Bool.self,
            forKey: .cursorAutoSnapReturnsToOriginal
        ) ?? false
        cursorAutoSnapMovesInstantly = try container.decodeIfPresent(
            Bool.self,
            forKey: .cursorAutoSnapMovesInstantly
        ) ?? false
    }
}

struct MouseDeviceProfile: Codable, Identifiable, Equatable {
    static let currentConfigurationVersion = 4

    var id: UUID
    var configurationVersion: Int
    var name: String
    var deviceIdentifier: String
    var isEnabled: Bool
    var buttonMappings: [ButtonMapping]
    var buttonChords: [ButtonChordMapping]
    var buttonWheelChords: [ButtonWheelChordMapping]
    var wheelMappings: [WheelMapping]
    var middleClickBehavior: MiddleClickBehavior
    var scrollDirection: ScrollDirection
    var verticalScrollSpeed: Double
    var horizontalScrollSpeed: Double
    var scrollAccelerationEnabled: Bool
    var scrollAcceleration: Double
    var verticalScrollSensitivity: Double
    var horizontalScrollSensitivity: Double
    var smoothScrollingEnabled: Bool
    var cursorControlEnabled: Bool
    var accelerationEnabled: Bool
    var accelerationLevel: Double
    var sensitivityLevel: Double
    var cursorAutoSnapDestination: CursorAutoSnapDestination
    var cursorAutoSnapReturnsToOriginal: Bool
    var cursorAutoSnapMovesInstantly: Bool

    init(
        id: UUID = UUID(),
        configurationVersion: Int = MouseDeviceProfile.currentConfigurationVersion,
        name: String,
        deviceIdentifier: String,
        isEnabled: Bool = true,
        buttonMappings: [ButtonMapping],
        buttonChords: [ButtonChordMapping] = [],
        buttonWheelChords: [ButtonWheelChordMapping] = [],
        wheelMappings: [WheelMapping] = [],
        middleClickBehavior: MiddleClickBehavior = .defaultClick,
        scrollDirection: ScrollDirection,
        verticalScrollSpeed: Double,
        horizontalScrollSpeed: Double,
        scrollAccelerationEnabled: Bool = true,
        scrollAcceleration: Double = 0.3125,
        verticalScrollSensitivity: Double? = nil,
        horizontalScrollSensitivity: Double? = nil,
        smoothScrollingEnabled: Bool = false,
        cursorControlEnabled: Bool = false,
        accelerationEnabled: Bool = true,
        accelerationLevel: Double = 44,
        sensitivityLevel: Double = 1900,
        cursorAutoSnapDestination: CursorAutoSnapDestination = .none,
        cursorAutoSnapReturnsToOriginal: Bool = false,
        cursorAutoSnapMovesInstantly: Bool = false
    ) {
        self.id = id
        self.configurationVersion = configurationVersion
        self.name = name
        self.deviceIdentifier = deviceIdentifier
        self.isEnabled = isEnabled
        self.buttonMappings = buttonMappings
        self.buttonChords = buttonChords
        self.buttonWheelChords = buttonWheelChords
        self.wheelMappings = wheelMappings
        self.middleClickBehavior = middleClickBehavior
        self.scrollDirection = scrollDirection
        self.verticalScrollSpeed = verticalScrollSpeed
        self.horizontalScrollSpeed = horizontalScrollSpeed
        self.scrollAccelerationEnabled = scrollAccelerationEnabled
        self.scrollAcceleration = scrollAcceleration
        self.verticalScrollSensitivity = verticalScrollSensitivity
            ?? ScrollSensitivityMapper.factor(forMultiplier: verticalScrollSpeed)
        self.horizontalScrollSensitivity = horizontalScrollSensitivity
            ?? ScrollSensitivityMapper.factor(forMultiplier: horizontalScrollSpeed)
        self.smoothScrollingEnabled = smoothScrollingEnabled
        self.cursorControlEnabled = cursorControlEnabled
        self.accelerationEnabled = accelerationEnabled
        self.accelerationLevel = accelerationLevel
        self.sensitivityLevel = sensitivityLevel
        self.cursorAutoSnapDestination = cursorAutoSnapDestination
        self.cursorAutoSnapReturnsToOriginal = cursorAutoSnapReturnsToOriginal
        self.cursorAutoSnapMovesInstantly = cursorAutoSnapMovesInstantly
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        if let decodedVersion = try container.decodeIfPresent(
            Int.self,
            forKey: .configurationVersion
        ) {
            configurationVersion = decodedVersion
        } else if container.contains(.cursorAutoSnapDestination)
            || container.contains(.cursorAutoSnapReturnsToOriginal)
            || container.contains(.cursorAutoSnapMovesInstantly) {
            configurationVersion = 4
        } else if container.contains(.wheelMappings) {
            configurationVersion = 3
        } else if container.contains(.buttonWheelChords)
            || container.contains(.cursorControlEnabled)
            || container.contains(.scrollAcceleration) {
            configurationVersion = 2
        } else {
            configurationVersion = 1
        }
        name = try container.decode(String.self, forKey: .name)
        deviceIdentifier = try container.decode(String.self, forKey: .deviceIdentifier)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        buttonMappings = try container.decode([ButtonMapping].self, forKey: .buttonMappings)
        buttonChords = try container.decodeIfPresent([ButtonChordMapping].self, forKey: .buttonChords) ?? []
        buttonWheelChords = try container.decodeIfPresent([ButtonWheelChordMapping].self, forKey: .buttonWheelChords) ?? []
        wheelMappings = try container.decodeIfPresent([WheelMapping].self, forKey: .wheelMappings) ?? []
        middleClickBehavior = try container.decodeIfPresent(MiddleClickBehavior.self, forKey: .middleClickBehavior) ?? .defaultClick
        scrollDirection = try container.decode(ScrollDirection.self, forKey: .scrollDirection)
        verticalScrollSpeed = try container.decode(Double.self, forKey: .verticalScrollSpeed)
        horizontalScrollSpeed = try container.decode(Double.self, forKey: .horizontalScrollSpeed)
        scrollAccelerationEnabled = try container.decodeIfPresent(Bool.self, forKey: .scrollAccelerationEnabled) ?? true
        scrollAcceleration = try container.decodeIfPresent(Double.self, forKey: .scrollAcceleration) ?? 0.3125
        verticalScrollSensitivity = try container.decodeIfPresent(Double.self, forKey: .verticalScrollSensitivity)
            ?? ScrollSensitivityMapper.factor(forMultiplier: verticalScrollSpeed)
        horizontalScrollSensitivity = try container.decodeIfPresent(Double.self, forKey: .horizontalScrollSensitivity)
            ?? ScrollSensitivityMapper.factor(forMultiplier: horizontalScrollSpeed)
        smoothScrollingEnabled = try container.decodeIfPresent(Bool.self, forKey: .smoothScrollingEnabled) ?? false
        cursorControlEnabled = try container.decodeIfPresent(Bool.self, forKey: .cursorControlEnabled) ?? false
        accelerationEnabled = try container.decodeIfPresent(Bool.self, forKey: .accelerationEnabled) ?? true
        accelerationLevel = try container.decodeIfPresent(Double.self, forKey: .accelerationLevel) ?? 44
        sensitivityLevel = try container.decodeIfPresent(Double.self, forKey: .sensitivityLevel) ?? 1900
        cursorAutoSnapDestination = try container.decodeIfPresent(
            CursorAutoSnapDestination.self,
            forKey: .cursorAutoSnapDestination
        ) ?? .none
        cursorAutoSnapReturnsToOriginal = try container.decodeIfPresent(
            Bool.self,
            forKey: .cursorAutoSnapReturnsToOriginal
        ) ?? false
        cursorAutoSnapMovesInstantly = try container.decodeIfPresent(
            Bool.self,
            forKey: .cursorAutoSnapMovesInstantly
        ) ?? false
    }

}

@MainActor
protocol ConfigurableMouseProfile {
    var buttonMappings: [ButtonMapping] { get set }
    var buttonChords: [ButtonChordMapping] { get set }
    var buttonWheelChords: [ButtonWheelChordMapping] { get set }
    var wheelMappings: [WheelMapping] { get set }
    var middleClickBehavior: MiddleClickBehavior { get set }
    var scrollDirection: ScrollDirection { get set }
    var verticalScrollSpeed: Double { get set }
    var horizontalScrollSpeed: Double { get set }
    var scrollAccelerationEnabled: Bool { get set }
    var scrollAcceleration: Double { get set }
    var verticalScrollSensitivity: Double { get set }
    var horizontalScrollSensitivity: Double { get set }
    var smoothScrollingEnabled: Bool { get set }
    var cursorControlEnabled: Bool { get set }
    var accelerationEnabled: Bool { get set }
    var accelerationLevel: Double { get set }
    var sensitivityLevel: Double { get set }
    var cursorAutoSnapDestination: CursorAutoSnapDestination { get set }
    var cursorAutoSnapReturnsToOriginal: Bool { get set }
    var cursorAutoSnapMovesInstantly: Bool { get set }
}

@MainActor
extension ApplicationProfile: ConfigurableMouseProfile {}
@MainActor
extension MouseDeviceProfile: ConfigurableMouseProfile {}

struct AppSettings: Codable, Equatable {
    var isEnabled: Bool
    var appTheme: AppTheme
    var selectedTab: AppTab
    var buttonMappings: [ButtonMapping]
    var buttonChords: [ButtonChordMapping]
    var buttonWheelChords: [ButtonWheelChordMapping]
    var wheelMappings: [WheelMapping]
    var applicationProfiles: [ApplicationProfile]
    var deviceProfiles: [MouseDeviceProfile]
    var scrollDirection: ScrollDirection
    var verticalScrollSpeed: Double
    var horizontalScrollSpeed: Double
    var scrollAccelerationEnabled: Bool
    var scrollAcceleration: Double
    var verticalScrollSensitivity: Double
    var horizontalScrollSensitivity: Double
    var smoothScrollingEnabled: Bool
    var middleClickBehavior: MiddleClickBehavior
    var pointerSpeed: Double
    var pointerAccelerationEnabled: Bool
    var preciseModeEnabled: Bool
    var preciseModeSpeed: Double
    var pointerControlEnabled: Bool
    var mouseTrackingSpeed: Double
    var mouseSpeedLevel: Double
    var mouseAccelerationEnabled: Bool
    var cursorControlEnabled: Bool
    var accelerationEnabled: Bool
    var accelerationLevel: Double
    var sensitivityLevel: Double
    var cursorAutoSnapDestination: CursorAutoSnapDestination
    var cursorAutoSnapReturnsToOriginal: Bool
    var cursorAutoSnapMovesInstantly: Bool
    var windowsLikeModeEnabled: Bool

    static let defaultSettings = AppSettings(
        isEnabled: true,
        appTheme: .system,
        selectedTab: .buttons,
        buttonMappings: [
            ButtonMapping(buttonNumber: 0, action: .defaultClick),
            ButtonMapping(buttonNumber: 1, action: .defaultClick),
            ButtonMapping(buttonNumber: 2, action: .defaultClick),
            ButtonMapping(buttonNumber: 3, action: .back),
            ButtonMapping(buttonNumber: 4, action: .forward),
            ButtonMapping(buttonNumber: 5, action: .defaultClick),
            ButtonMapping(buttonNumber: 6, action: .defaultClick),
            ButtonMapping(buttonNumber: 7, action: .defaultClick)
        ],
        buttonChords: [],
        buttonWheelChords: [],
        wheelMappings: [],
        applicationProfiles: [],
        deviceProfiles: [],
        scrollDirection: .natural,
        verticalScrollSpeed: 1.0,
        horizontalScrollSpeed: 1.0,
        scrollAccelerationEnabled: true,
        scrollAcceleration: 0.3125,
        verticalScrollSensitivity: 0,
        horizontalScrollSensitivity: 0,
        smoothScrollingEnabled: false,
        middleClickBehavior: .defaultClick,
        pointerSpeed: 1.0,
        pointerAccelerationEnabled: true,
        preciseModeEnabled: false,
        preciseModeSpeed: 0.5,
        pointerControlEnabled: false,
        mouseTrackingSpeed: 2.0,
        mouseSpeedLevel: MouseCursorMapper.legacyMouseSpeedLevel(
            fromSensitivityLevel: 1900
        ),
        mouseAccelerationEnabled: true,
        cursorControlEnabled: false,
        accelerationEnabled: true,
        accelerationLevel: 44,
        sensitivityLevel: 1900,
        cursorAutoSnapDestination: .none,
        cursorAutoSnapReturnsToOriginal: false,
        cursorAutoSnapMovesInstantly: false,
        windowsLikeModeEnabled: false
    )

    static let `default`: AppSettings = defaultSettings

    init(
        isEnabled: Bool,
        appTheme: AppTheme,
        selectedTab: AppTab,
        buttonMappings: [ButtonMapping],
        buttonChords: [ButtonChordMapping],
        buttonWheelChords: [ButtonWheelChordMapping],
        wheelMappings: [WheelMapping],
        applicationProfiles: [ApplicationProfile],
        deviceProfiles: [MouseDeviceProfile],
        scrollDirection: ScrollDirection,
        verticalScrollSpeed: Double,
        horizontalScrollSpeed: Double,
        scrollAccelerationEnabled: Bool,
        scrollAcceleration: Double,
        verticalScrollSensitivity: Double,
        horizontalScrollSensitivity: Double,
        smoothScrollingEnabled: Bool,
        middleClickBehavior: MiddleClickBehavior,
        pointerSpeed: Double,
        pointerAccelerationEnabled: Bool,
        preciseModeEnabled: Bool,
        preciseModeSpeed: Double,
        pointerControlEnabled: Bool,
        mouseTrackingSpeed: Double,
        mouseSpeedLevel: Double,
        mouseAccelerationEnabled: Bool,
        cursorControlEnabled: Bool,
        accelerationEnabled: Bool,
        accelerationLevel: Double,
        sensitivityLevel: Double,
        cursorAutoSnapDestination: CursorAutoSnapDestination,
        cursorAutoSnapReturnsToOriginal: Bool,
        cursorAutoSnapMovesInstantly: Bool,
        windowsLikeModeEnabled: Bool
    ) {
        self.isEnabled = isEnabled
        self.appTheme = appTheme
        self.selectedTab = selectedTab
        self.buttonMappings = buttonMappings
        self.buttonChords = buttonChords
        self.buttonWheelChords = buttonWheelChords
        self.wheelMappings = wheelMappings
        self.applicationProfiles = applicationProfiles
        self.deviceProfiles = deviceProfiles
        self.scrollDirection = scrollDirection
        self.verticalScrollSpeed = verticalScrollSpeed
        self.horizontalScrollSpeed = horizontalScrollSpeed
        self.scrollAccelerationEnabled = scrollAccelerationEnabled
        self.scrollAcceleration = scrollAcceleration
        self.verticalScrollSensitivity = verticalScrollSensitivity
        self.horizontalScrollSensitivity = horizontalScrollSensitivity
        self.smoothScrollingEnabled = smoothScrollingEnabled
        self.middleClickBehavior = middleClickBehavior
        self.pointerSpeed = pointerSpeed
        self.pointerAccelerationEnabled = pointerAccelerationEnabled
        self.preciseModeEnabled = preciseModeEnabled
        self.preciseModeSpeed = preciseModeSpeed
        self.pointerControlEnabled = pointerControlEnabled
        self.mouseTrackingSpeed = mouseTrackingSpeed
        self.mouseSpeedLevel = mouseSpeedLevel
        self.mouseAccelerationEnabled = mouseAccelerationEnabled
        self.cursorControlEnabled = cursorControlEnabled
        self.accelerationEnabled = accelerationEnabled
        self.accelerationLevel = accelerationLevel
        self.sensitivityLevel = sensitivityLevel
        self.cursorAutoSnapDestination = cursorAutoSnapDestination
        self.cursorAutoSnapReturnsToOriginal = cursorAutoSnapReturnsToOriginal
        self.cursorAutoSnapMovesInstantly = cursorAutoSnapMovesInstantly
        self.windowsLikeModeEnabled = windowsLikeModeEnabled
    }

    init(from decoder: Decoder) throws {
        let defaults = AppSettings.defaultSettings
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? defaults.isEnabled
        appTheme = try container.decodeIfPresent(AppTheme.self, forKey: .appTheme) ?? defaults.appTheme
        selectedTab = try container.decodeIfPresent(AppTab.self, forKey: .selectedTab) ?? defaults.selectedTab
        buttonMappings = try container.decodeIfPresent([ButtonMapping].self, forKey: .buttonMappings) ?? defaults.buttonMappings
        buttonChords = try container.decodeIfPresent([ButtonChordMapping].self, forKey: .buttonChords) ?? defaults.buttonChords
        buttonWheelChords = try container.decodeIfPresent([ButtonWheelChordMapping].self, forKey: .buttonWheelChords) ?? defaults.buttonWheelChords
        wheelMappings = try container.decodeIfPresent([WheelMapping].self, forKey: .wheelMappings) ?? defaults.wheelMappings
        applicationProfiles = try container.decodeIfPresent([ApplicationProfile].self, forKey: .applicationProfiles) ?? defaults.applicationProfiles
        deviceProfiles = try container.decodeIfPresent([MouseDeviceProfile].self, forKey: .deviceProfiles) ?? defaults.deviceProfiles
        scrollDirection = try container.decodeIfPresent(ScrollDirection.self, forKey: .scrollDirection) ?? defaults.scrollDirection
        verticalScrollSpeed = try container.decodeIfPresent(Double.self, forKey: .verticalScrollSpeed) ?? defaults.verticalScrollSpeed
        horizontalScrollSpeed = try container.decodeIfPresent(Double.self, forKey: .horizontalScrollSpeed) ?? defaults.horizontalScrollSpeed
        scrollAccelerationEnabled = try container.decodeIfPresent(Bool.self, forKey: .scrollAccelerationEnabled) ?? defaults.scrollAccelerationEnabled
        scrollAcceleration = try container.decodeIfPresent(Double.self, forKey: .scrollAcceleration) ?? defaults.scrollAcceleration
        verticalScrollSensitivity = try container.decodeIfPresent(Double.self, forKey: .verticalScrollSensitivity)
            ?? ScrollSensitivityMapper.factor(forMultiplier: verticalScrollSpeed)
        horizontalScrollSensitivity = try container.decodeIfPresent(Double.self, forKey: .horizontalScrollSensitivity)
            ?? ScrollSensitivityMapper.factor(forMultiplier: horizontalScrollSpeed)
        smoothScrollingEnabled = try container.decodeIfPresent(Bool.self, forKey: .smoothScrollingEnabled) ?? defaults.smoothScrollingEnabled
        middleClickBehavior = try container.decodeIfPresent(MiddleClickBehavior.self, forKey: .middleClickBehavior) ?? defaults.middleClickBehavior
        pointerSpeed = try container.decodeIfPresent(Double.self, forKey: .pointerSpeed) ?? defaults.pointerSpeed
        pointerAccelerationEnabled = try container.decodeIfPresent(Bool.self, forKey: .pointerAccelerationEnabled) ?? defaults.pointerAccelerationEnabled
        preciseModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .preciseModeEnabled) ?? defaults.preciseModeEnabled
        preciseModeSpeed = try container.decodeIfPresent(Double.self, forKey: .preciseModeSpeed) ?? defaults.preciseModeSpeed
        pointerControlEnabled = try container.decodeIfPresent(Bool.self, forKey: .pointerControlEnabled) ?? defaults.pointerControlEnabled
        mouseTrackingSpeed = try container.decodeIfPresent(Double.self, forKey: .mouseTrackingSpeed) ?? defaults.mouseTrackingSpeed
        mouseSpeedLevel = try container.decodeIfPresent(Double.self, forKey: .mouseSpeedLevel) ?? defaults.mouseSpeedLevel
        mouseAccelerationEnabled = try container.decodeIfPresent(Bool.self, forKey: .mouseAccelerationEnabled) ?? defaults.mouseAccelerationEnabled
        cursorControlEnabled = try container.decodeIfPresent(Bool.self, forKey: .cursorControlEnabled)
            ?? (container.contains(.pointerControlEnabled)
                ? pointerControlEnabled
                : defaults.cursorControlEnabled)
        accelerationEnabled = try container.decodeIfPresent(Bool.self, forKey: .accelerationEnabled)
            ?? (container.contains(.mouseAccelerationEnabled)
                ? mouseAccelerationEnabled
                : defaults.accelerationEnabled)
        accelerationLevel = try container.decodeIfPresent(Double.self, forKey: .accelerationLevel) ?? defaults.accelerationLevel
        sensitivityLevel = try container.decodeIfPresent(Double.self, forKey: .sensitivityLevel)
            ?? (container.contains(.mouseSpeedLevel)
                ? MouseCursorMapper.sensitivityLevel(
                    fromLegacyMouseSpeedLevel: mouseSpeedLevel
                )
                : defaults.sensitivityLevel)
        cursorAutoSnapDestination = try container.decodeIfPresent(
            CursorAutoSnapDestination.self,
            forKey: .cursorAutoSnapDestination
        ) ?? defaults.cursorAutoSnapDestination
        cursorAutoSnapReturnsToOriginal = try container.decodeIfPresent(
            Bool.self,
            forKey: .cursorAutoSnapReturnsToOriginal
        ) ?? defaults.cursorAutoSnapReturnsToOriginal
        cursorAutoSnapMovesInstantly = try container.decodeIfPresent(
            Bool.self,
            forKey: .cursorAutoSnapMovesInstantly
        ) ?? defaults.cursorAutoSnapMovesInstantly
        windowsLikeModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .windowsLikeModeEnabled) ?? defaults.windowsLikeModeEnabled

        applicationProfiles = applicationProfiles.map { profile in
            guard profile.configurationVersion < ApplicationProfile.currentConfigurationVersion else {
                return profile
            }

            var migrated = profile
            if profile.configurationVersion < 2 {
                migrated.buttonWheelChords = buttonWheelChords
                migrated.middleClickBehavior = middleClickBehavior
                migrated.scrollAccelerationEnabled = scrollAccelerationEnabled
                migrated.scrollAcceleration = scrollAcceleration
                migrated.smoothScrollingEnabled = smoothScrollingEnabled
                migrated.cursorControlEnabled = cursorControlEnabled
                migrated.accelerationEnabled = accelerationEnabled
                migrated.accelerationLevel = accelerationLevel
                migrated.sensitivityLevel = sensitivityLevel
            }
            if profile.configurationVersion < 3 {
                migrated.wheelMappings = wheelMappings
            }
            if profile.configurationVersion < 4 {
                migrated.cursorAutoSnapDestination = cursorAutoSnapDestination
                migrated.cursorAutoSnapReturnsToOriginal = cursorAutoSnapReturnsToOriginal
                migrated.cursorAutoSnapMovesInstantly = cursorAutoSnapMovesInstantly
            }
            migrated.configurationVersion = ApplicationProfile.currentConfigurationVersion
            return migrated
        }

        deviceProfiles = deviceProfiles.map { profile in
            guard profile.configurationVersion < MouseDeviceProfile.currentConfigurationVersion else {
                return profile
            }

            var migrated = profile
            if profile.configurationVersion < 2 {
                migrated.buttonWheelChords = buttonWheelChords
                migrated.middleClickBehavior = middleClickBehavior
                migrated.scrollAccelerationEnabled = scrollAccelerationEnabled
                migrated.scrollAcceleration = scrollAcceleration
                migrated.smoothScrollingEnabled = smoothScrollingEnabled
                migrated.cursorControlEnabled = cursorControlEnabled
                migrated.accelerationEnabled = accelerationEnabled
                migrated.accelerationLevel = accelerationLevel
                migrated.sensitivityLevel = sensitivityLevel
            }
            if profile.configurationVersion < 3 {
                migrated.wheelMappings = wheelMappings
            }
            if profile.configurationVersion < 4 {
                migrated.cursorAutoSnapDestination = cursorAutoSnapDestination
                migrated.cursorAutoSnapReturnsToOriginal = cursorAutoSnapReturnsToOriginal
                migrated.cursorAutoSnapMovesInstantly = cursorAutoSnapMovesInstantly
            }
            migrated.configurationVersion = MouseDeviceProfile.currentConfigurationVersion
            return migrated
        }
    }

    func actionForButton(_ buttonNumber: Int) -> MouseAction {
        mapping(for: buttonNumber).action
    }

    func mapping(for buttonNumber: Int, modifierFlags: MouseModifierFlags = []) -> ButtonMapping {
        if let mapping = buttonMappings.first(where: { $0.buttonNumber == buttonNumber && $0.modifierFlags == modifierFlags }) {
            if buttonNumber == 2, mapping.action == .defaultClick {
                return ButtonMapping(buttonNumber: buttonNumber, modifierFlags: modifierFlags, action: middleClickBehavior.action)
            }

            return mapping
        }

        if !modifierFlags.isEmpty {
            var inherited = mapping(for: buttonNumber)
            inherited.modifierFlags = modifierFlags
            return inherited
        }

        if buttonNumber == 2, modifierFlags.isEmpty {
            return ButtonMapping(buttonNumber: buttonNumber, modifierFlags: modifierFlags, action: middleClickBehavior.action)
        }

        return ButtonMapping(buttonNumber: buttonNumber, modifierFlags: modifierFlags, action: .defaultClick)
    }

    func resolvedMapping(for buttonNumber: Int, modifierFlags: MouseModifierFlags = []) -> ButtonMapping {
        if buttonMappings.contains(where: { $0.buttonNumber == buttonNumber && $0.modifierFlags == modifierFlags }) {
            return mapping(for: buttonNumber, modifierFlags: modifierFlags)
        }

        if !modifierFlags.isEmpty {
            return mapping(for: buttonNumber)
        }

        return mapping(for: buttonNumber, modifierFlags: modifierFlags)
    }

    func hasChordCandidate(containing buttonNumber: Int, modifierFlags: MouseModifierFlags) -> Bool {
        buttonChords.contains { chord in
            chord.isValid
                && chord.buttons.contains(buttonNumber)
                && (chord.modifierFlags == modifierFlags || (!modifierFlags.isEmpty && chord.modifierFlags.isEmpty))
        }
    }

    func hasButtonWheelChordCandidate(containing buttonNumber: Int, modifierFlags: MouseModifierFlags) -> Bool {
        buttonWheelChords.contains { chord in
            chord.isValid
                && chord.buttonNumber == buttonNumber
                && (chord.modifierFlags == modifierFlags || (!modifierFlags.isEmpty && chord.modifierFlags.isEmpty))
        }
    }

    func resolvedChord(for pressedButtons: Set<Int>, modifierFlags: MouseModifierFlags) -> ButtonChordMapping? {
        let candidates = buttonChords
            .filter { chord in
                chord.isValid && Set(chord.buttons).isSubset(of: pressedButtons)
            }
            .sorted { left, right in
                if left.buttons.count != right.buttons.count {
                    return left.buttons.count > right.buttons.count
                }

                return left.signature < right.signature
            }

        if let exact = candidates.first(where: { $0.modifierFlags == modifierFlags }) {
            return exact
        }

        guard !modifierFlags.isEmpty else {
            return nil
        }

        return candidates.first(where: { $0.modifierFlags.isEmpty })
    }

    func resolvedButtonWheelChord(
        for pressedButtons: Set<Int>,
        wheelDirection: WheelDirection,
        modifierFlags: MouseModifierFlags
    ) -> ButtonWheelChordMapping? {
        let candidates = buttonWheelChords
            .filter {
                $0.isValid
                    && pressedButtons.contains($0.buttonNumber)
                    && $0.wheelDirection == wheelDirection
            }
            .sorted { $0.signature < $1.signature }

        if let exact = candidates.first(where: { $0.modifierFlags == modifierFlags }) {
            return exact
        }

        guard !modifierFlags.isEmpty else {
            return nil
        }

        return candidates.first(where: { $0.modifierFlags.isEmpty })
    }

    func resolvedWheelMapping(
        for wheelDirection: WheelDirection,
        modifierFlags: MouseModifierFlags
    ) -> WheelMapping? {
        if let exact = wheelMappings.first(where: {
            $0.wheelDirection == wheelDirection
                && $0.modifierFlags == modifierFlags
        }) {
            return exact
        }

        guard !modifierFlags.isEmpty else {
            return nil
        }

        return wheelMappings.first(where: {
            $0.wheelDirection == wheelDirection
                && $0.modifierFlags.isEmpty
        })
    }

    func effectiveSettings(
        for bundleIdentifier: String?,
        deviceIdentifier: String? = nil
    ) -> AppSettings {
        var result = self

        if let deviceIdentifier,
           let profile = deviceProfiles.first(where: {
               $0.isEnabled && $0.deviceIdentifier == deviceIdentifier
           }) {
            result.buttonMappings = profile.buttonMappings
            result.buttonChords = profile.buttonChords
            result.buttonWheelChords = profile.buttonWheelChords
            result.wheelMappings = profile.wheelMappings
            result.middleClickBehavior = profile.middleClickBehavior
            result.scrollDirection = profile.scrollDirection
            result.verticalScrollSpeed = profile.verticalScrollSpeed
            result.horizontalScrollSpeed = profile.horizontalScrollSpeed
            result.scrollAccelerationEnabled = profile.scrollAccelerationEnabled
            result.scrollAcceleration = profile.scrollAcceleration
            result.verticalScrollSensitivity = profile.verticalScrollSensitivity
            result.horizontalScrollSensitivity = profile.horizontalScrollSensitivity
            result.smoothScrollingEnabled = profile.smoothScrollingEnabled
            result.cursorControlEnabled = profile.cursorControlEnabled
            result.pointerControlEnabled = profile.cursorControlEnabled
            result.accelerationEnabled = profile.accelerationEnabled
            result.mouseAccelerationEnabled = profile.accelerationEnabled
            result.accelerationLevel = profile.accelerationLevel
            result.sensitivityLevel = profile.sensitivityLevel
            result.cursorAutoSnapDestination = profile.cursorAutoSnapDestination
            result.cursorAutoSnapReturnsToOriginal = profile.cursorAutoSnapReturnsToOriginal
            result.cursorAutoSnapMovesInstantly = profile.cursorAutoSnapMovesInstantly
        }

        if let bundleIdentifier,
           let profile = applicationProfiles.first(where: {
               $0.isEnabled && $0.bundleIdentifier.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
           }) {
            result.buttonMappings = profile.buttonMappings
            result.buttonChords = profile.buttonChords
            result.buttonWheelChords = profile.buttonWheelChords
            result.wheelMappings = profile.wheelMappings
            result.middleClickBehavior = profile.middleClickBehavior
            result.scrollDirection = profile.scrollDirection
            result.verticalScrollSpeed = profile.verticalScrollSpeed
            result.horizontalScrollSpeed = profile.horizontalScrollSpeed
            result.scrollAccelerationEnabled = profile.scrollAccelerationEnabled
            result.scrollAcceleration = profile.scrollAcceleration
            result.verticalScrollSensitivity = profile.verticalScrollSensitivity
            result.horizontalScrollSensitivity = profile.horizontalScrollSensitivity
            result.smoothScrollingEnabled = profile.smoothScrollingEnabled
            result.cursorControlEnabled = profile.cursorControlEnabled
            result.pointerControlEnabled = profile.cursorControlEnabled
            result.accelerationEnabled = profile.accelerationEnabled
            result.mouseAccelerationEnabled = profile.accelerationEnabled
            result.accelerationLevel = profile.accelerationLevel
            result.sensitivityLevel = profile.sensitivityLevel
            result.cursorAutoSnapDestination = profile.cursorAutoSnapDestination
            result.cursorAutoSnapReturnsToOriginal = profile.cursorAutoSnapReturnsToOriginal
            result.cursorAutoSnapMovesInstantly = profile.cursorAutoSnapMovesInstantly
        }

        return result
    }

    func actionForButton(_ buttonNumber: Int, modifierFlags: MouseModifierFlags) -> MouseAction {
        if buttonNumber == 2 {
            let mappedAction = mapping(for: buttonNumber, modifierFlags: modifierFlags).action
            return mappedAction == .defaultClick ? middleClickBehavior.action : mappedAction
        }

        return mapping(for: buttonNumber, modifierFlags: modifierFlags).action
    }

    func action(for buttonNumber: Int) -> MouseAction {
        actionForButton(buttonNumber)
    }

    mutating func setAction(_ action: MouseAction, for buttonNumber: Int, modifierFlags: MouseModifierFlags = []) {
        guard let index = buttonMappings.firstIndex(where: { $0.buttonNumber == buttonNumber && $0.modifierFlags == modifierFlags }) else {
            buttonMappings.append(ButtonMapping(buttonNumber: buttonNumber, modifierFlags: modifierFlags, action: action))
            buttonMappings.sort { $0.buttonNumber < $1.buttonNumber }
            return
        }

        buttonMappings[index].action = action
    }

    mutating func setMapping(_ mapping: ButtonMapping) {
        guard let index = buttonMappings.firstIndex(where: { $0.buttonNumber == mapping.buttonNumber && $0.modifierFlags == mapping.modifierFlags }) else {
            buttonMappings.append(mapping)
            buttonMappings.sort {
                if $0.buttonNumber == $1.buttonNumber {
                    return $0.modifierFlags.rawValue < $1.modifierFlags.rawValue
                }

                return $0.buttonNumber < $1.buttonNumber
            }
            return
        }

        buttonMappings[index] = mapping
    }
}
