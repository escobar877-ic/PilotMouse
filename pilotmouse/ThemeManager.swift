import AppKit
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    func applyTheme(_ theme: AppTheme) {
        // Keep status-bar and system-owned windows independent from the settings theme.
        for window in NSApp.windows where window.title == "MousePilot" {
            applyTheme(theme, to: window)
        }
    }

    func applyTheme(_ theme: AppTheme, to window: NSWindow) {
        let appearance = theme.nsAppearance
        window.appearance = appearance
        window.contentView?.appearance = appearance
        window.backgroundColor = theme.windowBackgroundColor
        window.invalidateShadow()
        window.contentView?.needsDisplay = true
        window.standardWindowButton(.closeButton)?.superview?.needsDisplay = true
        window.displayIfNeeded()

        for childWindow in window.childWindows ?? [] {
            childWindow.appearance = appearance
            childWindow.contentView?.appearance = appearance
            childWindow.backgroundColor = theme.windowBackgroundColor
            childWindow.contentView?.needsDisplay = true
            childWindow.standardWindowButton(.closeButton)?.superview?.needsDisplay = true
            childWindow.displayIfNeeded()
        }
    }
}
