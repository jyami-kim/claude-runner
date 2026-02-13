import XCTest
import AppKit
@testable import ClaudeRunnerLib

final class DesignTokensTests: XCTestCase {

    // MARK: - Color Mapping Consistency

    func testNSColorMapping() {
        XCTAssertEqual(DesignTokens.nsColor(for: .permission), DesignTokens.red)
        XCTAssertEqual(DesignTokens.nsColor(for: .waiting), DesignTokens.yellow)
        XCTAssertEqual(DesignTokens.nsColor(for: .active), DesignTokens.green)
    }

    func testSwiftUIColorMappingCoversAllStates() {
        // Ensure color(for:) handles all cases without crashing
        for state in [SessionState.active, .waiting, .permission] {
            let _ = DesignTokens.color(for: state)
        }
    }

    // MARK: - Dimension Constants

    func testIconDimensions() {
        XCTAssertEqual(DesignTokens.iconWidth, 36)
        XCTAssertEqual(DesignTokens.iconHeight, 18)
    }

    func testCircleDimensions() {
        XCTAssertGreaterThan(DesignTokens.circleRadius, 0)
        XCTAssertGreaterThanOrEqual(DesignTokens.circleSpacing, 0)
    }

    func testDimAlpha() {
        XCTAssertEqual(DesignTokens.dimAlpha, 0.15, accuracy: 0.001)
        XCTAssertGreaterThan(DesignTokens.dimAlpha, 0)
        XCTAssertLessThan(DesignTokens.dimAlpha, 1)
    }

    func testBadgeDimensions() {
        XCTAssertGreaterThan(DesignTokens.badgeSize, 0)
    }

    func testPopoverWidth() {
        XCTAssertEqual(DesignTokens.popoverWidth, 260)
    }

    func testDotSize() {
        XCTAssertEqual(DesignTokens.dotSize, 8)
        XCTAssertEqual(DesignTokens.dotTextGap, 8)
    }
}
