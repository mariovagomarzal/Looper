import AppKit
import Common

struct MoveCommand: Command {
    let args: MoveCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let currentWindow = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        if await shouldFailBecauseFullscreen_nonCancellable(
            window: currentWindow,
            failIfFullscreen: args.failIfFullscreen,
            failIfMacosNativeFullscreen: args.failIfMacosNativeFullscreen,
        ) {
            return .fail
        }
        if case .floatingWindowsContainer = currentWindow.windowParentCases {
            switch await floatingMove(env, io) {
                case .exit(let exitCode):
                    return exitCode
                case .frame(let window, let frame):
                    window.isFullscreen = false
                    window.setAxFrame(frame.topLeftCorner, nil)
                    return .succ
                case .monitor(let window, let monitor, let frame):
                    let moveNodeToMonitorArgs = MoveNodeToMonitorCmdArgs(target: .direction(args.direction.val))
                        .with(\.windowId, .id(window.windowId))
                        .with(\.focusFollowsWindow, globalFocus.windowOrNil == window)
                    let exitCode = MoveNodeToMonitorCommand(args: moveNodeToMonitorArgs).run(env, io)
                    guard exitCode.rawValue == 0, window.nodeMonitorInfo?.rect.topLeftCorner == monitor.rect.topLeftCorner else { return exitCode }
                    window.isFullscreen = false
                    window.setAxFrame(frame.topLeftCorner, frame.size)
                    return .succ
            }
        }
        return apply(env, io)
    }

    enum FloatingMove {
        /// The window moves inside its monitor
        case frame(Window, Rect)
        /// The window enters the monitor next to its own from the edge it touches
        case monitor(Window, MonitorInfo, Rect)
        case exit(BinaryExitCode)
    }

    /// Where a floating window moves: the distance along the direction, without leaving the usable area of the monitor.
    /// At the edge, '--boundaries all-monitors-outer-frame' takes it to the next monitor. Shared with the wheel preview
    @MainActor func floatingMove(_ env: CmdEnv, _ io: CmdIo) async -> FloatingMove {
        let direction = args.direction.val
        guard let target = args.resolveTargetOrReportError(env, io), let window = target.windowOrNil else {
            return .exit(.fail(io.err(noWindowIsFocused)))
        }
        guard case .floatingWindowsContainer = window.windowParentCases else { return .exit(.fail(io.err(bugPrompt()))) }
        guard let rect = try? await window.getAxRect(.nonCancellable) else { return .exit(.fail(io.err("Can't read the frame of the window"))) }
        let monitor = target.workspace.workspaceMonitorInfo
        let area = monitor.visibleRectPaddedByOuterGaps
        let moved = movedFloatingFrame(rect, direction, args.distance ?? .default, area: area)
        if !moved.topLeftCorner.isApproximatelyEqual(to: rect.topLeftCorner) { return .frame(window, moved) }
        // Already at the edge
        if args.boundaries == .allMonitorsOuterFrame,
           let (monitors, index) = monitor.findRelativeMonitor(inDirection: direction),
           let next = monitors.getOrNil(atIndex: index)
        {
            return .monitor(window, next, enteringFloatingFrame(rect, direction, from: area, to: next.visibleRectPaddedByOuterGaps))
        }
        return switch args.boundariesAction {
            case .fail: .exit(.fail)
            case .stop, .createImplicitContainer: .exit(.succ)
        }
    }

    /// The tree change, without the asynchronous fullscreen checks. Synchronous, so that the wheel preview can simulate it
    @MainActor func apply(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        let direction = args.direction.val
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let currentWindow = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        switch currentWindow.windowParentCases {
            case nil: return .fail
            case .tilingContainer(let parent):
                guard let indexOfCurrent = currentWindow.ownIndex(in: .all) else { return .fail(io.err(bugPrompt())) }
                if args.distance != nil { return .fail(io.err("A distance only applies to floating windows")) }
                if parent.orientation == direction.orientation,
                   let siblingIndex = parent.inhabitedSiblingIndex(of: indexOfCurrent, in: direction)
                {
                    switch parent.children[siblingIndex].tilingTreeNodeCasesOrDie().resolvedThroughMustBeFlattenedRecursive() {
                        case .tilingContainer(let topLevelSiblingTargetContainer):
                            return deepMoveIn(window: currentWindow, into: topLevelSiblingTargetContainer, moveDirection: direction, io)
                        case .window: // "swap windows"
                            let prevBinding = currentWindow.unbindFromParent()
                            currentWindow.bind(to: parent, adaptiveWeight: prevBinding.adaptiveWeight, index: siblingIndex)
                            return .succ
                    }
                } else {
                    return moveOut(tilingWindow: currentWindow, direction: direction, io, args, env)
                }
            case .floatingWindowsContainer: // Moved by frame, asynchronously (see 'floatingMove')
                return .fail(io.err(bugPrompt()))
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
                return .fail(io.err(moveOutMacosUnconventionalWindow))
            case .macosPopupWindowsContainer:
                return .fail(io.err(bugPrompt())) // Impossible
        }
    }
}

