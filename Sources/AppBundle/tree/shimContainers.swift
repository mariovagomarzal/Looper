import Common

final class FloatingWindowsContainer: TreeNode, NonLeafTreeNodeObject {
    @MainActor init(parent: Workspace) { super.init(parent: parent, adaptiveWeight: 1, index: INDEX_BIND_LAST) }
}

/// The independent set of workspaces of one (monitor, native macOS Space) pair.
/// A monitor has one container per native Space that Looper has seen on it.
final class WorkspacesContainer: TreeNode, NonLeafTreeNodeObject {
    /// nil when native Spaces are unavailable. Then every monitor has a single container
    let spaceId: NativeSpaceId?
    var visibleWorkspaceNameOrStale: String? = nil
    var prevVisibleWorkspaceName: String? = nil
    @MainActor init(parent: Monitor, spaceId: NativeSpaceId?) {
        self.spaceId = spaceId
        super.init(parent: parent, adaptiveWeight: 1, index: INDEX_BIND_LAST)
    }
}

final class MacosFullscreenWindowsContainer: TreeNode, NonLeafTreeNodeObject {
    @MainActor init(parent: Workspace) { super.init(parent: parent, adaptiveWeight: 1, index: INDEX_BIND_LAST) }
}

/// The container for macOS windows of hidden apps
final class MacosHiddenAppsWindowsContainer: TreeNode, NonLeafTreeNodeObject {
    @MainActor init(parent: Workspace) { super.init(parent: parent, adaptiveWeight: 1, index: INDEX_BIND_LAST) }
}

@MainActor let macosMinimizedWindowsContainer = MacosMinimizedWindowsContainer()
final class MacosMinimizedWindowsContainer: TreeNode, NonLeafTreeNodeObject {
    @MainActor fileprivate init() { super.init(parent: NilTreeNode.instance, adaptiveWeight: 1, index: INDEX_BIND_LAST) }
}

@MainActor let macosPopupWindowsContainer = MacosPopupWindowsContainer()
/// The container for macOS objects that are windows from AX perspective but from human perspective they are not even
/// dialogs. E.g. Sonoma (macOS 14) keyboard layout switch
final class MacosPopupWindowsContainer: TreeNode, NonLeafTreeNodeObject {
    @MainActor fileprivate init() { super.init(parent: NilTreeNode.instance, adaptiveWeight: 1, index: INDEX_BIND_LAST) }
}
