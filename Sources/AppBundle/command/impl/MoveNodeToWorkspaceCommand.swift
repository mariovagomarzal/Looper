import Common

struct MoveNodeToWorkspaceCommand: Command {
    let args: MoveNodeToWorkspaceCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
        let subjectWs = window.nodeWorkspace
        let container: WorkspacesContainer
        if let monitor = args.targetMonitor {
            let windowMonitor = subjectWs?.workspaceMonitorInfo ?? globalFocus.workspace.workspaceMonitorInfo
            guard let it = monitor.resolveWorkspacesContainer(relativeTo: windowMonitor, env, io) else { return .fail }
            container = it
        } else {
            // The workspaces of the window's monitor and native Space
            container = subjectWs?.workspacesContainer ?? focusedWorkspacesContainer
        }
        let targetWorkspace: Workspace
        switch args.target.val {
            case .relative(let nextPrev):
                guard let subjectWs else { return .fail(io.err("Window \(window.windowId) doesn't belong to any workspace")) }
                // On another monitor, next and prev are relative to its visible workspace
                let current = args.targetMonitor == nil ? subjectWs : container.visibleWorkspace
                let ws = getNextPrevWorkspace(
                    current: current,
                    isNext: nextPrev == .next,
                    wrapAround: args.wrapAround,
                    stdin: args.useStdin ? io.readStdin() : nil,
                    target: args.targetMonitor == nil ? target : current.toLiveFocus(),
                )
                guard let ws = ws.getOrNil(appendErrorTo: &io.stderr) else { return .fail }
                targetWorkspace = ws
            case .direct(let name):
                targetWorkspace = Workspace.get(byName: name.raw, in: container)
        }
        return moveWindowToWorkspace(window, targetWorkspace, io, focusFollowsWindow: args.focusFollowsWindow, failIfNoop: args.failIfNoop)
    }
}

@MainActor
func moveWindowToWorkspace(_ window: Window, _ targetWorkspace: Workspace, _ io: CmdIo, focusFollowsWindow: Bool, failIfNoop: Bool, index: Int = INDEX_BIND_LAST) -> BinaryExitCode {
    if window.nodeWorkspace == targetWorkspace {
        return switch failIfNoop {
            case true: .fail
            case false:
                .succ(io.err("Window '\(window.windowId)' already belongs to workspace '\(targetWorkspace.name)'. Tip: use --fail-if-noop to exit with non-zero code"))
        }
    }
    let targetContainer: NonLeafTreeNodeObject = window.isFloating
        ? targetWorkspace.floatingWindowsContainer
        : targetWorkspace.rootTilingContainer
    window.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: index)
    return .from(bool: focusFollowsWindow ? window.focusWindow() : true)
}
