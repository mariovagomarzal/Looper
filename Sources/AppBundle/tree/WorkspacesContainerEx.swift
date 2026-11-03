import Common
import Foundation

extension WorkspacesContainer {
    @MainActor var monitor: Monitor { (parent as? Monitor).orDie("WorkspacesContainer must be a child of Monitor") }

    @MainActor var workspaces: [Workspace] { children.filterIsInstance(of: Workspace.self) }

    @MainActor func workspace(named name: String) -> Workspace? {
        workspaces.first { $0.name == name }
    }

    /// The container belongs to the native Space currently shown on its monitor
    @MainActor var isActive: Bool {
        spaceId == nativeSpaces?.currentSpace(of: monitor.info)
    }

    /// The native Space of the container no longer exists, or no longer belongs to the monitor
    @MainActor var isStale: Bool {
        guard let snapshot = nativeSpaces else { return spaceId != nil }
        guard let spaceId, let display = snapshot.display(ofSpace: spaceId) else { return true }
        return !snapshot.spacesSpanAllDisplays && snapshot.display(of: monitor.info)?.id != display.id
    }

    @MainActor func setVisibleWorkspace(_ workspace: Workspace) -> Bool {
        if workspace.parent !== self { return false }
        if visibleWorkspaceNameOrStale == workspace.name { return true }
        prevVisibleWorkspaceName = visibleWorkspaceNameOrStale
        visibleWorkspaceNameOrStale = workspace.name
        return true
    }

    /// The workspace that is shown when the native Space of the container is active
    @MainActor var visibleWorkspace: Workspace {
        if let workspace = visibleWorkspaceNameOrStale.flatMap(workspace(named:)) { return workspace }
        let stub = stubWorkspace
        check(setVisibleWorkspace(stub))
        return stub
    }

    /// A workspace to show when the visible one is gone
    @MainActor private var stubWorkspace: Workspace {
        if let prev = prevVisibleWorkspaceName.flatMap(workspace(named:)) {
            return prev
        }
        // Not the most recent child: binding marks every newly created workspace (e.g. persistent ones) as most recent
        if let persistent = config.persistentWorkspaces.map({ Workspace.get(byName: $0, in: self) }).min() {
            return persistent
        }
        return (1 ... Int.max).lazy
            .map { Workspace.get(byName: String($0), in: self) }
            .first { $0.isEffectivelyEmpty }
            .orDie("Can't create empty workspace")
    }
}
