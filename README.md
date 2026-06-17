# MousePilot

MousePilot is a local macOS mouse customization utility.

## Features

- Menu bar app
- Extra mouse button remapping
- Back / Forward actions
- Mission Control
- Show Desktop
- App Switcher
- Close Window / New Tab / Close Tab
- Copy / Paste
- Basic wheel settings
- Basic pointer settings UI
- Local settings storage
- No accounts
- No subscription
- No telemetry

## Requirements

- macOS
- Xcode
- Accessibility permission

## How to Build

1. Open the project in Xcode.
2. Select the `MyApp` scheme and `My Mac` run destination.
3. Disable App Sandbox for local development if Xcode re-enables it.
4. Build and run.
5. Click the MousePilot icon in the macOS menu bar.

MousePilot is configured as an accessory menu bar app, so it should not appear in the Dock.

## Accessibility Permission

MousePilot needs Accessibility permission to listen for extra mouse buttons and trigger selected actions.

Open:

System Settings -> Privacy & Security -> Accessibility

Enable MousePilot, then return to the app and refresh the permission status.

## Current Status

Working:

- Menu bar app
- Menu with Open MousePilot, Start / Stop, and Quit
- Settings window
- Button mappings
- UserDefaults settings
- Accessibility status
- CGEventTap for extra mouse buttons
- Basic scroll direction and speed event edits

Experimental:

- Scroll speed behavior across different mouse hardware
- Pointer speed event delta editing
- Precise mode behavior

TODO:

- Custom keyboard shortcuts
- Open application action
- Launchpad action
- More stable pointer handling after device testing
- Better custom app icon

## Privacy

MousePilot stores settings locally in UserDefaults. It does not create accounts, use subscriptions, send telemetry, sync data to the cloud, log keyboard input, or save click history.
