# Privacy

MousePilot is designed as a local-only macOS utility.

- No telemetry or analytics
- No user account
- No subscriptions
- No background network requests
- No cloud synchronization
- No keyboard logging
- No click history
- No collection or transmission of personal data

MousePilot stores configuration locally in macOS UserDefaults.

Accessibility permission is used for configured actions that inspect or control the frontmost window. Input Monitoring is used only to process supported mouse button and wheel events. Event-posting access is used only to send actions selected by the user. The shortcut recorder stores only the shortcut explicitly entered while its recording sheet is open; MousePilot does not retain general keyboard input or mouse event history. A user-configured Open URL action delegates that URL to macOS.
