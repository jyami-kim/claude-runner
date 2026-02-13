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

    /// Creates an icon for the given style and state counts.
    static func icon(style: IconStyle, counts: StateCounts) -> NSImage {
        switch style {
        case .trafficLight:
            return trafficLight(counts: counts)
        case .singleDot:
            return singleDot(counts: counts)
        case .compactBar:
            return compactBar(counts: counts)
        case .textCounter:
            return textCounter(counts: counts)
        }
    }

    // MARK: - Single Dot

    /// A single colored dot showing the highest-priority state, with session count text.
    static func singleDot(counts: StateCounts) -> NSImage {
        let width = DesignTokens.iconWidth
        let height = DesignTokens.iconHeight
        let dotDiameter: CGFloat = 10

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            // Determine dominant color
            let color: NSColor
            if counts.permissionCount > 0 {
                color = DesignTokens.red
            } else if counts.waitingCount > 0 {
                color = DesignTokens.yellow
            } else if counts.activeCount > 0 {
                color = DesignTokens.green
            } else {
                color = NSColor.gray.withAlphaComponent(DesignTokens.dimAlpha)
            }

            let total = counts.totalCount
            let countStr = total > 0 ? "\(total)" : ""
            let countAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
            let countSize = (countStr as NSString).size(withAttributes: countAttrs)

            // Layout: dot + gap + count text, centered
            let gap: CGFloat = total > 0 ? 2 : 0
            let totalContentWidth = dotDiameter + gap + countSize.width
            let startX = (width - totalContentWidth) / 2

            // Draw dot
            let dotY = (height - dotDiameter) / 2
            let dotRect = NSRect(x: startX, y: dotY, width: dotDiameter, height: dotDiameter)
            let path = NSBezierPath(ovalIn: dotRect)
            color.setFill()
            path.fill()

            // Draw count text
            if total > 0 {
                let textX = startX + dotDiameter + gap
                let textY = (height - countSize.height) / 2
                (countStr as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: countAttrs)
            }

            return true
        }

        image.isTemplate = false
        return image
    }

    // MARK: - Compact Bar

    /// A horizontal bar showing proportional state colors.
    static func compactBar(counts: StateCounts) -> NSImage {
        let width = DesignTokens.iconWidth
        let height = DesignTokens.iconHeight
        let barHeight: CGFloat = 6
        let barWidth: CGFloat = width - 4
        let cornerRadius: CGFloat = 3

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let barY = (height - barHeight) / 2
            let barX: CGFloat = 2
            let total = counts.totalCount

            if total == 0 {
                // Empty bar
                let rect = NSRect(x: barX, y: barY, width: barWidth, height: barHeight)
                let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
                NSColor.gray.withAlphaComponent(DesignTokens.dimAlpha).setFill()
                path.fill()
                return true
            }

            // Clip to rounded rect
            let clipRect = NSRect(x: barX, y: barY, width: barWidth, height: barHeight)
            let clipPath = NSBezierPath(roundedRect: clipRect, xRadius: cornerRadius, yRadius: cornerRadius)
            clipPath.addClip()

            // Draw proportional segments: permission (red) → waiting (yellow) → active (green)
            let segments: [(color: NSColor, count: Int)] = [
                (DesignTokens.red, counts.permissionCount),
                (DesignTokens.yellow, counts.waitingCount),
                (DesignTokens.green, counts.activeCount)
            ]

            var currentX = barX
            for (color, count) in segments {
                guard count > 0 else { continue }
                let segmentWidth = barWidth * CGFloat(count) / CGFloat(total)
                let rect = NSRect(x: currentX, y: barY, width: segmentWidth, height: barHeight)
                color.setFill()
                NSBezierPath(rect: rect).fill()
                currentX += segmentWidth
            }

            return true
        }

        image.isTemplate = false
        return image
    }

    // MARK: - Text Counter

    /// "CC" text with a background color matching the dominant state.
    static func textCounter(counts: StateCounts) -> NSImage {
        let width = DesignTokens.iconWidth
        let height = DesignTokens.iconHeight

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            // Background color based on dominant state
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
}
