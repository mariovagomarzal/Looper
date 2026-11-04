import AppKit
import Common

public final class TrayMenuModel: ObservableObject {
    @MainActor public static let shared = TrayMenuModel()

    private init() {}

    /// What the menu bar shows (see `menu-bar` in the config)
    @Published var menuBar: [MenuBarSegment] = []
    /// Is "layouting" enabled
    @Published var isEnabled: Bool = true
    @Published var workspaces: [WorkspaceViewModel] = []
    @Published var lastReloadConfigContainedWarnings: Bool = false
    @Published var axPermissionStatus: AxPermissionStatus = .waitingWithPrompt
}

enum AxPermissionStatus: Equatable {
    case granted
    case waiting
    case waitingWithPrompt
}

@MainActor func updateTrayText() {
    let focus = globalFocus
    var state = MenuBarState()
    state.mode = activeMode ?? mainModeId
    state.appName = focus.windowOrNil?.app.name
    state.monitors = globalSortedMonitorInfos.map { info in
        let monitor = info.toMonitorOrRearrangeMonitors()
        return monitor.activeWorkspacesContainer.workspaces.sorted().map { workspace in
            let state: MenuBarWorkspaceState = switch true {
                case workspace == focus.workspace: .focused
                case workspace.isVisible: .visible
                case !workspace.isEffectivelyEmpty: .occupied
                default: .empty
            }
            return MenuBarState.WorkspaceItem(name: workspace.name, monitor: info.name, state: state)
        }
    }
    let menuBar = renderMenuBar(config.menuBar, state)
    if TrayMenuModel.shared.menuBar != menuBar { TrayMenuModel.shared.menuBar = menuBar }
    // Workspaces of the focused monitor and native Space
    TrayMenuModel.shared.workspaces = (focus.workspace.workspacesContainer?.workspaces ?? []).sorted().map {
        let apps = $0.allLeafWindowsRecursive.map { $0.app.name?.takeIf { !$0.isEmpty } }.filterNotNil().toSet()
        let dash = " - "
        let suffix = switch true {
            case !apps.isEmpty: dash + apps.sorted().joinTruncating(separator: ", ", length: 25)
            case $0.isVisible: dash + $0.workspaceMonitorInfo.name
            default: ""
        }
        return WorkspaceViewModel(name: $0.name, suffix: suffix, isFocused: focus.workspace == $0)
    }
}

struct WorkspaceViewModel: Hashable {
    let name: String
    let suffix: String
    let isFocused: Bool
}
