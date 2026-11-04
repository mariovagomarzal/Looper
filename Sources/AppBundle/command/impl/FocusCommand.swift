import AppKit
import Common

struct FocusCommand: Command {
    let args: FocusCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        if let window = target.windowOrNil, await shouldFailBecauseFullscreen_nonCancellable(
            window: window,
            failIfFullscreen: args.failIfFullscreen,
            failIfMacosNativeFullscreen: args.failIfMacosNativeFullscreen,
        ) {
            return .fail
        }
        // todo bug: floating windows break mru
        let floatingWindows = args.floatingAsTiling ? await makeFloatingWindowsSeenAsTiling(workspace: target.workspace) : []
        defer {
            if args.floatingAsTiling {
                restoreFloatingWindows(floatingWindows: floatingWindows, workspace: target.workspace)
            }
        }

        switch destination(target, env, io) {
            case .window(let window):
                return .from(bool: window.focusWindow())
            case .workspace(let workspace, let raising):
                raising?.markAsMostRecentChild()
                return .from(bool: workspace.focusWorkspace())
            case .exit(let exitCode):
                return exitCode
        }
    }

    enum Destination {
        case window(Window)
        /// The workspace gets focus, with `raising` as its most recent window first
        case workspace(Workspace, raising: Window?)
        case exit(BinaryExitCode)
    }

    /// Where the focus goes, without moving it. Synchronous, so that the wheel preview can show it
    @MainActor func destination(_ target: LiveFocus, _ env: CmdEnv, _ io: CmdIo) -> Destination {
        switch args.target {
            case .direction(let direction):
                let window = target.windowOrNil
                if let (parent, _, neighborIndex) = window?.closestParent(hasInhabitedChildrenInDirection: direction, withLayout: nil) {
                    guard let windowToFocus = parent.children[neighborIndex]
                        .findInhabitedLeafWindowRecursive(snappedTo: direction.opposite) else { return .exit(.fail(io.err(bugPrompt()))) }
                    return .window(windowToFocus)
                } else {
                    return hitWorkspaceBoundaries(target, io, args, direction)
                }
            case .windowId(let windowTarget):
                guard let windowToFocus = windowTarget.resolveOrReportError(env, io) else { return .exit(.fail) }
                return .window(windowToFocus)
            case .dfsIndex(let dfsIndex):
                if let windowToFocus = target.workspace.rootTilingContainer.allInhabitedLeafWindowsRecursive.getOrNil(atIndex: Int(dfsIndex)) {
                    return .window(windowToFocus)
                } else {
                    return .exit(.fail(io.err("Can't find window with DFS index \(dfsIndex)")))
                }
            case .dfsRelative(let nextPrev):
                let windows = target.workspace.rootTilingContainer.allInhabitedLeafWindowsRecursive
                guard let currentIndex = windows.firstIndex(where: { $0 == target.windowOrNil }) else {
                    return .exit(.fail)
                }
                var targetIndex = switch nextPrev {
                    case .dfsNext: currentIndex + 1
                    case .dfsPrev: currentIndex - 1
                }
                if !(0 ..< windows.count).contains(targetIndex) {
                    switch args.boundariesAction {
                        case .stop: return .exit(.succ)
                        case .fail: return .exit(.fail)
                        case .wrapAroundTheWorkspace: targetIndex = (targetIndex + windows.count) % windows.count
                        case .wrapAroundAllMonitors: return .exit(.fail(io.err(bugPrompt("Must be discarded by args parser"))))
                    }
                }
                return .window(windows[targetIndex])
        }
    }
}

@MainActor private func hitWorkspaceBoundaries(
    _ target: LiveFocus,
    _ io: CmdIo,
    _ args: FocusCmdArgs,
    _ direction: CardinalDirection,
) -> FocusCommand.Destination {
    switch args.boundaries {
        case .workspace:
            return switch args.boundariesAction {
                case .stop: .exit(.succ)
                case .fail: .exit(.fail)
                case .wrapAroundTheWorkspace: wrapAroundTheWorkspace(target, io, direction)
                case .wrapAroundAllMonitors: .exit(.fail(io.err("Must be discarded by args parser")))
            }
        case .allMonitorsOuterFrame:
            let currentMonitor = target.workspace.workspaceMonitorInfo
            guard let (monitors, index) = currentMonitor.findRelativeMonitor(inDirection: direction) else {
                return .exit(.fail(io.err(bugPrompt("Should never happen. Can't find the current monitor"))))
            }

            if let targetMonitor = monitors.getOrNil(atIndex: index) {
                return .workspace(targetMonitor.visibleWorkspace, raising: nil)
            } else {
                guard let wrapped = monitors.get(wrappingIndex: index) else { return .exit(.fail(io.err(bugPrompt("\(index) \(monitors)")))) }
                return hitAllMonitorsOuterFrameBoundaries(target, io, args, direction, wrapped)
            }
    }
}

@MainActor private func hitAllMonitorsOuterFrameBoundaries(
    _ target: LiveFocus,
    _ io: CmdIo,
    _ args: FocusCmdArgs,
    _ direction: CardinalDirection,
    _ wrappedMonitor: MonitorInfo,
) -> FocusCommand.Destination {
    switch args.boundariesAction {
        case .stop:
            return .exit(.succ)
        case .fail:
            return .exit(.fail)
        case .wrapAroundTheWorkspace:
            return wrapAroundTheWorkspace(target, io, direction)
        case .wrapAroundAllMonitors:
            let workspace = wrappedMonitor.visibleWorkspace
            return .workspace(workspace, raising: workspace.findInhabitedLeafWindowRecursive(snappedTo: direction.opposite))
    }
}

