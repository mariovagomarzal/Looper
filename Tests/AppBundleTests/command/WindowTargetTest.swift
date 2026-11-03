@testable import AppBundle
import Common
import XCTest

@MainActor
final class WindowTargetTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private func args(_ raw: String) -> (any CmdArgs)? {
        if case .cmd(.cmd(let command)) = parseCommand(raw) { command.args } else { nil }
    }

    func testParse() {
        assertEquals(args("close --window-id 5")?.windowId, .id(OpaqueWindowId(5)))
        assertEquals(args("close --window-id focused")?.windowId, .focused)
        assertEquals(args("close --window-id pointer")?.windowId, .pointer)
        assertEquals(args("swap left --window-id wheel")?.windowId, .wheel)
        XCTAssertNotNil(parseCommand("close --window-id under").errorOrNil)
        assertEquals(args("test --window-id wheel %{window-layout} = floating")?.windowId, .wheel)
        assertEquals((args("test-not --window-id wheel %{window-layout} = floating") as? TestNotCmdArgs)?.testArgs.windowId, .wheel)
    }

    func testResolve() {
        let workspace = Workspace.get(byName: "a")
        let focused = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let other = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        assertTrue(focused.focusWindow())

        let io = CmdIoImpl(stdin: .emptyStdin)
        XCTAssertTrue(WindowTarget.focused.resolveOrReportError(.defaultEnv, io) === focused)
        XCTAssertTrue(WindowTarget.id(other.windowId).resolveOrReportError(.defaultEnv, io) === other)

        let wheelEnv = CmdEnv.defaultEnv.withWheel(WheelGestureEnv(windowId: other.windowId))
        XCTAssertTrue(WindowTarget.wheel.resolveOrReportError(wheelEnv, io) === other)
        assertEquals(io.stderr, [])

        XCTAssertNil(WindowTarget.wheel.resolveOrReportError(.defaultEnv, io))
        XCTAssertNil(WindowTarget.wheel.resolveOrReportError(.defaultEnv.withWheel(WheelGestureEnv(windowId: nil)), io))
        assertEquals(io.stderr, [
            "'--window-id wheel' is only valid in wheel actions and conditions",
            "There was no window under the mouse pointer when the wheel opened",
        ])
    }

    func testCommandsTargetTheWheelWindow() async {
        let workspace = Workspace.get(byName: "a")
        let focused = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let underPointer = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        assertTrue(focused.focusWindow())
        let wheelEnv = CmdEnv.defaultEnv.withWheel(WheelGestureEnv(windowId: underPointer.windowId))

        // Without the flag, commands keep acting on the focused window, also in wheel actions
        assertEquals(await parseCommand("test %{window-id} = 1").cmdOrDie.run(wheelEnv, .emptyStdin).exitCode.rawValue, 0)
        assertEquals(await parseCommand("test --window-id wheel %{window-id} = 2").cmdOrDie.run(wheelEnv, .emptyStdin).exitCode.rawValue, 0)
        assertEquals(await parseCommand("focus --window-id wheel").cmdOrDie.run(wheelEnv, .emptyStdin).exitCode.rawValue, 0)
        assertEquals(globalFocus.windowOrNil?.windowId, 2)
    }
}
