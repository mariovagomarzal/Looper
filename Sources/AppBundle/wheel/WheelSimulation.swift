import AppKit
import Common

// Previews of commands that rearrange the tiling tree. The command runs for real on the tree, the resulting window
// frames are computed without touching any window, and the tree is put back exactly as it was. Everything happens
// synchronously on the main actor, so no other code can observe the tree in between.

/// What an action would do to the windows of the visible workspaces. nil if the action can't be simulated
@MainActor func simulateWheelPreview(_ action: Shell<any Command>, _ env: CmdEnv, _ mode: WheelPreviewMode) -> [WheelPreviewItem]? {
    guard mode != .off, let first = action.flatten().first, first.isSimulatable else { return nil }
    let io = CmdIoImpl(stdin: .emptyStdin)
    // Commands may move windows between the workspaces of the active native Spaces of every monitor, and change which
    // one is visible. The snapshot covers all of them
    let containers = Monitor.all.map(\.activeWorkspacesContainer)
    let visibleBefore = containers.map(\.visibleWorkspace)
    let isCovered: (Workspace) -> Bool = { workspace in containers.contains { $0 === workspace.workspacesContainer } }
    // Commands that move a whole workspace act on every window of it, and may have no window at all
    let movesWorkspaces = first is MoveWorkspaceToMonitorCommand || first is SwapWorkspaceWithMonitorCommand
    let targetWindow = first.args.resolveTargetOrReportError(env, io)?.windowOrNil
    guard movesWorkspaces || targetWindow?.nodeWorkspace.map(isCovered) == true else { return nil }

    let before = layoutFrames(visibleBefore)
    let wasFloating = Set(visibleBefore.flatMap(\.floatingWindows).map(\.windowId))
    let snapshot = TreeSnapshot(containers)
    var isFloating = wasFloating
    let after: [OpaqueWindowId: Rect]? = withGlobalFocusRestored {
        guard simulate(action, env, io, isCovered) != nil else { return nil }
        let visibleAfter = containers.map(\.visibleWorkspace)
        var frames = layoutFrames(visibleAfter)
        let floating = visibleAfter.flatMap(\.floatingWindows)
        isFloating = Set(floating.map(\.windowId))
        // A tiling window that floats keeps its position and gets back its last floating size
        for window in floating where !wasFloating.contains(window.windowId) {
            guard let tile = before[window.windowId] else { continue }
            frames[window.windowId] = Rect(topLeftX: tile.minX, topLeftY: tile.minY, width: window.lastFloatingSize?.width ?? tile.width, height: window.lastFloatingSize?.height ?? tile.height)
        }
        return frames
    }
    snapshot.restore()
    guard let after else { return nil }

    let changed = after.keys.filter { id in before[id].map { !$0.isApproximatelyEqual(to: after[id]!) } ?? true }
    var items: [WheelPreviewItem] = []
    if movesWorkspaces {
        for id in changed.sorted(by: { $0.rawId < $1.rawId }) {
            items.append(WheelPreviewItem(windowId: id, rect: after[id]!, kind: .frame))
        }
        return items
    }
    guard let targetWindow else { return items }
    let switchedFloating = wasFloating.contains(targetWindow.windowId) != isFloating.contains(targetWindow.windowId)
    if let frame = after[targetWindow.windowId], changed.contains(targetWindow.windowId) || switchedFloating {
        items.append(WheelPreviewItem(windowId: targetWindow.windowId, rect: frame, kind: .frame))
    }
    if mode == .all {
        for id in changed.sorted(by: { $0.rawId < $1.rawId }) where id != targetWindow.windowId {
            items.append(WheelPreviewItem(windowId: id, rect: after[id]!, kind: .affected))
        }
    }
    return items
}

