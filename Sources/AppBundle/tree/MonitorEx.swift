import Common

extension Monitor {
    @MainActor var workspacesContainers: [WorkspacesContainer] {
        children.filterIsInstance(of: WorkspacesContainer.self)
    }

    /// The workspaces of the native Space currently shown on the monitor
    @MainActor var activeWorkspacesContainer: WorkspacesContainer {
        workspacesContainer(forSpace: nativeSpaces?.currentSpace(of: info))
    }

    @MainActor func workspacesContainer(forSpace spaceId: NativeSpaceId?) -> WorkspacesContainer {
        workspacesContainers.first { $0.spaceId == spaceId } ?? WorkspacesContainer(parent: self, spaceId: spaceId)
    }

    /// Removes the containers of native Spaces that no longer exist (or moved to another display) once their windows
    /// were moved elsewhere. See ``reconcileWindowsWithNativeSpaces()``
    @MainActor func garbageCollectStaleWorkspacesContainers(focus: LiveFocus) {
        for container in workspacesContainers where container.isStale {
            if container.anyLeafWindowRecursive != nil { continue }
            if focus.workspace.workspacesContainer === container { continue }
            container.unbindFromParent()
        }
    }
}

/// The container that owns the workspaces of the given native Space
///
/// - Parameter fallbackMonitor: the monitor to use when a single set of Spaces spans all displays
@MainActor func workspacesContainer(forNativeSpace space: NativeSpaceId, fallbackMonitor: MonitorInfo) -> WorkspacesContainer? {
    guard let snapshot = nativeSpaces, let display = snapshot.display(ofSpace: space) else { return nil }
    let monitor: MonitorInfo? = snapshot.spacesSpanAllDisplays
        ? fallbackMonitor
        : globalUnsortedMonitorInfos.first { snapshot.display(of: $0)?.id == display.id }
    return monitor?.toMonitorOrRearrangeMonitors().workspacesContainer(forSpace: space)
}
