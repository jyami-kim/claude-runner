import AppKit
import SwiftUI

/// Shared design tokens from Figma Make design.
/// Colors match Apple HIG dark-mode palette for strong menu bar contrast.
enum DesignTokens {
    // MARK: - State Colors (NSColor for menu bar icon)

    static let red = NSColor(red: 1.0, green: 0.271, blue: 0.227, alpha: 1.0)       // #FF453A
    static let yellow = NSColor(red: 1.0, green: 0.839, blue: 0.039, alpha: 1.0)     // #FFD60A
    static let green = NSColor(red: 0.188, green: 0.820, blue: 0.345, alpha: 1.0)    // #30D158

    /// Dim alpha for inactive circles
    static let dimAlpha: CGFloat = 0.15

    // MARK: - State Colors (SwiftUI for popover)

    static let redSwiftUI = Color(red: 1.0, green: 0.271, blue: 0.227)       // #FF453A
    static let yellowSwiftUI = Color(red: 1.0, green: 0.839, blue: 0.039)    // #FFD60A
    static let greenSwiftUI = Color(red: 0.188, green: 0.820, blue: 0.345)   // #30D158

    // MARK: - Badge

    static let badgeBg = NSColor.black.withAlphaComponent(0.75)
    static let badgeText = NSColor.white
    static let badgeFont = NSFont.systemFont(ofSize: 7, weight: .bold)

    // MARK: - Menu Bar Icon Dimensions

    static let iconWidth: CGFloat = 36
    static let iconHeight: CGFloat = 18
    static let circleRadius: CGFloat = 5.0
    static let circleSpacing: CGFloat = 2.0
    static let badgeSize: CGFloat = 9.0

    // MARK: - Popover

    static let popoverWidth: CGFloat = 260
    static let dotSize: CGFloat = 8
    static let dotTextGap: CGFloat = 8

    /// SwiftUI color for a session state
    static func color(for state: SessionState) -> Color {
        switch state {
        case .permission: return redSwiftUI
        case .waiting: return yellowSwiftUI
        case .active: return greenSwiftUI
        }
    }

    /// NSColor for a session state
    static func nsColor(for state: SessionState) -> NSColor {
        switch state {
        case .permission: return red
        case .waiting: return yellow
        case .active: return green
        }
    }
}