/// Runs the shell the way `Shell.run` does, normalizing the tree after every command. Returns whether it succeeded, or
/// nil if it reaches a command that can't run synchronously or that leaves the given workspaces
@MainActor private func simulate(_ shell: Shell<any Command>, _ env: CmdEnv, _ io: CmdIo, _ isCovered: (Workspace) -> Bool) -> Bool? {
    switch shell {
        case .empty:
            return true
        case .cmd(let command):
            // Floating windows move and resize by frame, which isn't part of the tree
            let byFrame = (command is MoveCommand || command is ResizeCommand) && isFloating(command.args, env, io)
            guard command.isSimulatable, !byFrame,
                  let workspace = command.args.resolveTargetOrReportError(env, io)?.workspace, isCovered(workspace),
                  let succeeded = applySynchronously(command, env, io)
            else { return nil }
            for workspace in Workspace.all where isCovered(workspace) { workspace.normalizeContainers() }
            return succeeded
        case .and(let shells):
            for shell in shells {
                guard let succeeded = simulate(shell, env, io, isCovered) else { return nil }
                if !succeeded { return false }
            }
            return true
        case .or(let shells):
            for shell in shells {
                guard let succeeded = simulate(shell, env, io, isCovered) else { return nil }
                if succeeded { return true }
            }
            return false
        case .seq(let shells):
            var succeeded = true
            for shell in shells {
                guard let it = simulate(shell, env, io, isCovered) else { return nil }
                succeeded = it
            }
            return succeeded
        case .pipe:
            return nil // Commands that change the tree don't read stdin
    }
}

extension Command {
    /// Commands that only change the tree of the workspace they act on, synchronously
    fileprivate var isSimulatable: Bool {
        switch self {
            case is MoveCommand, is SwapCommand, is LayoutCommand, is ResizeCommand, is BalanceSizesCommand,
                 is FlattenWorkspaceTreeCommand, is JoinWithCommand, is SplitCommand,
                 is MoveNodeToMonitorCommand, is MoveNodeToWorkspaceCommand,
                 is MoveWorkspaceToMonitorCommand, is SwapWorkspaceWithMonitorCommand: true
            default: false
        }
    }
}

/// Returns whether the command succeeded, or nil if it can't run synchronously
@MainActor private func applySynchronously(_ command: any Command, _ env: CmdEnv, _ io: CmdIo) -> Bool? {
    let exitCode: BinaryExitCode? = switch command {
        case let it as MoveCommand: it.apply(env, io)
        case let it as SwapCommand: it.apply(env, io)
        case let it as LayoutCommand: it.applySynchronously(env, io)
        case let it as ResizeCommand: it.apply(env, io)
        case let it as BalanceSizesCommand: it.run(env, io)
        case let it as FlattenWorkspaceTreeCommand: it.run(env, io)
        case let it as JoinWithCommand: it.run(env, io)
        case let it as SplitCommand: it.run(env, io)
        case let it as MoveNodeToMonitorCommand: it.run(env, io)
        case let it as MoveNodeToWorkspaceCommand: it.run(env, io)
        case let it as MoveWorkspaceToMonitorCommand: it.run(env, io)
        case let it as SwapWorkspaceWithMonitorCommand: it.run(env, io)
        default: nil
    }
    return exitCode.map { $0.rawValue == 0 }
}

// MARK: - Layout without side effects

/// The frames that the layout would give to the tiling windows of the workspaces. Mirrors `layoutWorkspace` without
/// touching windows or weights. `WheelSimulationTest` checks that both agree
@MainActor func layoutFrames(_ workspaces: [Workspace]) -> [OpaqueWindowId: Rect] {
    var result: [OpaqueWindowId: Rect] = [:]
    for workspace in workspaces where !workspace.isEffectivelyEmpty {
        let rect = workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps
        let context = FramesContext(workspace: workspace, gaps: ResolvedGaps(gaps: config.gaps, monitor: workspace.workspaceMonitorInfo))
        context.layout(workspace.rootTilingContainer, rect.topLeftCorner, width: rect.width, height: rect.height - 1, &result)
    }
    return result
}

private struct FramesContext {
    let workspace: Workspace
    let gaps: ResolvedGaps

    @MainActor func layout(_ node: TreeNode, _ point: CGPoint, width: CGFloat, height: CGFloat, _ result: inout [OpaqueWindowId: Rect]) {
        switch node.nodeCases {
            case .window(let window):
                if window.isFullscreen && window == workspace.rootTilingContainer.mostRecentWindowRecursive {
                    let monitor = workspace.workspaceMonitorInfo
                    result[window.windowId] = window.noOuterGapsInFullscreen ? monitor.visibleRect : monitor.visibleRectPaddedByOuterGaps
                } else {
                    result[window.windowId] = Rect(topLeftX: point.x, topLeftY: point.y, width: width, height: height)
                }
            case .tilingContainer(let container):
                switch container.layout {
                    case .tiles: layoutTiles(container, point, width: width, height: height, &result)
                    case .accordion: layoutAccordion(container, point, width: width, height: height, &result)
                }
            default:
                return
        }
    }

