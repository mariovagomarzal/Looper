@testable import AppBundle
import Common
import XCTest

@MainActor
final class WheelSimulationTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        config.gaps = parseConfig("gaps.inner.horizontal = 10\ngaps.inner.vertical = 6\ngaps.outer.left = 8\ngaps.outer.top = 4").config.gaps
    }

    override func tearDown() async throws { setUpWorkspacesForTests() }

    /// [1, v_tiles[2, 3], v_accordion[4, 5, 6]] with uneven weights, focused on 1
    private func makeTree() -> Workspace {
        let workspace = Workspace.get(byName: "a")
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0, adaptiveWeight: 300)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 500, index: INDEX_BIND_LAST).apply {
                TestWindow.new(id: 2, parent: $0, adaptiveWeight: 100)
                TestWindow.new(id: 3, parent: $0, adaptiveWeight: 300)
            }
            TilingContainer(parent: $0, adaptiveWeight: 200, .v, .accordion, index: INDEX_BIND_LAST).apply {
                TestWindow.new(id: 4, parent: $0)
                TestWindow.new(id: 5, parent: $0)
                TestWindow.new(id: 6, parent: $0)
            }
        }
        TestWindow.new(id: 7, parent: workspace.floatingWindowsContainer, rect: Rect(topLeftX: 1, topLeftY: 2, width: 3, height: 4))
        assertTrue((Window.get(byId: 5) ?? dieT()).focusWindow())
        assertTrue((Window.get(byId: 1) ?? dieT()).focusWindow())
        return workspace
    }

    private func frames(_ ids: [OpaqueWindowId]) async -> [OpaqueWindowId: [CGFloat]] {
        var result: [OpaqueWindowId: [CGFloat]] = [:]
        for id in ids {
            if let rect = try? await Window.get(byId: id)?.getAxRect(.nonCancellable) {
                result[id] = [rect.minX, rect.minY, rect.width, rect.height].map { ($0 * 100).rounded() / 100 }
            }
        }
        return result
    }

    private func rounded(_ frames: [OpaqueWindowId: Rect]) -> [OpaqueWindowId: [CGFloat]] {
        frames.mapValues { rect in [rect.minX, rect.minY, rect.width, rect.height].map { ($0 * 100).rounded() / 100 } }
    }

    func testFramesMatchTheRealLayout() async throws {
        let workspace = makeTree()
        let computed = rounded(layoutFrames([workspace]))
        try await workspace.layoutWorkspace()
        assertEquals(computed, await frames([1, 2, 3, 4, 5, 6]))

        // Once more after a layout change, with stable weights
        workspace.rootTilingContainer.layout = .accordion
        let computedAccordion = rounded(layoutFrames([workspace]))
        try await workspace.layoutWorkspace()
        assertEquals(computedAccordion, await frames([1, 2, 3, 4, 5, 6]))
    }

    /// Everything that a simulation could change, with node identities
    private func state(_ workspace: Workspace) -> String {
        func describe(_ node: TreeNode) -> String {
            let id = ObjectIdentifier(node).hashValue
            let mru = node._mruChildren.map { String(ObjectIdentifier($0).hashValue) }.joined(separator: ",")
            let children = node.children.map(describe).joined(separator: " ")
            let extra = switch node.nodeCases {
                case .tilingContainer(let c): "\(c.layout) \(c.orientation) \(c.lifeStatus)"
                case .window(let w): "\(w.windowId) fs=\(w.isFullscreen)"
                default: ""
            }
            return "(\(id) \(extra) w=\(node.snapshotAdaptiveWeight) mru=[\(mru)] \(children))"
        }
        let container = workspace.workspacesContainer
        return describe(workspace) +
            " focus=\(globalFocus.windowOrNil?.windowId.description ?? "-")/\(globalFocus.workspace.name)" +
            " visible=\(container?.visibleWorkspaceNameOrStale ?? "-") prev=\(container?.prevVisibleWorkspaceName ?? "-")" +
            " containerMru=\(container.map { $0._mruChildren.map { String(ObjectIdentifier($0).hashValue) } } ?? [])"
    }

    func testSimulationLeavesNoTrace() {
        let commands = [
            "move left", "move right", "move up", "move down",
            "swap right", "swap left --swap-focus",
            "layout accordion horizontal vertical", "layout h_tiles", "layout --root v_accordion",
            "join-with right", "split vertical", "resize smart +100", "flatten-workspace-tree", "balance-sizes",
            "move right && move right && layout accordion",
            "move --window-id 3 left", "swap --window-id 5 up",
            "layout floating", "layout tiling --window-id 7", "layout floating tiling --window-id 4",
            "move left || move right", "move up; move right", "swap right && move down || layout v_accordion",
            "join-with right && layout accordion", "layout tiles; flatten-workspace-tree",
        ]
        let workspace = makeTree()
        let initial = state(workspace)
        for command in commands {
            let shell = parseCommand(command).cmdOrDie
            _ = simulateWheelPreview(shell, .defaultEnv, .all)
            assertEquals(state(workspace), initial, additionalMsg: "after simulating '\(command)'")
        }
    }

    func testPreviewMatchesTheRealResult() async throws {
        for command in ["move right", "swap right", "layout accordion horizontal vertical", "join-with right", "move up && layout v_accordion"] {
            setUpWorkspacesForTests()
            let workspace = makeTree()
            try await workspace.layoutWorkspace()
            let preview = simulateWheelPreview(parseCommand(command).cmdOrDie, .defaultEnv, .all) ?? []

            _ = await parseCommand(command).cmdOrDie.run(.defaultEnv, .emptyStdin)
            try await workspace.layoutWorkspace()
            let real = await frames([1, 2, 3, 4, 5, 6])

            XCTAssertFalse(preview.isEmpty, command)
            assertEquals(preview.first?.windowId, 1, additionalMsg: command) // The target goes first
            for item in preview {
                assertEquals(rounded([item.windowId: item.rect])[item.windowId], real[item.windowId], additionalMsg: "\(command): window \(item.windowId)")
            }
        }
    }

    /// The preview shows exactly the windows that the real action moves or resizes, where it puts them
    func testPreviewMatchesTheRealResultForShells() async throws {
        let commands = [
            "move left || move right", "move up; move right", "swap right && move down || layout v_accordion",
            "join-with right && layout accordion", "layout tiles; flatten-workspace-tree", "move left && move left",
            "layout floating", "layout tiling --window-id 7", "join-with right", "move right && move right && layout accordion",
        ]
        for command in commands {
            setUpWorkspacesForTests()
            let workspace = makeTree()
            (Window.get(byId: 1) ?? dieT()).lastFloatingSize = CGSize(width: 400, height: 300)
            try await workspace.layoutWorkspace()
            let before = await frames([1, 2, 3, 4, 5, 6, 7])
            let preview = simulateWheelPreview(parseCommand(command).cmdOrDie, .defaultEnv, .all) ?? []

            _ = await parseCommand(command).cmdOrDie.run(.defaultEnv, .emptyStdin)
            try await workspace.layoutWorkspace()
            let real = await frames([1, 2, 3, 4, 5, 6, 7])

            let changed = Set(real.keys.filter { real[$0] != before[$0] })
            assertEquals(Set(preview.map(\.windowId)), changed, additionalMsg: command)
            for item in preview {
                assertEquals(rounded([item.windowId: item.rect])[item.windowId], real[item.windowId], additionalMsg: "\(command): window \(item.windowId)")
            }
        }
    }

    /// The outlined window is the one that really gets focus, also when floating windows are seen as tiling ones
    func testFocusPreviewMatchesTheRealFocus() async throws {
        let commands = [
            "focus right", "focus left", "focus down", "focus up", "focus --ignore-floating left",
            "focus --boundaries-action wrap-around-the-workspace left", "focus dfs-next", "focus --window-id 5",
            "focus --boundaries all-monitors-outer-frame left",
        ]
        for command in commands {
            setUpWorkspacesForTests()
            let workspace = makeTree()
            try await workspace.layoutWorkspace()
            let preview = await computeWheelPreview(parseCommand(command).cmdOrDie, .defaultEnv, .target)
            _ = await parseCommand(command).cmdOrDie.run(.defaultEnv, .emptyStdin)
            let focused = globalFocus.windowOrNil?.windowId
            assertEquals(preview.map(\.windowId), focused == 1 ? [] : [focused].compactMap { $0 }, additionalMsg: command)
        }
    }

    func testPreviewModes() {
        let workspace = makeTree()
        _ = workspace
        let move = parseCommand("move right").cmdOrDie
        let target = simulateWheelPreview(move, .defaultEnv, .target) ?? []
        let all = simulateWheelPreview(move, .defaultEnv, .all) ?? []
        assertEquals(target.map(\.windowId), [1])
        assertEquals(target.map(\.kind), [.frame])
        XCTAssertTrue(all.count > 1)
        XCTAssertTrue(all.dropFirst().allSatisfy { $0.kind == .affected })
        XCTAssertNil(simulateWheelPreview(move, .defaultEnv, .off))
        // Unsupported commands and shells
        XCTAssertNil(simulateWheelPreview(parseCommand("workspace b").cmdOrDie, .defaultEnv, .all))
        XCTAssertNil(simulateWheelPreview(parseCommand("move right | move left").cmdOrDie, .defaultEnv, .all))
        XCTAssertNil(simulateWheelPreview(parseCommand("move right && workspace b").cmdOrDie, .defaultEnv, .all))
        // Unless the unsupported command doesn't run
        XCTAssertNotNil(simulateWheelPreview(parseCommand("move right || workspace b").cmdOrDie, .defaultEnv, .all))
        // A window that floats is outlined even if it keeps its frame
        assertEquals(simulateWheelPreview(parseCommand("layout floating").cmdOrDie, .defaultEnv, .target)?.map(\.windowId), [1])
    }
}
