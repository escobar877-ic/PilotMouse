# Changelog

## 1.3.1 - 2026-07-24

- Fixed cursor and native wheel settings not applying on current macOS releases.
- Replaced the restricted HID simple client with the full event-system client used by established mouse utilities.
- Verified cursor and native wheel changes against live macOS HID filters on a physical USB mouse.

## 1.3.0 - 2026-07-16

- Fixed stale delayed HID writes so an earlier sensitivity or acceleration change can no longer overwrite the latest setting.
- Fixed button chord timing: quick releases execute once, held shortcuts repeat correctly, and App Switcher remains active only for the physical hold.
- Made every wheel step in a held button-plus-wheel chord execute without replaying the original button click.
- Added SteerMouse-style held repetition for shortcuts and ordered shortcut sequences.
- Added multi-target application, file, and URL actions with up to 32 ordered targets.
- Added cancel, minimize, fullscreen, and Dock cursor-snap actions plus per-application and per-device automatic snapping.
- Added middle, triple, and explicit mouse-button 4-32 click actions.
- Added launch-at-login registration and a direct Login Items action when another mouse utility blocks cursor control.
- Migrated older device profiles to inherit new global wheel and auto-snap settings without resetting existing custom profiles.
- Made HID callbacks and shutdown paths pass strict Swift 5 and Swift 6 concurrency checks.

## 1.2.0 - 2026-07-16

- Added stable application and mouse profiles with application > device > global priority.
- Added two-button chords, button-plus-wheel chords, all 16 modifier combinations, ordered shortcut sequences, and key-plus-click actions.
- Added native wheel acceleration/sensitivity, separate vertical/horizontal event scaling, Auto Scroll, and trackpad-safe raw HID attribution.
- Reworked cursor sensitivity writes as readback-verified transactions that roll back to the immediately preceding state on partial failure.
- Stopped repeated rejected HID writes and capped repeated external resets to prevent periodic cursor-speed pulses.
- Added hot-plug, wake, permission-refresh, single-instance, and held-input cleanup paths.
- Made serial-less mouse identity stable across USB ports and device display-name changes, with migration from legacy IDs.
- Added settings validation for non-finite numbers, invalid buttons/modifiers, duplicate profile/chord IDs, and malformed sequences.
- Added versioned settings import/export and automatic migration of legacy cursor and scroll fields.
- Fixed multi-display screen-center snapping, modifier mapping display, Wheel-tab clipping, and hidden wheel-driver diagnostics.
- Excluded built-in and virtual HID pointers, guarded fixed-point restoration from overflow, and made IOHID shutdown actor-safe.
- Exposed the complete wheel sensitivity `-100...1` and acceleration `0...20` ranges without edge-value jumps.

## 1.1.0 - 2026-07-16

- Replaced global cursor writes with per-mouse HID event-service settings.
- Matched the SteerMouse acceleration and sensitivity scales and fixed settings reverting after a brief speed change.
- Added conflict detection for other cursor-control utilities and automatic apply after they quit.
- Added per-device original-value capture, reconnect monitoring, and restore on disable or exit.
- Fixed sub-1.0 wheel multipliers by preserving fractional scroll deltas.
- Added an opt-in path for continuous wheel events so trackpad scrolling stays untouched by default.
- Marked generated events to prevent remapping loops and release Click Lock when event handling stops.
- Expanded button support to 32 buttons with live button and modifier detection.
- Added custom shortcuts, application/file/URL actions, media actions, cursor snapping, and application profiles.
- Added separate Accessibility, Input Monitoring, and event-posting diagnostics.
- Restored original HID values on SIGTERM/SIGINT and corrected automatic-reapply diagnostics.
- Kept the original button event when a configured action needs missing event-posting permission.
- Lowered the deployment target to macOS 14 and made the settings window open on launch.

## 0.1.0

- Initial development version
- Menu bar app
- Extra mouse button remapping
- Mouse wheel settings
- Mouse-only pointer speed settings
- Windows-like pointer preset
- System, Light, and Dark theme selector
- Local settings persistence
- Accessibility and Input Monitoring status
