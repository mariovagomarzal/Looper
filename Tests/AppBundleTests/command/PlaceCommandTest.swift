@testable import AppBundle
import Common
import XCTest

@MainActor
final class PlaceCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        testParseSingleCommandSucc("place left-half", PlaceCmdArgs(rawArgs: []).with(\.placement, .initialized(.preset(.leftHalf))))
        testParseSingleCommandSucc(
            "place --window-id pointer rect 10 20 30 40",
            PlaceCmdArgs(rawArgs: [])
                .with(\.placement, .initialized(.rect(x: 10, y: 20, width: 30, height: 40)))
                .with(\.windowId, .pointer),
        )
        XCTAssertNotNil(parseCommand("place sideways").errorOrNil)
        XCTAssertNotNil(parseCommand("place rect 10 20").errorOrNil)
        XCTAssertNotNil(parseCommand("place rect 50 0 60 100").errorOrNil) // Doesn't fit
    }

    private let area = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 600)
    private let gaps = CGSize(width: 10, height: 20)

    private func parts(_ rect: Rect) -> [CGFloat] { [rect.minX, rect.minY, rect.width, rect.height] }

    private func frame(_ placement: Placement, currentSize: CGSize? = nil) -> Rect? {
        placementFrame(placement, area: area, innerGaps: gaps, currentSize: currentSize)
    }

    func testFramesLeaveInnerGapsBetweenRegions() {
        assertEquals(frame(.preset(.leftHalf)).map(parts), [0, 0, 495, 600])
        assertEquals(frame(.preset(.rightHalf)).map(parts), [505, 0, 495, 600])
        assertEquals(frame(.preset(.bottomRightQuarter)).map(parts), [505, 310, 495, 290])
        assertEquals(frame(.preset(.maximize)).map(parts), parts(area))
        let centerThird = frame(.preset(.centerThird))
        XCTAssertEqual(centerThird?.minX ?? 0, 1000.0 / 3 + 5, accuracy: 0.001)
        XCTAssertEqual(centerThird?.maxX ?? 0, 2000.0 / 3 - 5, accuracy: 0.001)
        assertEquals(frame(.rect(x: 0, y: 0, width: 50, height: 100)).map(parts), frame(.preset(.leftHalf)).map(parts))
    }

    func testCenterAndAlmostMaximize() {
        assertEquals(frame(.preset(.center), currentSize: CGSize(width: 200, height: 100)).map(parts), [400, 250, 200, 100])
        // Bigger than the area: shrunk to fit
        assertEquals(frame(.preset(.center), currentSize: CGSize(width: 2000, height: 100)).map(parts), [0, 250, 1000, 100])
        XCTAssertNil(frame(.preset(.center)))
        assertEquals(frame(.preset(.almostMaximize)).map(parts), [50, 30, 900, 540])
    }

    func testOnlyFloatingWindows() async {
        let workspace = Workspace.get(byName: "a")
        let tiled = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let floating = TestWindow.new(id: 2, parent: workspace.floatingWindowsContainer, rect: Rect(topLeftX: 0, topLeftY: 0, width: 100, height: 100))
        assertTrue(tiled.focusWindow())

        let result = await parseCommand("place left-half").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        XCTAssertTrue(result.stderr.first?.hasPrefix("'place' only works with floating windows") == true)

        assertEquals(await parseCommand("place --window-id 2 maximize").cmdOrDie.run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
        let placed = try? await floating.getAxRect(.nonCancellable)
        assertEquals(placed.map(parts), parts(workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps))
    }
}
