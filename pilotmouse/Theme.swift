import AppKit
import SwiftUI

extension AppTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    var windowBackgroundColor: NSColor {
        .windowBackgroundColor
    }
}

enum AppColors {
    static var windowBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    static var secondaryBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

    static var separator: Color {
        Color(nsColor: .separatorColor)
    }
}
