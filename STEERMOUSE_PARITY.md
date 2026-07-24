# SteerMouse Parity Matrix

This matrix compares MousePilot with the public SteerMouse 5 feature set and the locally installed SteerMouse 5.7.8 resources. "Implemented" means the code path exists and passes static/model checks. It does not replace a physical-device test.

Reference: <https://plentycom.jp/en/steermouse/index.html>

| Area | MousePilot status | Evidence and boundary |
| --- | --- | --- |
| Cursor acceleration `0...99` | Implemented, physical HID test passed | `MouseCursorMapper` uses `5 * (level / 99)^2`; the requested fixed-point value was accepted and read back on a physical USB mouse. |
| Cursor sensitivity `5...1990` | Implemented, physical HID test passed | `HIDPointerResolution = 2000 - sensitivity`; values `1200` and `1900` produced live resolutions `800` and `100` on a physical USB mouse. |
| Cursor lifecycle | Implemented | Original per-service values are captured and restored on disable, normal quit, SIGTERM, and SIGINT. SIGKILL and power loss cannot run cleanup. |
| Driver conflict handling | Implemented | Known mouse utilities pause native writes; repeated unknown resets stop after three retries instead of causing speed pulses. |
| Basic button mappings | Implemented for CGEvent-visible buttons 1-32 | Failed or unavailable actions pass the physical event through. Raw-only vendor controls remain unsupported. |
| Modifier mappings | Implemented | All 16 Command/Shift/Option/Control combinations are stored, edited, normalized, and resolved with base-action fallback. |
| Button chords | Implemented | Two-button and button-plus-wheel chords use delayed suppression, replay, and per-device state. |
| Click actions | Implemented | Left, right, middle, double, triple, buttons 4-32, Click Lock, and key-plus-click actions are available; held input is released on stop, profile changes, and mapping changes. |
| Keyboard shortcuts | Implemented | Single shortcuts and ordered sequences with waits/click steps work. Optional held repetition follows the macOS key-repeat delay and interval. |
| Navigation and system actions | Broad coverage | Back/forward, Mission Control, Spaces, desktops 1-5, desktop, Launchpad/Apps, Spotlight, Siri, Quick Note, lock, app/window/tab actions are present. System shortcut customization can affect results. |
| Music control | Implemented for common controls | Volume, mute, play/pause, previous/next, and eject are present. Vendor-specific fine-volume behavior is not implemented. |
| Open targets | Implemented | Up to 32 applications, files, or URLs can be assigned to one mapping and are opened in order. |
| Cursor snapping | Broad coverage | Manual actions cover default, cancel, close, minimize, fullscreen, Dock, and screen center. Automatic snapping covers the five window controls and respects application > device > global settings. SteerMouse click/bounce/jump animation, return-to-origin, and arbitrary targets are not implemented. |
| Wheel direction and sensitivity | Implemented, native HID test passed | Vertical/horizontal event scaling, fractional remainder preservation, native-resolution compensation, trackpad passthrough, and full-range nonlinear UI controls are implemented. A physical USB mouse accepted and reported the requested native wheel resolution. |
| Wheel acceleration | Implemented, physical HID test passed | Native mouse scroll acceleration `0...20` is applied transactionally; a physical USB mouse accepted and reported both test and restored values. |
| Auto Scroll | Implemented | Two-axis velocity scrolling, dead zone, Shift axis lock, indicator, and safe cancellation are present. |
| Continuous wheel input | Implemented | Mouse continuous events are opt-in; unmatched trackpad events pass through unchanged. |
| Application profiles | Implemented | Case-insensitive bundle matching; application settings override device and global settings. |
| Device profiles | Implemented | Serial is preferred; otherwise `VID:PID:transport` is stable across USB ports and driver display-name changes. Identical serial-less models share a profile. |
| Import and export | Implemented | Versioned JSON plus legacy raw JSON migration, range validation, duplicate-ID repair, and atomic export. |
| Vendor wheel modes | Not implemented | Free-spin/ratchet and vendor output reports require per-model adapters. |
| Hardware DPI | Not implemented | MousePilot changes macOS pointer resolution, not the sensor DPI stored in supported gaming mice. |
| Raw-only special buttons | Not implemented | Controls that never produce a CGEvent require a dedicated raw-HID action pipeline and per-device definitions. |
| Launch at login | Implemented | The About tab registers the main app through `SMAppService.mainApp` and links to Login Items when macOS requires approval. |
| Recommended settings sharing | Intentionally omitted | MousePilot has no account, telemetry, or network service. |
| Apple gesture devices | Intentionally unsupported | Magic Mouse, Magic Trackpad, and internal trackpads are not modified, matching SteerMouse's documented exclusion. |

## Verification State

Completed checks:

- Core Swift typecheck for settings, HID controllers, event routing, actions, and profile controllers.
- Warning-free Swift 5 and Swift 6 builds with the project's MainActor, Approachable Concurrency, and upcoming-feature settings.
- Model harness for migration, normalization, mappings, modifiers, chords, sequences, profile priority, stable device identity, and import/export.
- Isolated harnesses for shortcut-repeat lifecycle, automatic cursor snapping, and nonlinear scroll mapping.
- Runtime UI and persistence checks for every tab, cursor sensitivity, full wheel ranges, chords, application profiles, launch at login, and driver-conflict reporting.
- Optimized arm64 and x86_64 compilation, linking, and universal Mach-O verification with only system framework dependencies.
- Objective-C bridge syntax check.
- Objective-C static analyzer check.
- Xcode Debug and Swift 6 Debug builds with warnings treated as errors, plus Xcode Analyze.
- Ad-hoc signature verification, DMG checksum verification, read-only mount inspection, and a Release launch/quit smoke test directly from the final image.
- Source parse and whitespace checks.
- Apple IOHID source review for pointer-resolution and acceleration-filter behavior.
- Installed SteerMouse 5.7.8 binary verification of the inverse sensitivity display mapping and its `2000.0` constant.
- Installed MousePilot 1.3.1 verification against the live macOS pointer and scroll filters on a physical USB mouse, including changed values and restoration of the user's original settings.

Still required before claiming a fully verified release:

- Physical button, chord, wheel-event scaling, Auto Scroll, hot-plug, wake, disable, and quit tests with Accessibility and Input Monitoring granted to the exact final app binary.
- A Developer ID signature and notarization if permissions must survive upgrades without re-adding the app or the image will be distributed to other Macs.
