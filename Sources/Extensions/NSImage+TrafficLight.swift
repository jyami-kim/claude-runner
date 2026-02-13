import AppKit

extension NSImage {
    /// Creates a horizontal traffic light icon for the menu bar.
    ///
    /// Layout (left to right): Red → Yellow → Green
    /// - Active state circles are bright (alpha 1.0)
    /// - Inactive state circles are dim (alpha 0.15)
    /// - If a state has 2+ sessions, a small badge number is drawn above the circle
    ///
    /// - Parameter counts: The current state counts
    /// - Returns: An NSImage sized for the menu bar (~36x18pt)
    static func trafficLight(counts: StateCounts) -> NSImage {
        let width = DesignTokens.iconWidth
        let height = DesignTokens.iconHeight
        let circleRadius = DesignTokens.circleRadius
        let circleDiameter = circleRadius * 2
        let spacing = DesignTokens.circleSpacing
        let totalWidth = circleDiameter * 3 + spacing * 2
        let startX = (width - totalWidth) / 2
        let circleY = (height - circleDiameter) / 2

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let dimAlpha = DesignTokens.dimAlpha

            let circles: [(color: NSColor, count: Int, x: CGFloat)] = [
                (DesignTokens.red, counts.permissionCount, startX),
                (DesignTokens.yellow, counts.waitingCount, startX + circleDiameter + spacing),
                (DesignTokens.green, counts.activeCount, startX + (circleDiameter + spacing) * 2)
            ]

            for (color, count, x) in circles {
                let circleRect = NSRect(x: x, y: circleY, width: circleDiameter, height: circleDiameter)
                let alpha: CGFloat = count > 0 ? 1.0 : dimAlpha
                let fillColor = color.withAlphaComponent(alpha)

                // Draw circle
                let path = NSBezierPath(ovalIn: circleRect)
                fillColor.setFill()
                path.fill()

                // Draw badge if count >= 2
                if count >= 2 {
                    let badgeStr = "\(count)"
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: DesignTokens.badgeFont,
                        .foregroundColor: DesignTokens.badgeText
                    ]
                    let size = (badgeStr as NSString).size(withAttributes: attrs)

                    let badgeHeight = DesignTokens.badgeSize
                    let badgeWidth = max(size.width + 3, badgeHeight)
                    let badgeX = x + circleDiameter - badgeWidth / 2
                    let badgeY = circleY + circleDiameter - badgeHeight / 2
                    let badgeRect = NSRect(x: badgeX, y: badgeY, width: badgeWidth, height: badgeHeight)
                    let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: badgeHeight / 2, yRadius: badgeHeight / 2)
                    DesignTokens.badgeBg.setFill()
                    badgePath.fill()

                    let textX = badgeX + (badgeWidth - size.width) / 2
                    let textY = badgeY + (badgeHeight - size.height) / 2
                    (badgeStr as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)
                }
            }

            return true
        }

        image.isTemplate = false
        return image
    }
}
