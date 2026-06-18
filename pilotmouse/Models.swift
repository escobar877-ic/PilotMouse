import Foundation

enum MouseAction: String, Codable, CaseIterable, Identifiable {
    case disabled
    case defaultClick
    case back
    case forward
    case missionControl
    case showDesktop
    case launchpad
    case appSwitcher
    case closeWindow
    case newTab
    case closeTab
    case copy
    case paste
    case customShortcut
    case openApplication

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .disabled: "Disabled"
        case .defaultClick: "Default Click"
        case .back: "Back"
        case .forward: "Forward"
        case .missionControl: "Mission Control"
        case .showDesktop: "Show Desktop"
        case .launchpad: "Launchpad"
        case .appSwitcher: "App Switcher"
        case .closeWindow: "Close Window"
        case .newTab: "New Tab"
        case .closeTab: "Close Tab"
        case .copy: "Copy"
        case .paste: "Paste"
        case .customShortcut: "Custom Keyboard Shortcut"
        case .openApplication: "Open Application"
        }
    }

    var isImplemented: Bool {
        switch self {
        case .disabled, .defaultClick, .back, .forward, .missionControl, .showDesktop, .appSwitcher, .closeWindow, .newTab, .closeTab, .copy, .paste:
            true
        case .launchpad, .customShortcut, .openApplication:
            false
        }
    }

    static let stableActions: [MouseAction] = allCases.filter(\.isImplemented)
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
    case permissions
    case about

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .buttons: "Buttons"
        case .wheel: "Wheel"
        case .pointer: "Pointer"
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

    static let stableBehaviors: [MiddleClickBehavior] = [.defaultClick, .missionControl, .appSwitcher]
}

struct ButtonMapping: Codable, Identifiable, Equatable {
    var buttonNumber: Int
    var action: MouseAction

    var id: Int { buttonNumber }
}

struct MouseButtonDefinition: Identifiable, Equatable {
    let buttonNumber: Int
    let name: String
    let isRemappable: Bool

    var id: Int { buttonNumber }

    static let all: [MouseButtonDefinition] = [
        MouseButtonDefinition(buttonNumber: 0, name: "Left Button", isRemappable: false),
        MouseButtonDefinition(buttonNumber: 1, name: "Right Button", isRemappable: false),
        MouseButtonDefinition(buttonNumber: 2, name: "Middle Button", isRemappable: true),
        MouseButtonDefinition(buttonNumber: 3, name: "Button 4", isRemappable: true),
        MouseButtonDefinition(buttonNumber: 4, name: "Button 5", isRemappable: true),
        MouseButtonDefinition(buttonNumber: 5, name: "Button 6", isRemappable: true),
        MouseButtonDefinition(buttonNumber: 6, name: "Button 7", isRemappable: true),
        MouseButtonDefinition(buttonNumber: 7, name: "Button 8", isRemappable: true)
    ]
}

struct AppSettings: Codable, Equatable {
    var isEnabled: Bool
    var appTheme: AppTheme
    var selectedTab: AppTab
    var buttonMappings: [ButtonMapping]
    var scrollDirection: ScrollDirection
    var verticalScrollSpeed: Double
    var horizontalScrollSpeed: Double
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
    var windowsLikeModeEnabled: Bool

    static let defaultSettings = AppSettings(
        isEnabled: true,
        appTheme: .system,
        selectedTab: .buttons,
        buttonMappings: [
            ButtonMapping(buttonNumber: 2, action: .defaultClick),
            ButtonMapping(buttonNumber: 3, action: .back),
            ButtonMapping(buttonNumber: 4, action: .forward),
            ButtonMapping(buttonNumber: 5, action: .defaultClick),
            ButtonMapping(buttonNumber: 6, action: .defaultClick),
            ButtonMapping(buttonNumber: 7, action: .defaultClick)
        ],
        scrollDirection: .natural,
        verticalScrollSpeed: 1.0,
        horizontalScrollSpeed: 1.0,
        smoothScrollingEnabled: false,
        middleClickBehavior: .defaultClick,
        pointerSpeed: 1.0,
        pointerAccelerationEnabled: true,
        preciseModeEnabled: false,
        preciseModeSpeed: 0.5,
        pointerControlEnabled: false,
        mouseTrackingSpeed: 2.0,
        mouseSpeedLevel: 50,
        mouseAccelerationEnabled: true,
        windowsLikeModeEnabled: false
    )

    static let `default`: AppSettings = defaultSettings

    init(
        isEnabled: Bool,
        appTheme: AppTheme,
        selectedTab: AppTab,
        buttonMappings: [ButtonMapping],
        scrollDirection: ScrollDirection,
        verticalScrollSpeed: Double,
        horizontalScrollSpeed: Double,
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
        windowsLikeModeEnabled: Bool
    ) {
        self.isEnabled = isEnabled
        self.appTheme = appTheme
        self.selectedTab = selectedTab
        self.buttonMappings = buttonMappings
        self.scrollDirection = scrollDirection
        self.verticalScrollSpeed = verticalScrollSpeed
        self.horizontalScrollSpeed = horizontalScrollSpeed
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
        self.windowsLikeModeEnabled = windowsLikeModeEnabled
    }

    init(from decoder: Decoder) throws {
        let defaults = AppSettings.defaultSettings
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? defaults.isEnabled
        appTheme = try container.decodeIfPresent(AppTheme.self, forKey: .appTheme) ?? defaults.appTheme
        selectedTab = try container.decodeIfPresent(AppTab.self, forKey: .selectedTab) ?? defaults.selectedTab
        buttonMappings = try container.decodeIfPresent([ButtonMapping].self, forKey: .buttonMappings) ?? defaults.buttonMappings
        scrollDirection = try container.decodeIfPresent(ScrollDirection.self, forKey: .scrollDirection) ?? defaults.scrollDirection
        verticalScrollSpeed = try container.decodeIfPresent(Double.self, forKey: .verticalScrollSpeed) ?? defaults.verticalScrollSpeed
        horizontalScrollSpeed = try container.decodeIfPresent(Double.self, forKey: .horizontalScrollSpeed) ?? defaults.horizontalScrollSpeed
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
        windowsLikeModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .windowsLikeModeEnabled) ?? defaults.windowsLikeModeEnabled
    }

    func actionForButton(_ buttonNumber: Int) -> MouseAction {
        if buttonNumber == 2 {
            let mappedAction = buttonMappings.first { $0.buttonNumber == buttonNumber }?.action ?? .defaultClick
            return mappedAction == .defaultClick ? middleClickBehavior.action : mappedAction
        }

        return buttonMappings.first { $0.buttonNumber == buttonNumber }?.action ?? .defaultClick
    }

    func action(for buttonNumber: Int) -> MouseAction {
        actionForButton(buttonNumber)
    }

    mutating func setAction(_ action: MouseAction, for buttonNumber: Int) {
        guard let index = buttonMappings.firstIndex(where: { $0.buttonNumber == buttonNumber }) else {
            buttonMappings.append(ButtonMapping(buttonNumber: buttonNumber, action: action))
            buttonMappings.sort { $0.buttonNumber < $1.buttonNumber }
            return
        }

        buttonMappings[index].action = action
    }
}
