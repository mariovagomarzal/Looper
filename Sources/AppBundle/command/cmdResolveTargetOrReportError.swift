import Common

extension CmdArgs {
    /// The workspaces of the monitor that '--monitor' refers to (in its active native Space), or of the focused monitor
    @MainActor
    func workspacesContainer(_ env: CmdEnv, _ io: CmdIo) -> WorkspacesContainer? {
        guard let monitor else { return focusedWorkspacesContainer }
        return monitor.resolveWorkspacesContainer(relativeTo: globalFocus.workspace.workspaceMonitorInfo, env, io)
    }

    @MainActor
    func resolveTargetOrReportError(_ env: CmdEnv, _ io: CmdIo) -> LiveFocus? {
        // Flags
        if let windowId {
            return windowId.resolveOrReportError(env, io)?.toLiveFocusOrReportError(io)
        }
        if workspaceName != nil || monitor != nil {
            guard let container = workspacesContainer(env, io) else { return nil }
            let workspace = workspaceName.map { Workspace.get(byName: $0.raw, in: container) } ?? container.visibleWorkspace
            return workspace.toLiveFocus()
        }
        // Env
        if let windowId = env.windowId {
            if let wi = Window.get(byId: windowId) {
                return wi.toLiveFocusOrReportError(io)
            } else {
                io.err("Invalid <window-id> \(windowId) specified in \(LOOPER_WINDOW_ID) env variable")
                return nil
            }
        }
        if let wsName = env.workspaceName {
            return Workspace.get(byName: wsName).toLiveFocus()
        }
        // Real Focus
        return globalFocus
    }
}

extension Window {
    @MainActor
    func toLiveFocusOrReportError(_ io: CmdIo) -> LiveFocus? {
        if let result = toLiveFocusOrNil() {
            return result
        } else {
            io.err("Window \(windowId) doesn't belong to any monitor. And thus can't even define a focused workspace")
            return nil
        }
    }
}

extension MonitorTarget {
    /// The workspaces of the active native Space of the monitor. Reports an error if there is no such monitor
    @MainActor
    func resolveWorkspacesContainer(relativeTo currentMonitor: MonitorInfo, wrapAround: Bool = false, _ env: CmdEnv, _ io: CmdIo) -> WorkspacesContainer? {
        switch resolve(currentMonitor, wrapAround: wrapAround, env) {
            case .success(let monitor): return monitor.toMonitorOrRearrangeMonitors().activeWorkspacesContainer
            case .failure(let msg):
                io.err(msg)
                return nil
        }
    }
}
