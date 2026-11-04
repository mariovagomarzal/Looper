@testable import AppBundle
import Common
import XCTest

/// Commands that target the workspaces of another monitor. A second monitor sits right of the main test monitor
@MainActor
final class CrossMonitorCommandsTest: XCTestCase {
    private var right: Monitor!
    private var rightWorkspaces: WorkspacesContainer { right.activeWorkspacesContainer }
    private var left: Workspace!

    override func setUp() async throws {
        setUpWorkspacesForTests()
        unsafe extraMonitorInfosForTests = [makeMonitorInfoForTests(id: 2, name: "Right Monitor", rect: Rect(topLeftX: 1920, topLeftY: 0, width: 960, height: 540))]
        gcMonitors()
        right = unsafe extraMonitorInfosForTests[0].toMonitorOrRearrangeMonitors()
        assertTrue(Workspace.get(byName: "b", in: rightWorkspaces).focusWorkspace())
        left = Workspace.get(byName: "a", in: mainMonitorInfo.toMonitorOrRearrangeMonitors().activeWorkspacesContainer)
        assertTrue(left.focusWorkspace())
    }

    override func tearDown() async throws { setUpWorkspacesForTests() }

    private func run(_ command: String, _ env: CmdEnv = .defaultEnv) async -> CmdResult {
        await parseCommand(command).cmdOrDie.run(env, .emptyStdin)
    }

    func testParse() {
        guard case .cmd(let focusMonitor as FocusMonitorCommand) = parseCommand("focus-monitor pointer").cmdOrDie else { return XCTFail() }
        assertEquals(focusMonitor.args.target.val, .pointer)
        guard case .cmd(let workspace as WorkspaceCommand) = parseCommand("workspace --monitor wheel 3").cmdOrDie else { return XCTFail() }
        assertEquals(workspace.args.monitor, .wheel)
        guard case .cmd(let move as MoveNodeToWorkspaceCommand) = parseCommand("move-node-to-workspace --monitor 2 next").cmdOrDie else { return XCTFail() }
        assertEquals(move.args.targetMonitor, .patterns([.sequenceNumber(2)]))
        XCTAssertNil(parseCommand("list-monitors --pointer").errorOrNil)
        XCTAssertNil(parseCommand("list-workspaces --monitor pointer").errorOrNil)
        XCTAssertNotNil(parseCommand("list-monitors --mouse").errorOrNil)
        XCTAssertNotNil(parseCommand("focus-monitor --wrap-around pointer").errorOrNil)
        XCTAssertNotNil(parseCommand("layout --monitor right accordion").errorOrNil) // Requires --root
        XCTAssertNil(parseCommand("layout --root --monitor right accordion").errorOrNil)
        XCTAssertNil(parseCommand("swap-workspace-with-monitor --wrap-around next").errorOrNil)
        XCTAssertNotNil(parseCommand("move-workspace-to-monitor --wrap-around main").errorOrNil)
    }

    func testWorkspaceOnAnotherMonitor() async {
        assertEquals(await run("workspace --monitor right 3").exitCode.rawValue, 0)
        assertEquals(globalFocus.workspace.workspacesContainer, rightWorkspaces)
        assertEquals(globalFocus.workspace.name, "3")
        // The other monitor keeps its workspace
        assertEquals(left.workspacesContainer?.visibleWorkspace, left)

        // Visible there but not focused: it gets the focus
        assertTrue(left.focusWorkspace())
        assertEquals(await run("workspace --monitor right 3").exitCode.rawValue, 0)
        assertEquals(globalFocus.workspace.name, "3")
        assertEquals(globalFocus.workspace.workspacesContainer, rightWorkspaces)

        // next and prev among the workspaces of that monitor ('b' needs a window to survive the garbage collection)
        _ = TestWindow.new(id: 9, parent: Workspace.get(byName: "b", in: rightWorkspaces).rootTilingContainer)
        assertTrue(left.focusWorkspace())
        assertEquals(await run("workspace --monitor right next").exitCode.rawValue, 0) // '3' comes before 'b'
        assertEquals(globalFocus.workspace.name, "b")
        assertEquals(globalFocus.workspace.workspacesContainer, rightWorkspaces)
    }