/// The frame of a floating window moved by `distance`, stopping at the edge of the area. A window that is already beyond
/// the edge isn't pulled back
func movedFloatingFrame(_ rect: Rect, _ direction: CardinalDirection, _ distance: MoveDistance, area: Rect) -> Rect {
    let isHorizontal = direction.orientation == .h
    let step: CGFloat = switch distance {
        case .points(let points): CGFloat(points)
        case .percent(let percent): (isHorizontal ? area.width : area.height) * CGFloat(percent) / 100
    }
    let (start, size, areaStart, areaEnd) = isHorizontal
        ? (rect.minX, rect.width, area.minX, area.maxX)
        : (rect.minY, rect.height, area.minY, area.maxY)
    let newStart = direction.isPositive
        ? min(start + step, max(start, areaEnd - size))
        : max(start - step, min(start, areaStart))
    return isHorizontal
        ? Rect(topLeftX: newStart, topLeftY: rect.minY, width: rect.width, height: rect.height)
        : Rect(topLeftX: rect.minX, topLeftY: newStart, width: rect.width, height: rect.height)
}

/// The frame of a floating window that crosses into the next monitor: against the edge it comes through, at the same
/// relative position along that edge, and no bigger than the new area
func enteringFloatingFrame(_ rect: Rect, _ direction: CardinalDirection, from area: Rect, to newArea: Rect) -> Rect {
    let width = min(rect.width, newArea.width)
    let height = min(rect.height, newArea.height)
    func relative(_ value: CGFloat, _ start: CGFloat, _ length: CGFloat, _ newStart: CGFloat, _ newLength: CGFloat, _ size: CGFloat) -> CGFloat {
        let proportion = length > 0 ? (value - start) / length : 0
        return (newStart + proportion * newLength).coerce(in: newStart ... max(newStart, newStart + newLength - size))
    }
    return switch direction {
        case .left: Rect(topLeftX: newArea.maxX - width, topLeftY: relative(rect.minY, area.minY, area.height, newArea.minY, newArea.height, height), width: width, height: height)
        case .right: Rect(topLeftX: newArea.minX, topLeftY: relative(rect.minY, area.minY, area.height, newArea.minY, newArea.height, height), width: width, height: height)
        case .up: Rect(topLeftX: relative(rect.minX, area.minX, area.width, newArea.minX, newArea.width, width), topLeftY: newArea.maxY - height, width: width, height: height)
        case .down: Rect(topLeftX: relative(rect.minX, area.minX, area.width, newArea.minX, newArea.width, width), topLeftY: newArea.minY, width: width, height: height)
    }
}

extension CGPoint {
    fileprivate func isApproximatelyEqual(to other: CGPoint) -> Bool { abs(x - other.x) < 0.5 && abs(y - other.y) < 0.5 }
}

@MainActor private func hitWorkspaceBoundaries(
    _ window: Window,
    _ workspace: Workspace,
    _ io: CmdIo,
    _ args: MoveCmdArgs,
    _ direction: CardinalDirection,
    _ env: CmdEnv,
) -> BinaryExitCode {
    switch args.boundaries {
        case .workspace:
            switch args.boundariesAction {
                case .stop: return .succ
                case .fail: return .fail
                case .createImplicitContainer:
                    createImplicitContainerAndMoveWindow(window, workspace, direction)
                    return .succ
            }
        case .allMonitorsOuterFrame:
            guard let (monitors, index) = window.nodeMonitorInfo?.findRelativeMonitor(inDirection: direction) else {
                return .fail(io.err("Should never happen. Can't find the current monitor"))
            }

            if monitors.indices.contains(index) {
                let moveNodeToMonitorArgs = MoveNodeToMonitorCmdArgs(target: .direction(direction))
                    .with(\.windowId, .id(window.windowId))
                    .with(\.focusFollowsWindow, globalFocus.windowOrNil == window)

                return MoveNodeToMonitorCommand(args: moveNodeToMonitorArgs).run(env, io)
            } else {
                return hitAllMonitorsOuterFrameBoundaries(window, workspace, args, direction)
            }
    }
}

