import XCTest
@testable import ClaudeRunnerLib

// MARK: - Mock

final class MockLoginItemManager: LoginItemManaging {
    var registerCalled = false
    var unregisterCalled = false
    var mockIsEnabled = false
    var shouldThrow = false

    func register() throws {
        registerCalled = true
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        mockIsEnabled = true
    }

    func unregister() throws {
        unregisterCalled = true
        if shouldThrow { throw NSError(domain: "test", code: 2) }
        mockIsEnabled = false
    }

    var isEnabled: Bool { mockIsEnabled }
}

// MARK: - Tests

final class LoginItemManagerTests: XCTestCase {

    func testRegisterCallsThrough() throws {
        let mock = MockLoginItemManager()
        XCTAssertFalse(mock.registerCalled)
        XCTAssertFalse(mock.isEnabled)

        try mock.register()
        XCTAssertTrue(mock.registerCalled)
        XCTAssertTrue(mock.isEnabled)
    }

    func testUnregisterCallsThrough() throws {
        let mock = MockLoginItemManager()
        mock.mockIsEnabled = true

        try mock.unregister()
        XCTAssertTrue(mock.unregisterCalled)
        XCTAssertFalse(mock.isEnabled)
    }

    func testRegisterThrows() {
        let mock = MockLoginItemManager()
        mock.shouldThrow = true

        XCTAssertThrowsError(try mock.register())
        XCTAssertTrue(mock.registerCalled)
    }

    func testUnregisterThrows() {
        let mock = MockLoginItemManager()
        mock.shouldThrow = true

        XCTAssertThrowsError(try mock.unregister())
        XCTAssertTrue(mock.unregisterCalled)
    }

    func testProtocolConformance() {
        // Verify LoginItemManager conforms to protocol
        let _: LoginItemManaging = MockLoginItemManager()
    }
}
