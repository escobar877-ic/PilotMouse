# Security Policy

## Reporting an Issue

Report security concerns through a private GitHub security advisory when available. If private reporting is unavailable, open an issue without including sensitive details and request a private contact channel.

Include the affected MousePilot version, macOS version, reproduction steps, and expected impact.

## Security Model

MousePilot is a local-only utility:

- No external servers
- No network client
- No remote code execution features
- No downloaded scripts or plugins
- No telemetry or analytics SDKs
- No storage of keyboard input or click history

MousePilot uses macOS Accessibility and Input Monitoring permissions only for configured mouse button listening and shortcut actions.
