import XCTest
@testable import ClaudeRunnerLib

final class WorktreeResolutionTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("worktree-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Normal repo (.git directory) → returns original cwd

    func testNormalRepoReturnsOriginalCwd() {
        let projectDir = tempDir.appendingPathComponent("my-project")
        let gitDir = projectDir.appendingPathComponent(".git")
        try! FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        let result = JetBrainsFocuser.resolveWorktreeRoot(cwd: projectDir.path)
        XCTAssertEqual(result, projectDir.path)
    }

    // MARK: - No .git at all → returns original cwd

    func testNoGitReturnsOriginalCwd() {
        let projectDir = tempDir.appendingPathComponent("no-git")
        try! FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let result = JetBrainsFocuser.resolveWorktreeRoot(cwd: projectDir.path)
        XCTAssertEqual(result, projectDir.path)
    }

    // MARK: - Worktree → resolves to original project root

    func testWorktreeResolvesToOriginalRoot() {
        let originalProject = tempDir.appendingPathComponent("original")
        let originalGitDir = originalProject.appendingPathComponent(".git")
        let worktreesDir = originalGitDir.appendingPathComponent("worktrees/feature-branch")
        try! FileManager.default.createDirectory(at: worktreesDir, withIntermediateDirectories: true)

        let worktreeDir = tempDir.appendingPathComponent("worktree-checkout")
        try! FileManager.default.createDirectory(at: worktreeDir, withIntermediateDirectories: true)

        let gitFileContent = "gitdir: \(originalGitDir.path)/worktrees/feature-branch\n"
        try! gitFileContent.write(
            to: worktreeDir.appendingPathComponent(".git"),
            atomically: true, encoding: .utf8
        )

        let result = JetBrainsFocuser.resolveWorktreeRoot(cwd: worktreeDir.path)
        XCTAssertEqual(result, originalProject.path)
    }

    // MARK: - Invalid .git file content → returns original cwd

    func testInvalidGitFileContentReturnsOriginalCwd() {
        let projectDir = tempDir.appendingPathComponent("bad-git-file")
        try! FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        try! "some random content\n".write(
            to: projectDir.appendingPathComponent(".git"),
            atomically: true, encoding: .utf8
        )

        let result = JetBrainsFocuser.resolveWorktreeRoot(cwd: projectDir.path)
        XCTAssertEqual(result, projectDir.path)
    }

    // MARK: - .git file without /worktrees/ pattern → returns original cwd

    func testGitFileWithoutWorktreesPatternReturnsOriginalCwd() {
        let projectDir = tempDir.appendingPathComponent("submodule")
        try! FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        try! "gitdir: /some/other/path/modules/submodule\n".write(
            to: projectDir.appendingPathComponent(".git"),
            atomically: true, encoding: .utf8
        )

        let result = JetBrainsFocuser.resolveWorktreeRoot(cwd: projectDir.path)
        XCTAssertEqual(result, projectDir.path)
    }

    // MARK: - Worktree inside .claude/worktrees/

    func testClaudeWorktreeResolution() {
        let originalProject = tempDir.appendingPathComponent("my-project")
        let originalGitDir = originalProject.appendingPathComponent(".git")
        let worktreesDir = originalGitDir.appendingPathComponent("worktrees/xyz")
        try! FileManager.default.createDirectory(at: worktreesDir, withIntermediateDirectories: true)

        let worktreeDir = originalProject
            .appendingPathComponent(".claude/worktrees/xyz")
        try! FileManager.default.createDirectory(at: worktreeDir, withIntermediateDirectories: true)

        let gitFileContent = "gitdir: \(originalGitDir.path)/worktrees/xyz\n"
        try! gitFileContent.write(
            to: worktreeDir.appendingPathComponent(".git"),
            atomically: true, encoding: .utf8
        )

        let result = JetBrainsFocuser.resolveWorktreeRoot(cwd: worktreeDir.path)
        XCTAssertEqual(result, originalProject.path)
    }
}