    func testMoveNodeToWorkspaceOnAnotherMonitor() async {
        let window = TestWindow.new(id: 1, parent: left.rootTilingContainer)
        assertTrue(window.focusWindow())
        assertEquals(await run("move-node-to-workspace --monitor right 3").exitCode.rawValue, 0)
        assertEquals(window.nodeWorkspace, rightWorkspaces.workspace(named: "3"))
        assertEquals(globalFocus.workspace, left) // The focus stays

        assertEquals(await run("move-node-to-workspace --window-id 1 --monitor left --focus-follows-window 4").exitCode.rawValue, 0)
        assertEquals(window.nodeWorkspace?.name, "4")
        assertTrue(window.nodeWorkspace?.workspacesContainer === mainMonitorInfo.toMonitorOrRearrangeMonitors().activeWorkspacesContainer)
        assertEquals(globalFocus.windowOrNil, window)
    }

    func testMonitorFlagOfWorkspaceCommands() async {
        let rightVisible = rightWorkspaces.visibleWorkspace
        rightVisible.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1, index: INDEX_BIND_LAST).apply {
                TestWindow.new(id: 2, parent: $0)
            }
        }
        assertEquals(await run("flatten-workspace-tree --monitor right").exitCode.rawValue, 0)
        assertEquals(rightVisible.rootTilingContainer.children.count, 2)
        assertTrue(rightVisible.rootTilingContainer.children.allSatisfy { $0 is Window })

        assertEquals(await run("layout --root --monitor wheel accordion").exitCode.rawValue, 2) // Not in the wheel
        let wheel = CmdEnv.defaultEnv.withWheel(WheelGestureEnv(windowId: nil, pointerLocation: CGPoint(x: 2000, y: 100)))
        assertEquals(await run("layout --root --monitor wheel accordion", wheel).exitCode.rawValue, 0)
        assertEquals(rightVisible.rootTilingContainer.layout, .accordion)
        assertEquals(left.rootTilingContainer.layout, .tiles)
    }

    func testMoveWorkspaceToMonitor() async {
        let one = TestWindow.new(id: 1, parent: left.rootTilingContainer, adaptiveWeight: 1200)
        let two = TestWindow.new(id: 2, parent: left.rootTilingContainer, adaptiveWeight: 720)
        left.rootTilingContainer.layout = .accordion
        assertTrue(two.focusWindow())

        assertEquals(await run("move-workspace-to-monitor right").exitCode.rawValue, 0)
        let moved = rightWorkspaces.workspace(named: "a")
        XCTAssertNotNil(moved)
        assertEquals(one.nodeWorkspace, moved)
        assertEquals(moved?.rootTilingContainer.layout, .accordion)
        assertEquals(moved?.rootTilingContainer.children, [one, two])
        // Sizes scaled to the half as wide monitor
        assertEquals(one.getWeight(.h), 600)
        assertEquals(two.getWeight(.h), 360)
        assertTrue(left.isEffectivelyEmpty)
        // Visible and focused, on its most recent window
        assertEquals(rightWorkspaces.visibleWorkspace, moved)
        assertEquals(globalFocus.windowOrNil, two)

        // Back to a workspace that has windows: they're merged
        let three = TestWindow.new(id: 3, parent: left.rootTilingContainer)
        assertEquals(await run("move-workspace-to-monitor left").exitCode.rawValue, 0)
        assertEquals(left.rootTilingContainer.children.first, three)
        let nested = left.rootTilingContainer.children.last as? TilingContainer
        assertEquals(nested?.children, [one, two])
        assertEquals(nested?.layout, .accordion)

        assertEquals(await run("move-workspace-to-monitor focused").exitCode.rawValue, 2)
    }

    func testSwapWorkspaceWithMonitor() async {
        let one = TestWindow.new(id: 1, parent: left.rootTilingContainer)
        let floating = TestWindow.new(id: 2, parent: left.floatingWindowsContainer)
        let rightVisible = rightWorkspaces.visibleWorkspace
        let three = TestWindow.new(id: 3, parent: rightVisible.rootTilingContainer)
        rightVisible.rootTilingContainer.changeOrientation(.v)
        assertTrue(one.focusWindow())

        assertEquals(await run("swap-workspace-with-monitor right").exitCode.rawValue, 0)
        // Each monitor keeps its workspaces, the windows are exchanged
        assertEquals(rightWorkspaces.visibleWorkspace, rightVisible)
        assertEquals(one.nodeWorkspace, rightVisible)
        assertEquals(floating.nodeWorkspace, rightVisible)
        assertTrue(floating.parent === rightVisible.floatingWindowsContainer)
        assertEquals(three.nodeWorkspace, left)
        assertEquals(left.rootTilingContainer.orientation, .v)
        assertEquals(rightVisible.rootTilingContainer.orientation, .h)
        // The focus follows the window
        assertEquals(globalFocus.windowOrNil, one)
        assertEquals(globalFocus.workspace, rightVisible)
    }

    /// Everything a simulation could change on both monitors
    private func state() -> String {
        func describe(_ node: TreeNode) -> String {
            let children = node.children.map(describe).joined(separator: " ")
            let mru = node._mruChildren.map { String(ObjectIdentifier($0).hashValue) }.joined(separator: ",")
            let extra = switch node.nodeCases {
                case .tilingContainer(let c): "\(c.layout) \(c.orientation)"
                case .window(let w): "\(w.windowId)"
                case .workspace(let w): w.name
                default: ""
            }
            return "(\(ObjectIdentifier(node).hashValue) \(extra) w=\(node.snapshotAdaptiveWeight) mru=[\(mru)] \(children))"
        }
        let containers = Monitor.all.map(\.activeWorkspacesContainer)
        return containers.map(describe).joined(separator: " ") +
            " visible=\(containers.map { $0.visibleWorkspaceNameOrStale ?? "-" })" +
            " focus=\(globalFocus.windowOrNil?.windowId.description ?? "-")/\(globalFocus.workspace.name)"
    }

    func testPreviews() async throws {
        let one = TestWindow.new(id: 1, parent: left.rootTilingContainer)
        _ = TestWindow.new(id: 2, parent: left.rootTilingContainer)
        let rightVisible = rightWorkspaces.visibleWorkspace
        _ = TestWindow.new(id: 3, parent: rightVisible.rootTilingContainer)
        assertTrue(one.focusWindow())
        let initial = state()
        let commands = [
            "move-node-to-monitor right", "move-node-to-workspace --monitor right b", "move-node-to-workspace --monitor right 7",
            "move-workspace-to-monitor right", "swap-workspace-with-monitor right", "workspace --monitor right 5 && move-node-to-monitor left",
        ]
        for command in commands {
            _ = simulateWheelPreview(parseCommand(command).cmdOrDie, .defaultEnv, .all)
            assertEquals(state(), initial, additionalMsg: "after simulating '\(command)'")
        }

        // The window goes to the visible workspace of the other monitor, next to window 3
        let toMonitor = simulateWheelPreview(parseCommand("move-node-to-monitor right").cmdOrDie, .defaultEnv, .all) ?? []
        assertEquals(toMonitor.map(\.windowId), [1, 2, 3])
        assertEquals(toMonitor.first?.kind, .frame)
        XCTAssertTrue(toMonitor.first.map { $0.rect.minX >= 1920 } == true)
        // To a workspace that isn't visible: nothing to show for the window
        let hidden = simulateWheelPreview(parseCommand("move-node-to-workspace --monitor right 7").cmdOrDie, .defaultEnv, .target) ?? []
        assertEquals(hidden.map(\.windowId), [])
        // Whole workspaces: every window that moves
        let swapped = simulateWheelPreview(parseCommand("swap-workspace-with-monitor right").cmdOrDie, .defaultEnv, .target) ?? []
        assertEquals(swapped.map(\.windowId), [1, 2, 3])
        XCTAssertTrue(swapped.allSatisfy { $0.kind == .frame })

        // The preview matches the real result
        _ = await run("move-node-to-monitor right")
        try await rightVisible.layoutWorkspace()
        let real = try await one.getAxRect(.nonCancellable)
        assertEquals(real.map { [$0.minX, $0.minY, $0.width, $0.height] }, toMonitor.first.map { [$0.rect.minX, $0.rect.minY, $0.rect.width, $0.rect.height] })
    }
}
