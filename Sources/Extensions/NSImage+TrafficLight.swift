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
                    drawBadge(count: count, circleX: x, circleY: circleY, circleDiameter: circleDiameter)
                }
            }

            return true
        }

        image.isTemplate = false
        return image
    }

    /// Creates an icon for the given style and state counts.
    static func icon(style: IconStyle, counts: StateCounts) -> NSImage {
        switch style {
        case .trafficLight:
            return trafficLight(counts: counts)
        case .pieChart:
            return pieChart(counts: counts)
        case .domino:
            return domino(counts: counts)
        case .textCounter:
            return textCounter(counts: counts)
        }
    }

    // MARK: - Pie Chart

    /// A proportional pie chart showing state distribution.
    /// Segments are drawn clockwise from 12 o'clock: permission(red) → waiting(yellow) → active(green).
    static func pieChart(counts: StateCounts) -> NSImage {
        let width: CGFloat = 20
        let height = DesignTokens.iconHeight
        let radius: CGFloat = 7
        let center = NSPoint(x: width / 2, y: height / 2)

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let total = counts.totalCount

            if total == 0 {
                // Empty circle
                let ovalRect = NSRect(x: center.x - radius, y: center.y - radius,
                                      width: radius * 2, height: radius * 2)
                let path = NSBezierPath(ovalIn: ovalRect)
                NSColor.gray.withAlphaComponent(DesignTokens.dimAlpha).setFill()
                path.fill()
                return true
            }

            let segments: [(color: NSColor, count: Int)] = [
                (DesignTokens.red, counts.permissionCount),
                (DesignTokens.yellow, counts.waitingCount),
                (DesignTokens.green, counts.activeCount)
            ]

            // Start from 12 o'clock (90°), draw clockwise (decreasing angle)
            var currentAngle: CGFloat = 90

            for (color, count) in segments {
                guard count > 0 else { continue }
                let sweepAngle = CGFloat(count) / CGFloat(total) * 360.0
                let endAngle = currentAngle - sweepAngle

                let path = NSBezierPath()
                path.move(to: center)
                path.appendArc(withCenter: center, radius: radius,
                               startAngle: currentAngle, endAngle: endAngle, clockwise: true)
                path.close()

                color.setFill()
                path.fill()

                currentAngle = endAngle
            }

            return true
        }

        image.isTemplate = false
        return image
    }

    // MARK: - Domino

    /// Vertical rectangle tiles showing state counts.
    /// Each state gets tiles: 0→dim tile, 1→bright tile, 2→two bright tiles, 3+→tile with number badge.
    /// Order: permission(red) → waiting(yellow) → active(green).
    static func domino(counts: StateCounts) -> NSImage {
        let width = DesignTokens.iconWidth
        let height = DesignTokens.iconHeight
        let tileWidth: CGFloat = 4
        let tileHeight: CGFloat = 14
        let tileSpacing: CGFloat = 1.5
        let tileCorner: CGFloat = 1

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let states: [(color: NSColor, count: Int)] = [
                (DesignTokens.red, counts.permissionCount),
                (DesignTokens.yellow, counts.waitingCount),
                (DesignTokens.green, counts.activeCount)
            ]

            // Calculate total tiles needed for layout
            var totalTiles = 0
            for (_, count) in states {
                if count == 0 {
                    totalTiles += 1 // dim placeholder
                } else if count <= 2 {
                    totalTiles += count
                } else {
                    totalTiles += 1 // single tile + badge
                }
            }

            // Add group spacing (2 gaps between 3 state groups)
            let groupSpacing: CGFloat = 2.5
            let totalContentWidth = CGFloat(totalTiles) * tileWidth
                + CGFloat(totalTiles - 1) * tileSpacing
                + 2 * groupSpacing // spacing between the 3 groups
            var currentX = (width - totalContentWidth) / 2
            let tileY = (height - tileHeight) / 2

            for (groupIndex, (color, count)) in states.enumerated() {
                if groupIndex > 0 {
                    currentX += groupSpacing
                }

                if count == 0 {
                    // Dim placeholder tile
                    let rect = NSRect(x: currentX, y: tileY, width: tileWidth, height: tileHeight)
                    let path = NSBezierPath(roundedRect: rect, xRadius: tileCorner, yRadius: tileCorner)
                    color.withAlphaComponent(DesignTokens.dimAlpha).setFill()
                    path.fill()
                    currentX += tileWidth + tileSpacing
                } else if count <= 2 {
                    // Draw individual tiles
                    for i in 0..<count {
                        let rect = NSRect(x: currentX, y: tileY, width: tileWidth, height: tileHeight)
                        let path = NSBezierPath(roundedRect: rect, xRadius: tileCorner, yRadius: tileCorner)
                        color.setFill()
                        path.fill()
                        currentX += tileWidth
                        if i < count - 1 { currentX += tileSpacing }
                    }
                    currentX += tileSpacing
                } else {
                    // Single tile + number badge for count >= 3
                    let rect = NSRect(x: currentX, y: tileY, width: tileWidth, height: tileHeight)
                    let path = NSBezierPath(roundedRect: rect, xRadius: tileCorner, yRadius: tileCorner)
                    color.setFill()
                    path.fill()

                    // Badge
                    let badgeStr = "\(count)"
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: DesignTokens.badgeFont,
                        .foregroundColor: DesignTokens.badgeText
                    ]
                    let size = (badgeStr as NSString).size(withAttributes: attrs)
                    let badgeH = DesignTokens.badgeSize
                    let badgeW = max(size.width + 3, badgeH)
                    let badgeX = currentX + tileWidth - badgeW / 2
                    let badgeY = tileY + tileHeight - badgeH / 2
                    let badgeRect = NSRect(x: badgeX, y: badgeY, width: badgeW, height: badgeH)
                    let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: badgeH / 2, yRadius: badgeH / 2)
                    DesignTokens.badgeBg.setFill()
                    badgePath.fill()

                    let textX = badgeX + (badgeW - size.width) / 2
                    let textY = badgeY + (badgeH - size.height) / 2
                    (badgeStr as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)

                    currentX += tileWidth + tileSpacing
                }
            }

            return true
        }

        image.isTemplate = false
        return image
    }

    // MARK: - Text Counter

    /// "CC" text with a background color matching the dominant state.
    static func textCounter(counts: StateCounts) -> NSImage {
        let width: CGFloat = 28
        let height = DesignTokens.iconHeight

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            // Background color based on dominant state (permission > waiting > active)
            let bgColor: NSColor
            if counts.permissionCount > 0 {
                bgColor = DesignTokens.red
            } else if counts.waitingCount > 0 {
                bgColor = DesignTokens.yellow
            } else if counts.activeCount > 0 {
                bgColor = DesignTokens.green
            } else {
                bgColor = NSColor.gray.withAlphaComponent(0.3)
            }

            // Draw rounded background
            let inset: CGFloat = 1
            let bgRect = NSRect(x: inset, y: inset, width: width - inset * 2, height: height - inset * 2)
            let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4)
            bgColor.setFill()
            bgPath.fill()

            // Draw "CC" text
            let textAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let textSize = ("CC" as NSString).size(withAttributes: textAttrs)
            let textX = (width - textSize.width) / 2
            let textY = (height - textSize.height) / 2
            ("CC" as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: textAttrs)

            return true
        }

        image.isTemplate = false
        return image
    }

    // MARK: - Helpers

    private static func drawBadge(count: Int, circleX: CGFloat, circleY: CGFloat, circleDiameter: CGFloat) {
        let badgeStr = "\(count)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: DesignTokens.badgeFont,
            .foregroundColor: DesignTokens.badgeText
        ]
        let size = (badgeStr as NSString).size(withAttributes: attrs)

        let badgeHeight = DesignTokens.badgeSize
        let badgeWidth = max(size.width + 3, badgeHeight)
        let badgeX = circleX + circleDiameter - badgeWidth / 2
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
