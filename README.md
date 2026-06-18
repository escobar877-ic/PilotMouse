# MousePilot

MousePilot is a local macOS mouse customization utility built with SwiftUI, AppKit, CoreGraphics, ApplicationServices, and IOKit.

## Features

- Compact menu bar app
- Extra mouse button remapping
- Back / Forward actions
- Mission Control and Show Desktop
- App Switcher, tab, window, copy, and paste actions
- Mouse wheel direction and speed settings
- Mouse-only pointer speed control
- Windows-like pointer preset
- System / Light / Dark appearance
- Local settings persistence
- No accounts
- No subscription
- No telemetry

## Requirements

- macOS
- Xcode
- Accessibility permission
- Input Monitoring permission

## Build

1. Open the project in Xcode.
2. Select the MousePilot target and My Mac run destination.
3. For local development, disable App Sandbox if it is enabled.
4. Build and run.
5. Open MousePilot from its menu bar icon.

The settings window opens at `860x640` and cannot be resized below `780x560`.

## Permissions

MousePilot uses macOS permissions only for its local mouse functionality:

- Accessibility: posts configured keyboard shortcut actions.
- Input Monitoring: listens for extra mouse button events.

Open System Settings -> Privacy & Security and enable MousePilot under Accessibility and Input Monitoring. Quit and relaunch MousePilot if macOS does not refresh permission status immediately.

## Pointer Control

Pointer speed uses the IOHIDSystem mouse setting identified by `kIOHIDMouseAccelerationType`.

- The user-facing slider is `0...100`.
- It maps through a smooth curve to HID values from `0.35` to `2.80`.
- Changes apply with a short debounce.
- Sticky reapply handles macOS or another utility overwriting the value.
- Trackpad acceleration settings are never modified.
- `mouseMoved` events and mouse delta fields are not intercepted or rewritten.

Other mouse utilities may override the pointer value. Close them when testing MousePilot pointer control.

## Menu Bar

- Left click opens MousePilot.
- Right click or Control-click opens the menu.
- Start / Stop enables or disables event handling.
- The status item uses a monochrome template SF Symbol and contains no text.

## Privacy

MousePilot is local only:

- No analytics
- No telemetry
- No network requests
- No account
- No keylogging
- No click history
- Settings stored locally in UserDefaults

See [PRIVACY.md](PRIVACY.md) for details.

## Known Limitations

- Trackpad settings are not modified.
- Pointer control depends on the macOS IOHIDSystem mouse setting.
- Other mouse utilities may override pointer speed.
- Launchpad, custom shortcuts, and application launching are not exposed as stable actions yet.

## License

MousePilot is available under the MIT License. See [LICENSE](LICENSE).
