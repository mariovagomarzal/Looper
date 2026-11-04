@testable import AppBundle
import Common
import XCTest

/// 'move' and 'resize' on floating windows, which change frames instead of the tree
@MainActor
final class FloatingMoveResizeTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private let area = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 600)
    private func parts(_ rect: Rect) -> [CGFloat] { [rect.minX, rect.minY, rect.width, rect.height] }
    private func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> Rect {
        Rect(topLeftX: x, topLeftY: y, width: width, height: height)
    }

    func testParseDistance() {
        func distance(_ command: String) -> MoveDistance? {
            guard case .cmd(let move as MoveCommand) = parseCommand(command).cmdOrDie else { return nil }
            return move.args.distance
        }
        XCTAssertNil(distance("move left"))
        assertEquals(distance("move left 40"), .points(40))
        assertEquals(distance("move --boundaries all-monitors-outer-frame up 10%"), .percent(10))
        XCTAssertNotNil(parseCommand("move left 0").errorOrNil)
        XCTAssertNotNil(parseCommand("move left far").errorOrNil)
        XCTAssertNotNil(parseCommand("move left 10 20").errorOrNil)
    }

    func testMovedFrame() {
        let window = rect(100, 100, 200, 100)
        // 5% of the width by default
        assertEquals(parts(movedFloatingFrame(window, .right, .default, area: area)), [150, 100, 200, 100])
        assertEquals(parts(movedFloatingFrame(window, .down, .percent(10), area: area)), [100, 160, 200, 100])
        assertEquals(parts(movedFloatingFrame(window, .left, .points(30), area: area)), [70, 100, 200, 100])
        // Stops at the edge
        assertEquals(parts(movedFloatingFrame(window, .left, .points(500), area: area)), [0, 100, 200, 100])
        assertEquals(parts(movedFloatingFrame(window, .right, .points(5000), area: area)), [800, 100, 200, 100])
        assertEquals(parts(movedFloatingFrame(rect(0, 0, 200, 100), .up, .default, area: area)), [0, 0, 200, 100])
        // A window beyond the edge isn't pulled back
        assertEquals(parts(movedFloatingFrame(rect(900, 0, 200, 100), .right, .default, area: area)), [900, 0, 200, 100])
    }

    func testEnteringFrame() {
        let next = rect(1000, 0, 500, 300)
        // Moving right enters the next monitor from its left edge, at the same relative height
        assertEquals(parts(enteringFloatingFrame(rect(800, 300, 200, 100), .right, from: area, to: next)), [1000, 150, 200, 100])
        // Bigger than the new area: shrunk to fit
        assertEquals(parts(enteringFloatingFrame(rect(200, 0, 800, 600), .right, from: area, to: next)), [1000, 0, 500, 300])
        assertEquals(parts(enteringFloatingFrame(rect(0, 0, 100, 100), .left, from: area, to: rect(-500, 0, 500, 600))), [-100, 0, 100, 100])
    }

    func testResizedFrame() {
        func resized(_ dimension: ResizeCmdArgs.Dimension, _ units: ResizeCmdArgs.Units, _ window: Rect? = nil) -> [CGFloat]? {
            resizedFloatingFrame(window ?? self.rect(300, 200, 200, 100), dimension, units, area: area).map(parts)
        }
        // From the center
        assertEquals(resized(.width, .add(100)), [250, 200, 300, 100])
        assertEquals(resized(.height, .subtract(40)), [300, 220, 200, 60])
        assertEquals(resized(.smart, .add(100)), [250, 150, 300, 200])
        assertEquals(resized(.smart, .set(400)), [200, 50, 400, 400])
        XCTAssertNil(resized(.smartOpposite, .add(100)))
        // Limits: a minimum size, and the area
        assertEquals(resized(.width, .subtract(1000)), [375, 200, 50, 100])
        assertEquals(resized(.width, .set(5000)), [0, 200, 1000, 100])
        // Growing past an edge pushes it back inside
        assertEquals(resized(.width, .add(100), rect(0, 0, 200, 100)), [0, 0, 300, 100])
        assertEquals(resized(.width, .add(100), rect(800, 0, 200, 100)), [700, 0, 300, 100])
        // Beyond the edge: it keeps that edge where it was and grows inwards
        assertEquals(resized(.width, .add(100), rect(-50, 0, 200, 100)), [-50, 0, 300, 100])
    }

    func testCommands() async throws {
        let workspace = Workspace.get(byName: "a")
        let tiled = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let floating = TestWindow.new(id: 2, parent: workspace.floatingWindowsContainer, rect: rect(100, 100, 200, 100))
        let area = workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps
        assertTrue(floating.focusWindow())

        assertEquals(await parseCommand("move right 40").cmdOrDie.run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
        assertEquals(try await floating.getAxRect(.nonCancellable).map(parts), [140, 100, 200, 100])
        assertEquals(await parseCommand("resize smart +100").cmdOrDie.run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
        assertEquals(try await floating.getAxRect(.nonCancellable).map(parts), [90, 50, 300, 200])
        assertTrue(floating.parent === workspace.floatingWindowsContainer)

        // At the edge, the boundaries action decides
        _ = await parseCommand("move left 5000").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(try await floating.getAxRect(.nonCancellable)?.minX, area.minX)
        assertEquals(await parseCommand("move left").cmdOrDie.run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
        let failed = await parseCommand("move --boundaries-action fail left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertNotEqual(failed.exitCode.rawValue, 0)
        let smartOpposite = await parseCommand("resize smart-opposite +10").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertNotEqual(smartOpposite.exitCode.rawValue, 0)

        // Distances are for floating windows only
        assertTrue(tiled.focusWindow())
        let result = await parseCommand("move left 40").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertNotEqual(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, ["A distance only applies to floating windows"])
    }

    func testPreview() async {
        let workspace = Workspace.get(byName: "a")
        _ = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let floating = TestWindow.new(id: 2, parent: workspace.floatingWindowsContainer, rect: rect(100, 100, 200, 100))
        assertTrue(floating.focusWindow())
        let move = await computeWheelPreview(parseCommand("move right 40").cmdOrDie, .defaultEnv, .all)
        assertEquals(move.map(\.windowId), [2])
        assertEquals(move.first.map { parts($0.rect) }, [140, 100, 200, 100])
        let resize = await computeWheelPreview(parseCommand("resize width -100").cmdOrDie, .defaultEnv, .target)
        assertEquals(resize.first.map { parts($0.rect) }, [150, 100, 100, 100])
        // Inside a shell, floating windows aren't simulated
        XCTAssertNil(simulateWheelPreview(parseCommand("move right 40 && move left").cmdOrDie, .defaultEnv, .all))
    }
}
