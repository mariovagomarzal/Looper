import AppKit
import Common

// Workspace names belong to a monitor (and native Space), and with persistent workspaces every monitor has its own
// copies. So moving a workspace to another monitor moves what it holds into the workspace of the same name there.

struct MoveWorkspaceToMonitorCommand: Command {
    let args: MoveWorkspaceToMonitorCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let source = args.resolveTargetOrReportError(env, io)?.workspace else { return .fail }
        guard let targetContainer = args.target.val.resolveWorkspacesContainer(
            relativeTo: source.workspaceMonitorInfo,
            wrapAround: args.wrapAround,
            env,
            io,
        ) else { return .fail }
        if targetContainer === source.workspacesContainer {
            return .fail(io.err("Workspace '\(source.name)' is already on that monitor"))
        }
        let target = Workspace.get(byName: source.name, in: targetContainer)
        // A non-empty target keeps its windows, and the moved ones join them
        WorkspaceContents(takingFrom: source).put(into: target)
        return .from(bool: target.focusWorkspace())
    }
}

struct SwapWorkspaceWithMonitorCommand: Command {
    let args: SwapWorkspaceWithMonitorCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        let focus = globalFocus
        let source = focus.workspace
        guard let targetContainer = args.target.val.resolveWorkspacesContainer(
            relativeTo: source.workspaceMonitorInfo,
            wrapAround: args.wrapAround,
            env,
            io,
        ) else { return .fail }
        if targetContainer === source.workspacesContainer {
            return .fail(io.err("The focused workspace is already on that monitor"))
        }
        let target = targetContainer.visibleWorkspace
        let fromSource = WorkspaceContents(takingFrom: source)
        let fromTarget = WorkspaceContents(takingFrom: target)
        fromSource.put(into: target)
        fromTarget.put(into: source)
        // The focus follows what it was on
        if let window = focus.windowOrNil { return .from(bool: window.focusWindow()) }
        return .from(bool: target.focusWorkspace())
    }
}

/// Everything a workspace holds, taken out of it to be put into another one
@MainActor
private struct WorkspaceContents {
    private let tiling: [(node: TreeNode, weight: CGFloat)]
    private let orientation: Orientation
    private let layout: Layout
    private let floating: [Window]
    private let macosFullscreen: [Window]
    private let macosHiddenApps: [Window]
    private let mostRecentWindow: Window?
    /// To scale the sizes of the tiling tree to the new monitor
    private let area: Rect

    init(takingFrom workspace: Workspace) {
        let root = workspace.rootTilingContainer
        orientation = root.orientation
        layout = root.layout
        area = workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps
        mostRecentWindow = workspace.mostRecentWindowRecursive
        tiling = root.children.map { child in
            let weight = child.getWeight(root.orientation)
            child.unbindFromParent()
            return (child, weight)
        }
        floating = workspace.floatingWindows
        macosFullscreen = workspace.macOsNativeFullscreenWindowsContainer.children.filterIsInstance(of: Window.self)
        macosHiddenApps = workspace.macOsNativeHiddenAppsWindowsContainer.children.filterIsInstance(of: Window.self)
        for window in floating + macosFullscreen + macosHiddenApps { window.unbindFromParent() }
    }

    func put(into workspace: Workspace) {
        let newArea = workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps
        let scale = (h: area.width > 0 ? newArea.width / area.width : 1, v: area.height > 0 ? newArea.height / area.height : 1)
        let root = workspace.rootTilingContainer
        let parent: TilingContainer
        if root.children.isEmpty {
            root.restoreSnapshotState(orientation: orientation, layout: layout, lifeStatus: root.lifeStatus)
            parent = root
        } else {
            parent = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, orientation, layout, index: INDEX_BIND_LAST)
        }
        for (node, weight) in tiling {
            node.bind(to: parent, adaptiveWeight: weight * (orientation == .h ? scale.h : scale.v), index: INDEX_BIND_LAST)
            (node as? TilingContainer)?.scaleWeightsRecursive(scale)
        }
        // Floating windows are moved to the new monitor by the layout, keeping their relative position
        for window in floating { window.bind(to: workspace.floatingWindowsContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST) }
        for window in macosFullscreen {
            window.bind(to: workspace.macOsNativeFullscreenWindowsContainer, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST)
        }
        for window in macosHiddenApps {
            window.bind(to: workspace.macOsNativeHiddenAppsWindowsContainer, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST)
        }
        mostRecentWindow?.markAsMostRecentChild()
    }
}

extension TilingContainer {
    /// Sizes are in points, so a tree that moves to a monitor of another size keeps its proportions this way
    @MainActor fileprivate func scaleWeightsRecursive(_ scale: (h: CGFloat, v: CGFloat)) {
        for child in children {
            child.setWeight(orientation, child.getWeight(orientation) * (orientation == .h ? scale.h : scale.v))
            (child as? TilingContainer)?.scaleWeightsRecursive(scale)
        }
    }
}