    @MainActor private func layoutTiles(_ container: TilingContainer, _ point: CGPoint, width: CGFloat, height: CGFloat, _ result: inout [OpaqueWindowId: Rect]) {
        let orientation = container.orientation
        let children = container.inhabitedChildren
        let weights = children.map { $0.getWeight(orientation) }
        guard let delta = ((orientation == .h ? width : height) - CGFloat(weights.reduce(0, +))).div(children.count) else { return }
        var point = point
        let rawGap = gaps.inner.get(orientation).toDouble()
        for (i, child) in children.enumerated() {
            let weight = weights[i] + delta
            let gap = rawGap - (i == 0 ? rawGap / 2 : 0) - (i == children.count - 1 ? rawGap / 2 : 0)
            layout(
                child,
                i == 0 ? point : point.addingOffset(orientation, rawGap / 2),
                width: orientation == .h ? weight - gap : width,
                height: orientation == .v ? weight - gap : height,
                &result,
            )
            point = orientation == .h ? point.addingXOffset(weight) : point.addingYOffset(weight)
        }
    }

    @MainActor private func layoutAccordion(_ container: TilingContainer, _ point: CGPoint, width: CGFloat, height: CGFloat, _ result: inout [OpaqueWindowId: Rect]) {
        let children = container.inhabitedChildren
        guard let mruIndex = container.mostRecentInhabitedChild?.ownIndex(in: .inhabitedOnly) else { return }
        let padding = CGFloat(config.accordionPadding)
        for (index, child) in children.enumerated() {
            let (lPadding, rPadding) = accordionPaddings(index, count: children.count, mruIndex: mruIndex, padding: padding)
            switch container.orientation {
                case .h: layout(child, point + CGPoint(x: lPadding, y: 0), width: width - rPadding - lPadding, height: height, &result)
                case .v: layout(child, point + CGPoint(x: 0, y: lPadding), width: width, height: height - lPadding - rPadding, &result)
            }
        }
    }
}

extension Rect {
    fileprivate func isApproximatelyEqual(to other: Rect) -> Bool {
        abs(minX - other.minX) < 0.5 && abs(minY - other.minY) < 0.5 && abs(width - other.width) < 0.5 && abs(height - other.height) < 0.5
    }
}

// MARK: - Snapshot

/// An exact copy of the state of some workspaces that commands may change: the tiling tree (the same node objects,
/// their order and weights, layouts and orientations), floating windows, MRU orders up to the monitor, the visible
/// workspace of their containers, and the fullscreen state of windows
@MainActor final class TreeSnapshot {
    private struct Binding {
        let node: TreeNode
        let parent: NonLeafTreeNodeObject
        let index: Int
        let weight: CGFloat
    }

    private struct ContainerState {
        let container: TilingContainer
        let orientation: Orientation
        let layout: Layout
        let lifeStatus: TilingContainerLifeStatus
    }

    private struct WindowState {
        let window: Window
        let isFullscreen: Bool
        let noOuterGapsInFullscreen: Bool
        let lastFloatingSize: CGSize?
    }

    private struct VisibleWorkspaces {
        let container: WorkspacesContainer
        let visible: String?
        let prevVisible: String?
    }

    private let workspaces: [Workspace]
    /// The workspaces of each container and the children of each workspace, to remove what is created meanwhile
    private let workspaceLists: [(container: WorkspacesContainer, workspaces: [Workspace])]
    private let workspaceChildren: [(workspace: Workspace, children: [TreeNode])]
    /// Floating, macOS fullscreen and hidden apps windows containers. Cleared on restore, like tiling containers
    private var leafContainers: [NonLeafTreeNodeObject] = []
    /// Parents first, children in order
    private var bindings: [Binding] = []
    private var containers: [ContainerState] = []
    private var windows: [WindowState] = []
    private var mruOrders: [(node: TreeNode, children: [TreeNode])] = []
    private var visibleWorkspaces: [VisibleWorkspaces] = []

    /// Every workspace of the containers. Workspaces created meanwhile are removed on restore
    convenience init(_ containers: [WorkspacesContainer]) {
        self.init(containers.flatMap(\.workspaces), containers: containers)
    }