@MainActor private func hitAllMonitorsOuterFrameBoundaries(
    _ window: Window,
    _ workspace: Workspace,
    _ args: MoveCmdArgs,
    _ direction: CardinalDirection,
) -> BinaryExitCode {
    switch args.boundariesAction {
        case .stop: return .succ
        case .fail: return .fail
        case .createImplicitContainer:
            createImplicitContainerAndMoveWindow(window, workspace, direction)
            return .succ
    }
}

private let moveOutMacosUnconventionalWindow = "moving macOS fullscreen, minimized windows and windows of hidden apps isn't yet supported. This behavior is subject to change"

@MainActor private func moveOut(
    tilingWindow window: Window,
    direction: CardinalDirection,
    _ io: CmdIo,
    _ args: MoveCmdArgs,
    _ env: CmdEnv,
) -> BinaryExitCode {
    let proposedSibling = window.parents.first(where: { proposedSibling in
        return switch proposedSibling.parent?.cases {
            case .tilingContainer(let proposedParent):
                switch proposedParent.lifeStatus {
                    case .alive: proposedParent.orientation == direction.orientation
                    case .mustBeFlattened, .deadOrInvisible: false
                }
            // Stop searching: we have hit the workspace
            case nil, .workspace: true
            // Impossible: tilingContainer's parent can only be a workspace or tilingContainer
            case .floatingWindowsContainer,
                 .macosMinimizedWindowsContainer,
                 .monitor,
                 .workspacesContainer,
                 .macosFullscreenWindowsContainer,
                 .macosHiddenAppsWindowsContainer,
                 .macosPopupWindowsContainer: true
        }
    }) as? TilingContainer
    guard let proposedSibling else { return .fail(io.err(bugPrompt())) } // Impossible
    switch proposedSibling.tilingContainerParentCases {
        case .unbound: return .fail
        case .tilingContainer(let parent):
            check(parent.orientation == direction.orientation)
            guard let ownIndex = proposedSibling.ownIndex(in: .all) else { return .fail(io.err(bugPrompt())) }
            window.bind(to: parent, adaptiveWeight: WEIGHT_AUTO, index: ownIndex + direction.insertionOffset)
            return .succ
        case .workspace(let parent):
            return hitWorkspaceBoundaries(window, parent, io, args, direction, env)
    }
}

@MainActor private func createImplicitContainerAndMoveWindow(
    _ window: Window,
    _ workspace: Workspace,
    _ direction: CardinalDirection,
) {
    let prevRoot = workspace.rootTilingContainer
    prevRoot.unbindFromParent()
    // Force tiles layout
    _ = TilingContainer(parent: workspace, adaptiveWeight: WEIGHT_AUTO, direction.orientation, .tiles, index: 0)
    check(prevRoot != workspace.rootTilingContainer)
    prevRoot.bind(to: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: 0)
    window.bind(to: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: direction.insertionOffset)
}

@MainActor private func deepMoveIn(window: Window, into container: TilingContainer, moveDirection: CardinalDirection, _ io: CmdIo) -> BinaryExitCode {
    let deepTarget = container.tilingTreeNodeCasesOrDie().findDeepMoveInTargetRecursive(moveDirection.orientation)
    switch deepTarget {
        case .tilingContainer(let deepTarget):
            window.bind(to: deepTarget, adaptiveWeight: WEIGHT_AUTO, index: 0)
        case .window(let deepTarget):
            guard let (parent, deepTargetIndex) = deepTarget.nearestAliveTilingParent() else { return .fail(io.err(bugPrompt())) }
            window.bind(to: parent, adaptiveWeight: WEIGHT_AUTO, index: deepTargetIndex + 1)
    }
    return .succ
}

extension TilingTreeNodeCases {
    @MainActor fileprivate func findDeepMoveInTargetRecursive(_ orientation: Orientation) -> TilingTreeNodeCases {
        switch self {
            case .window:
                self
            case .tilingContainer(let container):
                switch container.lifeStatus {
                    case .alive where container.orientation == orientation:
                        .tilingContainer(container)
                    case .alive, .mustBeFlattened:
                        container.mostRecentInhabitedChild.orDie("Inhabited containers must have at least one inhabited child")
                            .tilingTreeNodeCasesOrDie()
                            .findDeepMoveInTargetRecursive(orientation)
                    case .deadOrInvisible:
                        die("Tombstone containers are skipped by the callers")
                }
        }
    }
}

func shouldFailBecauseFullscreen_nonCancellable(
    window: Window,
    failIfFullscreen: Bool,
    failIfMacosNativeFullscreen: Bool,
) async -> Bool {
    if failIfFullscreen && window.isFullscreen {
        return true
    }
    if failIfMacosNativeFullscreen {
        if true == (try? await window.isMacosFullscreen(.nonCancellable)) {
            return true
        }
    }
    return false
}
