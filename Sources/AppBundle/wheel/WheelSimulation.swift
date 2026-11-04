import AppKit
import Common

// Previews of commands that rearrange the tiling tree. The command runs for real on the tree, the resulting window
// frames are computed without touching any window, and the tree is put back exactly as it was. Everything happens
// synchronously on the main actor, so no other code can observe the tree in between.

/// What an action would do to the windows of the visible workspaces. nil if the action can't be simulated
@MainActor func simulateWheelPreview(_ action: Shell<any Command>, _ env: CmdEnv, _ mode: WheelPreviewMode) -> [WheelPreviewItem]? {
    guard mode != .off, let first = action.flatten().first, first.isSimulatable else { return nil }
    let io = CmdIoImpl(stdin: .emptyStdin)
    let workspaces = Monitor.all.map(\.activeWorkspacesContainer.visibleWorkspace)
    // The snapshot only covers the visible workspaces
    guard let targetWindow = first.args.resolveTargetOrReportError(env, io)?.windowOrNil,
          let targetWorkspace = targetWindow.nodeWorkspace, workspaces.contains(targetWorkspace)
    else { return nil }

    let before = layoutFrames(workspaces)
    let wasFloating = Set(workspaces.flatMap(\.floatingWindows).map(\.windowId))
    let snapshot = TreeSnapshot(workspaces)
    var isFloating = wasFloating
    let after: [OpaqueWindowId: Rect]? = withGlobalFocusRestored {
        // Commands that touch other workspaces can't be simulated
        let simulated = simulate(action, env, io) { workspaces.contains($0) }
        guard simulated != nil else { return nil }
        var frames = layoutFrames(workspaces)
        isFloating = Set(workspaces.flatMap(\.floatingWindows).map(\.windowId))
        // A tiling window that floats keeps its position and gets back its last floating size
        for window in workspaces.flatMap(\.floatingWindows) where !wasFloating.contains(window.windowId) {
            guard let tile = before[window.windowId] else { continue }
            frames[window.windowId] = Rect(topLeftX: tile.minX, topLeftY: tile.minY, width: window.lastFloatingSize?.width ?? tile.width, height: window.lastFloatingSize?.height ?? tile.height)
        }
        return frames
    }
    snapshot.restore()
    guard let after else { return nil }

    let changed = after.keys.filter { id in before[id].map { !$0.isApproximatelyEqual(to: after[id]!) } ?? true }
    var items: [WheelPreviewItem] = []
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
            guard command.isSimulatable,
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
                 is FlattenWorkspaceTreeCommand, is JoinWithCommand, is SplitCommand: true
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
        case let it as ResizeCommand: it.run(env, io)
        case let it as BalanceSizesCommand: it.run(env, io)
        case let it as FlattenWorkspaceTreeCommand: it.run(env, io)
        case let it as JoinWithCommand: it.run(env, io)
        case let it as SplitCommand: it.run(env, io)
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
            let (lPadding, rPadding): (CGFloat, CGFloat) = switch index {
                case 0 where children.count == 1: (0, 0)
                case 0: (0, padding)
                case children.indices.last: (padding, 0)
                case mruIndex - 1: (0, 2 * padding)
                case mruIndex + 1: (2 * padding, 0)
                default: (padding, padding)
            }
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
    /// Parents first, children in order
    private var bindings: [Binding] = []
    private var containers: [ContainerState] = []
    private var windows: [WindowState] = []
    private var mruOrders: [(node: TreeNode, children: [TreeNode])] = []
    private var visibleWorkspaces: [VisibleWorkspaces] = []

    init(_ workspaces: [Workspace]) {
        self.workspaces = workspaces
        for workspace in workspaces {
            capture(workspace.rootTilingContainer)
            let floating = workspace.floatingWindowsContainer
            for (index, child) in floating.children.enumerated() {
                bindings.append(Binding(node: child, parent: floating, index: index, weight: child.snapshotAdaptiveWeight))
                if let window = child as? Window { captureWindow(window) }
            }
            mruOrders.append((floating, Array(floating._mruChildren)))
            mruOrders.append((workspace, Array(workspace._mruChildren)))
            if let container = workspace.workspacesContainer {
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
        // Detach whatever tiling trees the workspaces have now. Containers created meanwhile stay detached and die
        for workspace in workspaces {
            for root in workspace.children.filterIsInstance(of: TilingContainer.self) {
                root.unbindFromParent()
            }
        }
        for state in containers {
            state.container.restoreSnapshotState(orientation: state.orientation, layout: state.layout, lifeStatus: state.lifeStatus)
            for child in state.container.children {
                child.unbindFromParent()
            }
        }
        // Parents are bound before their children, and siblings in order, so every index is valid when it's used
        for binding in bindings {
            // Floating containers aren't cleared, so they may hold fewer windows than when they were captured
            let count = binding.parent.children.count - (binding.node.parent === binding.parent ? 1 : 0)
            binding.node.bind(to: binding.parent, adaptiveWeight: binding.weight, index: min(binding.index, count))
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
