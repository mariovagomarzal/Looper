@testable import AppBundle
import Common
import XCTest

@MainActor
final class NativeSpacesTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }
    override func tearDown() async throws { setUpWorkspacesForTests() }

    /// One display (the test monitor) with two desktops
    private func simulateSpaces(current: NativeSpaceId, spaces: [NativeSpaceId] = [1, 2]) {
        nativeSpacesForTests = NativeSpacesSnapshot(displays: [.init(id: "Main", currentSpace: current, userSpaces: spaces)])
        refreshNativeSpaces()
    }

    private var monitor: Monitor { mainMonitorInfo.toMonitorOrRearrangeMonitors() }

    func testEverySpaceHasItsOwnWorkspaces() {
        simulateSpaces(current: 1)
        let space1 = monitor.workspacesContainer(forSpace: 1)
        let space2 = monitor.workspacesContainer(forSpace: 2)
        let a1 = Workspace.get(byName: "a", in: space1)
        let a2 = Workspace.get(byName: "a", in: space2)
        XCTAssertTrue(a1 !== a2)
        XCTAssertTrue(Workspace.get(byName: "a", in: space1) === a1)
        assertEquals(a1.name, a2.name)
    }

    func testWorkspaceNamesResolveInFocusedSpace() async {
        simulateSpaces(current: 1)
        let space1 = monitor.workspacesContainer(forSpace: 1)
        assertTrue(Workspace.get(byName: "a", in: space1).focusWorkspace())

        _ = await WorkspaceCommand(args: WorkspaceCmdArgs(target: .direct(.parse("b").getOrDie()))).run(.defaultEnv, .emptyStdin)

        assertEquals(globalFocus.workspace.name, "b")
        XCTAssertTrue(globalFocus.workspace.workspacesContainer === space1)
        XCTAssertNil(monitor.workspacesContainer(forSpace: 2).workspace(named: "b"))
    }

    func testOnlyTheActiveSpaceIsVisible() {
        simulateSpaces(current: 1)
        let ws1 = monitor.workspacesContainer(forSpace: 1).visibleWorkspace
        let ws2 = monitor.workspacesContainer(forSpace: 2).visibleWorkspace
        XCTAssertTrue(ws1.isVisible)
        XCTAssertFalse(ws2.isVisible)
        XCTAssertTrue(ws2.isVisibleInItsSpace)
        XCTAssertTrue(mainMonitorInfo.visibleWorkspace === ws1)

        simulateSpaces(current: 2)
        XCTAssertFalse(ws1.isVisible)
        XCTAssertTrue(ws2.isVisible)
        XCTAssertTrue(mainMonitorInfo.visibleWorkspace === ws2)
    }

    func testFocusFollowsSpaceSwitch() {
        simulateSpaces(current: 1)
        let space1Workspace = Workspace.get(byName: "a", in: monitor.workspacesContainer(forSpace: 1))
        TestWindow.new(id: 1, parent: space1Workspace.rootTilingContainer)
        assertTrue(space1Workspace.focusWorkspace())
        let space2Workspace = Workspace.get(byName: "b", in: monitor.workspacesContainer(forSpace: 2))
        TestWindow.new(id: 2, parent: space2Workspace.rootTilingContainer)
        assertTrue(monitor.workspacesContainer(forSpace: 2).setVisibleWorkspace(space2Workspace))

        simulateSpaces(current: 2)
        moveFocusToActiveSpaceIfNeeded()

        XCTAssertTrue(globalFocus.workspace === space2Workspace)
        assertEquals(globalFocus.windowOrNil?.windowId, 2)
    }

    func testFocusStaysWhenSpacesDidNotChange() {
        simulateSpaces(current: 1)
        moveFocusToActiveSpaceIfNeeded() // Consume the change
        let inactive = Workspace.get(byName: "a", in: monitor.workspacesContainer(forSpace: 2))
        assertTrue(inactive.focusWorkspace())

        refreshNativeSpaces()
        moveFocusToActiveSpaceIfNeeded()

        XCTAssertTrue(globalFocus.workspace === inactive)
    }

    func testRemovedSpaceIsGarbageCollected() {
        simulateSpaces(current: 1)
        let removed = monitor.workspacesContainer(forSpace: 2)
        _ = Workspace.get(byName: "a", in: removed)
        assertTrue(monitor.activeWorkspacesContainer.visibleWorkspace.focusWorkspace())

        simulateSpaces(current: 1, spaces: [1])
        XCTAssertTrue(removed.isStale)
        Workspace.garbageCollectUnusedWorkspaces()

        XCTAssertFalse(monitor.workspacesContainers.contains { $0 === removed })
    }

    func testStaleSpaceWithWindowsIsKept() {
        simulateSpaces(current: 1)
        let removed = monitor.workspacesContainer(forSpace: 2)
        TestWindow.new(id: 1, parent: Workspace.get(byName: "a", in: removed).rootTilingContainer)
        assertTrue(monitor.activeWorkspacesContainer.visibleWorkspace.focusWorkspace())

        simulateSpaces(current: 1, spaces: [1])
        Workspace.garbageCollectUnusedWorkspaces()

        // Windows are moved out by reconcileWindowsWithNativeSpaces first
        XCTAssertTrue(monitor.workspacesContainers.contains { $0 === removed })
    }

    func testNewSpaceShowsFirstPersistentWorkspace() {
        config.persistentWorkspaces = ["1", "2", "Z"]
        simulateSpaces(current: 1)
        let container = monitor.workspacesContainer(forSpace: 2)
        Workspace.garbageCollectUnusedWorkspaces() // Creates persistent workspaces in every container

        assertEquals(container.visibleWorkspace.name, "1")
    }

    /// Regression: a window moved into a hidden Space used to get weight 1 next to a ~3000 points wide sibling
    func testWindowMovedIntoHiddenSpaceTakesWeightOfInvisibleSiblings() {
        let workspace = Workspace.get(byName: "a")
        let root = workspace.rootTilingContainer
        let existing = TestWindow.new(id: 1, parent: root, adaptiveWeight: 3000)
        existing.lifeStatus = .invisible // Windows of a Space that isn't shown

        let moved = TestWindow.new(id: 2, parent: root, adaptiveWeight: WEIGHT_AUTO)

        assertEquals(moved.getWeight(.h), 3000)
    }

    func testWithoutNativeSpacesEveryMonitorHasSingleContainer() {
        XCTAssertNil(nativeSpaces)
        XCTAssertNil(monitor.activeWorkspacesContainer.spaceId)
        XCTAssertTrue(monitor.activeWorkspacesContainer.isActive)
        assertEquals(monitor.workspacesContainers.count, 1)
    }
}
