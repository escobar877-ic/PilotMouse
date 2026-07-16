import AppKit
@preconcurrency import ApplicationServices
import Combine
import CoreGraphics
import IOKit.hidsystem

struct MousePilotPermissionStatus: Equatable {
    var accessibilityTrusted: Bool
    var listenEventAccess: Bool
    var postEventAccess: Bool
    var hidListenEventAccess: Bool

    var postShortcutActions: Bool {
        postEventAccess
    }

    var canUseEventTap: Bool {
        // MousePilot uses an active event tap so it can suppress remapped buttons.
        accessibilityTrusted
    }

    var canPostActions: Bool {
        postEventAccess
    }

    var isReady: Bool {
        canUseEventTap && hidListenEventAccess && canPostActions
    }
}

@MainActor
final class PermissionsManager: ObservableObject {
    @Published private(set) var status: MousePilotPermissionStatus

    var onStatusChanged: ((MousePilotPermissionStatus) -> Void)?

    var isTrusted: Bool {
        status.isReady
    }

    var currentBundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "Unknown bundle identifier"
    }

    var currentAppPath: String {
        Bundle.main.bundleURL.path
    }

    private var refreshTimer: Timer?

    init() {
        self.status = Self.readStatus()
    }

    isolated deinit {
        refreshTimer?.invalidate()
    }

    func refresh() {
        updateStatus(Self.readStatus())
    }

    func startMonitoring() {
        refresh()

        guard refreshTimer == nil else {
            return
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func requestPermissionIfNeeded() {
        requestAccessibilityPermission()
        requestListenEventPermission()
        requestPostEventPermission()
        refresh()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func requestListenEventPermission() {
        if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) != kIOHIDAccessTypeGranted {
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        }
        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
    }

    func requestPostEventPermission() {
        if !CGPreflightPostEventAccess() {
            _ = CGRequestPostEventAccess()
        }
    }

    func openAccessibilitySettings() {
        openSystemSettings(urls: [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security",
            "x-apple.systempreferences:"
        ])
    }

    func openInputMonitoringSettings() {
        openSystemSettings(urls: [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_InputMonitoring",
            "x-apple.systempreferences:com.apple.preference.security",
            "x-apple.systempreferences:"
        ])
    }

    func revealCurrentBuildInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    private func openSystemSettings(urls: [String]) {
        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func updateStatus(_ newStatus: MousePilotPermissionStatus) {
        guard newStatus != status else {
            return
        }

        status = newStatus
        onStatusChanged?(newStatus)
    }

    private static func readStatus() -> MousePilotPermissionStatus {
        MousePilotPermissionStatus(
            accessibilityTrusted: AXIsProcessTrusted(),
            listenEventAccess: CGPreflightListenEventAccess(),
            postEventAccess: CGPreflightPostEventAccess(),
            hidListenEventAccess: IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        )
    }
}