    init(_ workspaces: [Workspace], containers: [WorkspacesContainer] = []) {
        self.workspaces = workspaces
        workspaceLists = containers.map { ($0, $0.workspaces) }
        workspaceChildren = workspaces.map { ($0, $0.children) }
        for container in containers {
            mruOrders.append((container, Array(container._mruChildren)))
            visibleWorkspaces.append(VisibleWorkspaces(
                container: container,
                visible: container.visibleWorkspaceNameOrStale,
                prevVisible: container.prevVisibleWorkspaceName,
            ))
            mruOrders.append((container.monitor, Array(container.monitor._mruChildren)))
        }
        // Taking the snapshot must not change anything, so only what exists is read (accessors like
        // `rootTilingContainer` create what is missing)
        for workspace in workspaces {
            if let root = workspace.children.first(where: { $0 is TilingContainer }) { capture(root) }
            let leafContainers = workspace.children.filter {
                $0 is FloatingWindowsContainer || $0 is MacosFullscreenWindowsContainer || $0 is MacosHiddenAppsWindowsContainer
            }
            for case let leafContainer as NonLeafTreeNodeObject in leafContainers {
                self.leafContainers.append(leafContainer)
                for (index, child) in leafContainer.children.enumerated() {
                    bindings.append(Binding(node: child, parent: leafContainer, index: index, weight: child.snapshotAdaptiveWeight))
                    if let window = child as? Window { captureWindow(window) }
                }
                mruOrders.append((leafContainer, Array(leafContainer._mruChildren)))
            }
            mruOrders.append((workspace, Array(workspace._mruChildren)))
            if let container = workspace.workspacesContainer, !containers.contains(where: { $0 === container }) {
                mruOrders.append((container, Array(container._mruChildren)))
                visibleWorkspaces.append(VisibleWorkspaces(
                    container: container,
                    visible: container.visibleWorkspaceNameOrStale,
                    prevVisible: container.prevVisibleWorkspaceName,
                ))
                let monitor = container.monitor
                mruOrders.append((monitor, Array(monitor._mruChildren)))
            }
        }
    }

    private func capture(_ node: TreeNode) {
        guard let parent = node.parent, let index = node.ownIndex(in: .all) else { return }
        bindings.append(Binding(node: node, parent: parent, index: index, weight: node.snapshotAdaptiveWeight))
        switch node.nodeCases {
            case .tilingContainer(let container):
                containers.append(ContainerState(container: container, orientation: container.orientation, layout: container.layout, lifeStatus: container.lifeStatus))
                mruOrders.append((container, Array(container._mruChildren)))
                for child in container.children { capture(child) }
            case .window(let window):
                captureWindow(window)
            default:
                break
        }
    }

    private func captureWindow(_ window: Window) {
        windows.append(WindowState(
            window: window,
            isFullscreen: window.isFullscreen,
            noOuterGapsInFullscreen: window.noOuterGapsInFullscreen,
            lastFloatingSize: window.lastFloatingSize,
        ))
    }

    func restore() {
        // Detach whatever tiling trees the workspaces have now (also the ones created meanwhile). Containers created
        // meanwhile stay detached and die
        for workspace in workspaces + workspaceLists.flatMap(\.container.workspaces) {
            for root in workspace.children.filterIsInstance(of: TilingContainer.self) {
                root.unbindFromParent()
            }
        }
        for container in leafContainers {
            for child in container.children { child.unbindFromParent() }
        }
        for state in containers {
            state.container.restoreSnapshotState(orientation: state.orientation, layout: state.layout, lifeStatus: state.lifeStatus)
            for child in state.container.children {
                child.unbindFromParent()
            }
        }
        // Parents are bound before their children, and siblings in order, so every index is valid when it's used
        for binding in bindings {
            binding.node.bind(to: binding.parent, adaptiveWeight: binding.weight, index: binding.index)
        }
        for (workspace, children) in workspaceChildren {
            for child in workspace.children where !children.contains(where: { $0 === child }) && child.children.isEmpty {
                child.unbindFromParent()
            }
        }
        for (container, workspaces) in workspaceLists {
            for workspace in container.workspaces where !workspaces.contains(workspace) && workspace.children.allSatisfy(\.children.isEmpty) {
                workspace.unbindFromParent()
            }
        }
        for (node, children) in mruOrders {
            for child in children.reversed() where child.parent === node {
                node._mruChildren.pushOrRaise(child)
            }
        }
        for state in windows {
            state.window.isFullscreen = state.isFullscreen
            state.window.noOuterGapsInFullscreen = state.noOuterGapsInFullscreen
            state.window.lastFloatingSize = state.lastFloatingSize
        }
        for state in visibleWorkspaces {
            state.container.visibleWorkspaceNameOrStale = state.visible
            state.container.prevVisibleWorkspaceName = state.prevVisible
        }
    }
}
