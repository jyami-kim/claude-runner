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
        let width: CGFloat = 36
        let height: CGFloat = 18
        let circleRadius: CGFloat = 5.0
        let circleDiameter = circleRadius * 2
        let spacing: CGFloat = 2.0
        let totalWidth = circleDiameter * 3 + spacing * 2
        let startX = (width - totalWidth) / 2
        let circleY = (height - circleDiameter) / 2

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            // Colors for each state
            let redColor = NSColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1.0)
            let yellowColor = NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
            let greenColor = NSColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 1.0)
            let dimAlpha: CGFloat = 0.15

            let circles: [(color: NSColor, count: Int, x: CGFloat)] = [
                (redColor, counts.permissionCount, startX),
                (yellowColor, counts.waitingCount, startX + circleDiameter + spacing),
                (greenColor, counts.activeCount, startX + (circleDiameter + spacing) * 2)
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
                    let font = NSFont.systemFont(ofSize: 7, weight: .bold)
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: NSColor.white
                    ]
                    let size = (badgeStr as NSString).size(withAttributes: attrs)

                    // Badge background
                    let badgeWidth = max(size.width + 3, 9)
                    let badgeHeight: CGFloat = 9
                    let badgeX = x + circleDiameter - badgeWidth / 2
                    let badgeY = circleY + circleDiameter - badgeHeight / 2
                    let badgeRect = NSRect(x: badgeX, y: badgeY, width: badgeWidth, height: badgeHeight)
                    let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: badgeHeight / 2, yRadius: badgeHeight / 2)
                    NSColor.black.withAlphaComponent(0.75).setFill()
                    badgePath.fill()

                    // Badge text
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
