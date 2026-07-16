# MousePilot

MousePilot is a local macOS mouse-customization utility built with SwiftUI, AppKit, CoreGraphics, ApplicationServices, and IOKit.

## Features

- Menu bar Start/Stop control and a single-instance settings app
- Mouse buttons 1-32, all 16 modifier combinations, two-button chords, and button-plus-wheel chords
- Click, navigation, Mission Control, Spaces, app/window/tab, media, shortcut, sequence, file/app/URL, and cursor-snap actions
- Vertical and horizontal wheel sensitivity, direction, native acceleration, continuous-event control, and Auto Scroll
- Independent mouse acceleration `0...99` and sensitivity `5...1990`
- Application profiles and stable mouse profiles with application > device > global priority
- Versioned JSON settings import/export and legacy-settings migration
- System, Light, and Dark appearance
- Local UserDefaults storage with no account, subscription, telemetry, or cloud service

## Requirements

- macOS 14 or later
- Accessibility permission
- Input Monitoring / direct HID listen permission
- Event-posting access for configured keyboard, mouse, scroll, and media actions

Magic Mouse, Magic Trackpad, and internal trackpads are deliberately excluded from mouse HID changes.

## Build

```sh
xcodebuild -project pilotmouse.xcodeproj -scheme MyApp -configuration Debug build
```

For a universal unsigned release artifact:

```sh
xcodebuild -project pilotmouse.xcodeproj -scheme MyApp -configuration Release \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
```

The app is not sandboxed because active event suppression and mouse HID service properties are incompatible with the Mac App Store sandbox model.

## Permissions

Grant the exact installed `MousePilot.app` under System Settings > Privacy & Security > Accessibility and Input Monitoring, then relaunch it. The Permissions tab reports Accessibility, Core Graphics, direct HID, and posting status separately.

Ad-hoc builds do not have a stable signing identity. macOS may require a rebuilt binary to be removed and re-added to Privacy & Security. A Developer ID signature and notarization are required for stable distribution identity.

## Cursor Control

- Acceleration maps the SteerMouse `0...99` scale to `5 * (level / 99)^2`.
- Sensitivity maps `5...1990` to `HIDPointerResolution = 2000 - sensitivity`; larger UI values are faster.
- Writes are per external mouse HID service and are read back before success is reported.
- A sensitivity change rewrites acceleration only when required to activate an accepted resolution change.
- Partial failures roll back to the values immediately preceding that transaction.
- Original system values are restored on disable and supported shutdown paths.
- Known competing mouse utilities pause native writes. Repeated unknown resets stop after three retries to prevent periodic speed pulses.

## Profiles

Application profiles override device profiles, and device profiles override global settings. Device identity uses the serial number when available; otherwise it uses `VID:PID:transport`, so moving a receiver to another USB port does not lose its profile. Two identical serial-less mice intentionally share one model-level profile.

## Scope

MousePilot covers the main daily-use SteerMouse workflows, including held shortcut repetition, multi-target Open actions, automatic cursor snapping, and launch at login. It is not a binary-identical replacement: vendor-specific free-spin/ratchet modes, hardware sensor DPI, raw-only controls, and SteerMouse's cursor animation/return modes require device- or vendor-specific support and are not implemented. See [STEERMOUSE_PARITY.md](STEERMOUSE_PARITY.md) for the audited matrix and current verification state.

## Privacy

MousePilot has no analytics, telemetry, account, cloud sync, or background network client. A user-configured Open URL action delegates that URL to macOS. See [PRIVACY.md](PRIVACY.md).

## License

MousePilot is available under the MIT License. See [LICENSE](LICENSE).
