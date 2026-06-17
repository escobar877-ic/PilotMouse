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

    static let defaultSettings = AppSettings(
        isEnabled: true,
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
        preciseModeSpeed: 0.5
    )

    func action(for buttonNumber: Int) -> MouseAction {
        if buttonNumber == 2 {
            let mappedAction = buttonMappings.first { $0.buttonNumber == buttonNumber }?.action ?? .defaultClick
            return mappedAction == .defaultClick ? middleClickBehavior.action : mappedAction
        }

        return buttonMappings.first { $0.buttonNumber == buttonNumber }?.action ?? .defaultClick
    }
}
