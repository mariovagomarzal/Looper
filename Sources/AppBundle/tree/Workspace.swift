import AppKit
import Common

/// Workspace names are unique only inside their ``WorkspacesContainer``. Every (monitor, native Space) pair has its
/// own independent set of workspaces. Commands resolve workspace names in the container of the focused workspace.
final class Workspace: TreeNode, NonLeafTreeNodeObject, Hashable, Comparable {
    let name: String
    nonisolated private let nameLogicalSegments: StringLogicalSegments

    @MainActor private init(_ name: String, _ container: WorkspacesContainer) {
        self.name = name
        self.nameLogicalSegments = name.toLogicalSegments()
        super.init(parent: container, adaptiveWeight: 1, index: INDEX_BIND_LAST)
    }

    /// Workspaces of all monitors and native Spaces
    @MainActor static var all: [Workspace] {
        Monitor.all.flatMap { $0.workspacesContainers.flatMap(\.workspaces) }.sorted()
    }

    /// Resolves the name in the context of the focused workspace (focused monitor and its active native Space)
    @MainActor static func get(byName name: String) -> Workspace {
        get(byName: name, in: focusedWorkspacesContainer)
    }

    @MainActor static func get(byName name: String, in container: WorkspacesContainer) -> Workspace {
        container.workspace(named: name) ?? Workspace(name, container)
    }

    nonisolated static func < (lhs: Workspace, rhs: Workspace) -> Bool {
        lhs.nameLogicalSegments < rhs.nameLogicalSegments
    }

    override func getWeight(_ targetOrientation: Orientation) -> CGFloat {
        workspaceMonitorInfo.visibleRectPaddedByOuterGaps.getDimension(targetOrientation)
    }

    override func setWeight(_ targetOrientation: Orientation, _ newValue: CGFloat) {
        die("It's not possible to change weight of Workspace")
    }

    @MainActor
    var description: String {
        let description = [
            ("name", name),
            ("isVisible", String(isVisible)),
            ("isEffectivelyEmpty", String(isEffectivelyEmpty)),
            ("doKeepAlive", String(config.persistentWorkspaces.contains(name))),
        ].map { "\($0.0): \(String(describing: $0.1).singleQuoted)" }.joined(separator: ", ")
        return "Workspace(\(description))"
    }

    @MainActor static func garbageCollectUnusedWorkspaces() {
        let focus = globalFocus
        for monitor in Monitor.all {
            for container in monitor.workspacesContainers {
                for name in config.persistentWorkspaces {
                    _ = get(byName: name, in: container) // Make sure that all persistent workspaces exist
                }
                for workspace in container.workspaces {
                    let keep = config.persistentWorkspaces.contains(workspace.name) ||
                        !workspace.isEffectivelyEmpty ||
                        workspace.isVisibleInItsSpace ||
                        workspace == focus.workspace
                    if !keep { workspace.unbindFromParent() }
                }
            }
            monitor.garbageCollectStaleWorkspacesContainers(focus: focus)
        }
    }

    nonisolated static func == (lhs: Workspace, rhs: Workspace) -> Bool { lhs === rhs }

    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}

/// The container of the focused workspace
@MainActor var focusedWorkspacesContainer: WorkspacesContainer {
    globalFocus.workspace.workspacesContainer ?? mainMonitorInfo.toMonitorOrRearrangeMonitors().activeWorkspacesContainer
}
