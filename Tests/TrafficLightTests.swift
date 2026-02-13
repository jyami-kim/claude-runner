import XCTest
import AppKit
@testable import ClaudeRunnerLib

final class TrafficLightTests: XCTestCase {

    // MARK: - Image Creation

    func testImageSizeIdle() {
        let image = NSImage.trafficLight(counts: StateCounts())
        XCTAssertEqual(image.size.width, DesignTokens.iconWidth)
        XCTAssertEqual(image.size.height, DesignTokens.iconHeight)
    }

    func testImageIsNotTemplate() {
        let image = NSImage.trafficLight(counts: StateCounts())
        XCTAssertFalse(image.isTemplate)
    }

    // MARK: - Various State Combinations

    func testImageWithSingleActive() {
        var counts = StateCounts()
        counts.activeCount = 1
        let image = NSImage.trafficLight(counts: counts)
        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, DesignTokens.iconWidth)
    }

    func testImageWithSingleWaiting() {
        var counts = StateCounts()
        counts.waitingCount = 1
        let image = NSImage.trafficLight(counts: counts)
        XCTAssertNotNil(image)
    }

    func testImageWithSinglePermission() {
        var counts = StateCounts()
        counts.permissionCount = 1
        let image = NSImage.trafficLight(counts: counts)
        XCTAssertNotNil(image)
    }

    func testImageWithAllStates() {
        var counts = StateCounts()
        counts.activeCount = 1
        counts.waitingCount = 1
        counts.permissionCount = 1
        let image = NSImage.trafficLight(counts: counts)
        XCTAssertNotNil(image)
    }

    // MARK: - Badge Rendering (count >= 2)

    func testImageWithBadge() {
        var counts = StateCounts()
        counts.activeCount = 5
        let image = NSImage.trafficLight(counts: counts)
        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, DesignTokens.iconWidth)
    }

    func testImageWithMultipleBadges() {
        var counts = StateCounts()
        counts.activeCount = 3
        counts.waitingCount = 2
        counts.permissionCount = 4
        let image = NSImage.trafficLight(counts: counts)
        XCTAssertNotNil(image)
    }

    func testImageWithLargeCount() {
        var counts = StateCounts()
        counts.activeCount = 99
        let image = NSImage.trafficLight(counts: counts)
        XCTAssertNotNil(image)
    }

    // MARK: - Edge Cases

    func testImageWithZeroCounts() {
        let counts = StateCounts()
        XCTAssertEqual(counts.activeCount, 0)
        XCTAssertEqual(counts.waitingCount, 0)
        XCTAssertEqual(counts.permissionCount, 0)

        let image = NSImage.trafficLight(counts: counts)
        XCTAssertNotNil(image)
    }

    // MARK: - Icon Style Dispatcher

    func testIconDispatcherTrafficLight() {
        let image = NSImage.icon(style: .trafficLight, counts: StateCounts())
        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, DesignTokens.iconWidth)
        XCTAssertEqual(image.size.height, DesignTokens.iconHeight)
    }

    // MARK: - Pie Chart Style

    func testPieChartIdle() {
        let image = NSImage.pieChart(counts: StateCounts())
        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, 20)
        XCTAssertEqual(image.size.height, DesignTokens.iconHeight)
        XCTAssertFalse(image.isTemplate)
    }

    func testPieChartWithSessions() {
        var counts = StateCounts()
        counts.activeCount = 3
        counts.permissionCount = 1
        let image = NSImage.pieChart(counts: counts)
        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, 20)
    }

    func testPieChartSingleState() {
        var counts = StateCounts()
        counts.waitingCount = 5
        let image = NSImage.pieChart(counts: counts)
        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, 20)
    }

    func testIconDispatcherPieChart() {
        var counts = StateCounts()
        counts.activeCount = 1
        let image = NSImage.icon(style: .pieChart, counts: counts)
        XCTAssertNotNil(image)
    }

    // MARK: - Domino Style

    func testDominoIdle() {
        let image = NSImage.domino(counts: StateCounts())
        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, DesignTokens.iconWidth)
        XCTAssertEqual(image.size.height, DesignTokens.iconHeight)
        XCTAssertFalse(image.isTemplate)
    }

    func testDominoWithSessions() {
        var counts = StateCounts()
        counts.activeCount = 2
        counts.waitingCount = 3
        counts.permissionCount = 1
        let image = NSImage.domino(counts: counts)
        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, DesignTokens.iconWidth)
    }

    func testDominoWithBadge() {
        var counts = StateCounts()
        counts.activeCount = 5
        let image = NSImage.domino(counts: counts)
        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, DesignTokens.iconWidth)
    }

    func testIconDispatcherDomino() {
        var counts = StateCounts()
        counts.waitingCount = 2
        let image = NSImage.icon(style: .domino, counts: counts)
        XCTAssertNotNil(image)
    }

    // MARK: - Text Counter Style

    func testTextCounterIdle() {
        let image = NSImage.textCounter(counts: StateCounts())
        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, 28)
        XCTAssertEqual(image.size.height, DesignTokens.iconHeight)
        XCTAssertFalse(image.isTemplate)
    }

    func testTextCounterWithSessions() {
        var counts = StateCounts()
        counts.permissionCount = 2
        let image = NSImage.textCounter(counts: counts)
        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, 28)
    }

    func testIconDispatcherTextCounter() {
        var counts = StateCounts()
        counts.permissionCount = 1
        let image = NSImage.icon(style: .textCounter, counts: counts)
        XCTAssertNotNil(image)
    }

    // MARK: - All Styles Produce Correct Size

    func testAllStylesCorrectHeight() {
        var counts = StateCounts()
        counts.activeCount = 1
        counts.waitingCount = 1

        for style in IconStyle.allCases {
            let image = NSImage.icon(style: style, counts: counts)
            XCTAssertEqual(image.size.height, DesignTokens.iconHeight, "Height mismatch for \(style)")
            XCTAssertGreaterThan(image.size.width, 0, "Width should be positive for \(style)")
            XCTAssertFalse(image.isTemplate, "isTemplate should be false for \(style)")
        }
    }
}