@MainActor private func wrapAroundTheWorkspace(_ target: LiveFocus, _ io: CmdIo, _ direction: CardinalDirection) -> FocusCommand.Destination {
    guard let windowToFocus = target.workspace.findInhabitedLeafWindowRecursive(snappedTo: direction.opposite) else {
        return .exit(.fail(io.err(noWindowIsFocused)))
    }
    return .window(windowToFocus)
}

@MainActor private func makeFloatingWindowsSeenAsTiling(workspace: Workspace) async -> [FloatingWindowData] {
    makeFloatingWindowsSeenAsTiling(await FloatingAsTilingPlan(workspace))
}

/// Where each floating window of a workspace goes when floating windows are seen as tiling ones. Reading the frames
/// is asynchronous, binding the windows (`makeFloatingWindowsSeenAsTiling`) isn't, so that the wheel preview can
/// simulate it
struct FloatingAsTilingPlan {
    fileprivate struct Item {
        let window: Window
        let center: CGPoint
        /// The tiling window under the center of the floating window, with its own center
        let target: (window: Window, center: CGPoint)?
    }

    fileprivate let workspace: Workspace
    fileprivate let items: [Item]

    @MainActor init(_ workspace: Workspace) async {
        self.workspace = workspace
        var items: [Item] = []
        for window in workspace.floatingWindows {
            // todo bug: we shouldn't access ax api here. What if the window was moved but it wasn't committed to ax yet?
            guard let center = try? await window.getCenter(.nonCancellable) else { continue }
            if let target = center.coerce(in: workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps)?
                .findWindowRecursively(in: workspace.rootTilingContainer, virtual: true, fullscreenCoversAll: false)
            {
                guard let targetCenter = try? await target.getCenter(.nonCancellable) else { continue }
                items.append(Item(window: window, center: center, target: (target, targetCenter)))
            } else {
                items.append(Item(window: window, center: center, target: nil))
            }
        }
        self.items = items
    }
}

@MainActor @discardableResult
func makeFloatingWindowsSeenAsTiling(_ plan: FloatingAsTilingPlan) -> [FloatingWindowData] {
    let workspace = plan.workspace
    let mruBefore = workspace.mostRecentWindowRecursive
    defer {
        mruBefore?.markAsMostRecentChild()
    }
    var _floatingWindows: [FloatingWindowData] = []
    // The tree may have changed while the frames were read
    for item in plan.items where item.window.parent === workspace.floatingWindowsContainer {
        let window = item.window
        let center = item.center
        let tilingParent: TilingContainer
        let index: Int
        if let (target, targetCenter) = item.target {
            guard let _tilingParent = target.parent as? TilingContainer, _tilingParent.nodeWorkspace === workspace else { continue }
            tilingParent = _tilingParent
            index = switch tilingParent.layout {
                case .tiles:
                    center.getProjection(tilingParent.orientation) >= targetCenter.getProjection(tilingParent.orientation)
                        ? target.ownIndex(in: .all).orDie() + 1
                        : target.ownIndex(in: .all).orDie()
                case .accordion:
                    center.getProjection(tilingParent.orientation) >= targetCenter.getProjection(tilingParent.orientation)
                        ? tilingParent.children.count
                        : 0
            }
        } else {
            index = 0
            tilingParent = workspace.rootTilingContainer
        }

        let data = window.unbindFromParent()
        let floatingWindowData = FloatingWindowData(
            window: window,
            center: center,
            tilingParent: tilingParent,
            adaptiveWeight: data.adaptiveWeight,
            index: index,
        )
        _floatingWindows.append(floatingWindowData)
    }
    let floatingWindows: [FloatingWindowData] = _floatingWindows.sortedBy { $0.center.getProjection($0.tilingParent.orientation) }.reversed()

    for floating in floatingWindows { // Make floating windows be seen as tiling
        floating.window.bind(to: floating.tilingParent, adaptiveWeight: 1, index: floating.index)
    }
    return floatingWindows
}

@MainActor private func restoreFloatingWindows(floatingWindows: [FloatingWindowData], workspace: Workspace) {
    let mruBefore = workspace.mostRecentWindowRecursive
    defer {
        mruBefore?.markAsMostRecentChild()
    }
    for floating in floatingWindows {
        floating.window.bind(to: workspace.floatingWindowsContainer, adaptiveWeight: floating.adaptiveWeight, index: INDEX_BIND_LAST)
    }
}

struct FloatingWindowData {
    let window: Window
    let center: CGPoint

    let tilingParent: TilingContainer
    let adaptiveWeight: CGFloat
    let index: Int
}

extension TreeNode {
    @MainActor func findInhabitedLeafWindowRecursive(snappedTo direction: CardinalDirection) -> Window? {
        switch nodeCases {
            case .workspace(let workspace):
                return workspace.rootTilingContainer.findInhabitedLeafWindowRecursive(snappedTo: direction)
            case .window(let window):
                return window.lifeStatus.isInhabited ? window : nil
            case .tilingContainer(let container):
                if direction.orientation == container.orientation {
                    return (direction.isPositive ? container.inhabitedChildren.last : container.inhabitedChildren.first)?
                        .findInhabitedLeafWindowRecursive(snappedTo: direction)
                } else {
                    return container.mostRecentInhabitedChild?.findInhabitedLeafWindowRecursive(snappedTo: direction)
                }
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
                 .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer,
                 .monitor, .workspacesContainer,
                 .floatingWindowsContainer:
                die("Impossible")
        }
    }
}
