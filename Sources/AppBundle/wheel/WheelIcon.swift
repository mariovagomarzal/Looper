import AppKit
import Common

// The center of the wheel shows an SF Symbol for the release action of the selection. Slots set it with 'icon';
// otherwise it's derived from the first command of the action that has one.

/// Whether macOS has an SF Symbol with this name
func isSfSymbol(_ name: String) -> Bool {
    NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
}

/// The icon of the first command of the action that has one
func wheelAutoIcon(_ action: Shell<any Command>) -> String? {
    action.flatten().lazy.compactMap(wheelCommandIcon).first
}

func wheelCommandIcon(_ command: any Command) -> String? {
    switch command {
        case let it as MoveCommand: "arrow.\(it.args.direction.val.rawValue)"
        case let it as SwapCommand:
            switch it.args.target.val {
                case .direction(let direction): direction.orientation == .v ? "arrow.up.arrow.down" : "arrow.left.arrow.right"
                case .dfsNextPrev: "arrow.left.arrow.right"
            }
        case let it as FocusCommand:
            switch it.args.target {
                case .direction(let direction): "arrow.\(direction.rawValue).circle"
                default: "scope"
            }
        case is FocusBackAndForthCommand: "arrow.uturn.backward"
        case is JoinWithCommand: "arrow.triangle.merge"
        case let it as LayoutCommand: it.args.toggleBetween.val.first.map(layoutIcon)
        case is FullscreenCommand, is MacosNativeFullscreenCommand: "arrow.up.left.and.arrow.down.right"
        case is MacosNativeMinimizeCommand: "dock.arrow.down.rectangle"
        case let it as WorkspaceCommand: workspaceIcon(it.args.target.val)
        case is WorkspaceBackAndForthCommand: "arrow.uturn.backward.square"
        case is MoveNodeToWorkspaceCommand: "tray.and.arrow.down"
        case is MoveNodeToMonitorCommand, is MoveWorkspaceToMonitorCommand, is SwapWorkspaceWithMonitorCommand: "display.2"
        case is FocusMonitorCommand: "display"
        case is BalanceSizesCommand: "equal.square"
        case is FlattenWorkspaceTreeCommand: "arrow.down.right.and.arrow.up.left"
        case let it as SplitCommand: it.args.arg.val == .vertical ? "rectangle.split.1x2" : "rectangle.split.2x1"
        case let it as ResizeCommand:
            switch it.args.units.val {
                case .add: "plus.square"
                case .subtract: "minus.square"
                case .set: "ruler"
            }
        case let it as PlaceCommand: placeIcon(it.args.placement.val)
        case is CloseCommand: "xmark"
        case is CloseAllWindowsButCurrentCommand: "xmark.square"
        case is ExecAndForgetCommand: "terminal"
        case is ModeCommand: "keyboard"
        case is ReloadConfigCommand: "arrow.clockwise"
        case is EnableCommand: "power"
        case is VolumeCommand: "speaker.wave.2"
        case is MoveMouseCommand: "cursorarrow.motionlines"
        default: nil
    }
}

private func layoutIcon(_ layout: LayoutCmdArgs.LayoutDescription) -> String {
    switch layout {
        case .accordion, .h_accordion, .v_accordion: "rectangle.stack"
        case .tiles, .horizontal, .h_tiles: "rectangle.split.3x1"
        case .vertical, .v_tiles: "rectangle.split.1x2"
        case .tiling: "rectangle.split.2x2"
        case .floating: "macwindow.on.rectangle"
    }
}

private func workspaceIcon(_ target: WorkspaceTarget) -> String {
    switch target {
        case .relative(.next): "arrow.right.square"
        case .relative(.prev): "arrow.left.square"
        case .direct(let name):
            // Workspaces named with one letter or digit get it in a square, like '1.square'
            name.raw.count == 1 && isSfSymbol(name.raw.lowercased() + ".square") ? name.raw.lowercased() + ".square" : "square.grid.2x2"
    }
}

private func placeIcon(_ placement: Placement) -> String {
    guard case .preset(let preset) = placement else { return "rectangle.dashed" }
    return switch preset {
        case .leftHalf: "rectangle.lefthalf.filled"
        case .rightHalf: "rectangle.righthalf.filled"
        case .topHalf: "rectangle.tophalf.filled"
        case .bottomHalf: "rectangle.bottomhalf.filled"
        case .topLeftQuarter: "rectangle.inset.topleft.filled"
        case .topRightQuarter: "rectangle.inset.topright.filled"
        case .bottomLeftQuarter: "rectangle.inset.bottomleft.filled"
        case .bottomRightQuarter: "rectangle.inset.bottomright.filled"
        case .leftThird: "rectangle.leftthird.inset.filled"
        case .centerThird, .center: "rectangle.center.inset.filled"
        case .rightThird: "rectangle.rightthird.inset.filled"
        case .leftTwoThirds: "rectangle.lefthalf.inset.filled"
        case .rightTwoThirds: "rectangle.righthalf.inset.filled"
        case .maximize, .almostMaximize: "rectangle.inset.filled"
    }
}
