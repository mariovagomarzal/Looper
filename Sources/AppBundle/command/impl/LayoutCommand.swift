import AppKit
import Common

struct LayoutCommand: Command {
    let args: LayoutCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        if args.forNextDetectedWindow {
            if let it = args.toggleBetween.val.singleOrNil() {
                global_layoutForNextDetectedWindow = it
                return .succ
            } else {
                return .fail(io.err(bugPrompt()))
            }
        }
        let (target, node, targetDescription): (LiveFocus, ConventionalWindowParentCases, LayoutCmdArgs.LayoutDescription)
        switch resolve(env, io) {
            case .exit(let exitCode): return exitCode
            case .resolved(let t, let n, let d): (target, node, targetDescription) = (t, n, d)
        }
        // Floating windows remember their size to get it back when they float again
        if case .tiling = targetDescription, case .floatingWindowsContainer = node, let window = target.windowOrNil {
            window.lastFloatingSize = (try? await window.getAxSize(.nonCancellable)) ?? window.lastFloatingSize
        }
        let exitCode = apply(target, node, targetDescription, io)
        if case .floating = targetDescription, exitCode.rawValue == 0, let window = target.windowOrNil, let size = window.lastFloatingSize {
            window.setAxFrame(nil, size)
        }
        return exitCode
    }

    /// The changes to the tree, without reading or setting window frames. nil for --for-next-detected-window.
    /// Synchronous, so that the wheel preview can simulate it
    @MainActor func applySynchronously(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode? {
        if args.forNextDetectedWindow { return nil }
        switch resolve(env, io) {
            case .exit(let exitCode): return exitCode
            case .resolved(let target, let node, let targetDescription): return apply(target, node, targetDescription, io)
        }
    }

    @MainActor private func apply(
        _ target: LiveFocus,
        _ node: ConventionalWindowParentCases,
        _ targetDescription: LayoutCmdArgs.LayoutDescription,
        _ io: CmdIo,
    ) -> BinaryExitCode {
        if let exitCode = applyTilingLayout(targetDescription, node, io) { return exitCode }
        guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
        switch (targetDescription, node) {
            case (.tiling, .tilingContainer):
                return .succ // Nothing to do
            case (.tiling, .floatingWindowsContainer(let container)):
                guard let workspace = container.nodeWorkspace else { return .fail(io.err(bugPrompt())) }
                window.bindAsNewTilingWindow(on: workspace)
                return .succ
            case (.floating, _):
                window.bindAsFloatingWindow(to: target.workspace)
                return .succ
            default:
                return .fail(io.err(bugPrompt())) // Handled by applyTilingLayout
        }
    }

    @MainActor private func applyTilingLayout(
        _ targetDescription: LayoutCmdArgs.LayoutDescription,
        _ node: ConventionalWindowParentCases,
        _ io: CmdIo,
    ) -> BinaryExitCode? {
        switch targetDescription {
            case .h_accordion:
                changeTilingLayout(io, targetLayout: .accordion, targetOrientation: .h, node: node)
            case .v_accordion:
                changeTilingLayout(io, targetLayout: .accordion, targetOrientation: .v, node: node)
            case .h_tiles:
                changeTilingLayout(io, targetLayout: .tiles, targetOrientation: .h, node: node)
            case .v_tiles:
                changeTilingLayout(io, targetLayout: .tiles, targetOrientation: .v, node: node)
            case .accordion:
                changeTilingLayout(io, targetLayout: .accordion, targetOrientation: nil, node: node)
            case .tiles:
                changeTilingLayout(io, targetLayout: .tiles, targetOrientation: nil, node: node)
            case .horizontal:
                changeTilingLayout(io, targetLayout: nil, targetOrientation: .h, node: node)
            case .vertical:
                changeTilingLayout(io, targetLayout: nil, targetOrientation: .v, node: node)
            case .tiling, .floating:
                nil
        }
    }

    private enum Resolution {
        case exit(BinaryExitCode)
        case resolved(LiveFocus, ConventionalWindowParentCases, LayoutCmdArgs.LayoutDescription)
    }

    /// The container whose layout changes, and the layout it changes to
    @MainActor private func resolve(_ env: CmdEnv, _ io: CmdIo) -> Resolution {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .exit(.fail) }

        let node: ConventionalWindowParentCases
        switch args.root ? nil : target.windowOrNil {
            case let window?:
                switch window.windowParentCases {
                    case .floatingWindowsContainer(let it):
                        node = .floatingWindowsContainer(it)
                    case .tilingContainer:
                        guard let (parent, _) = window.nearestAliveTilingParent() else { return .exit(.fail(io.err(bugPrompt()))) }
                        node = .tilingContainer(parent)
                    case .macosFullscreenWindowsContainer,
                         .macosHiddenAppsWindowsContainer,
                         .macosMinimizedWindowsContainer:
                        let msg = "Can't change layout for macOS minimized, fullscreen windows or windows or hidden apps. " +
                            "This behavior is subject to change"
                        return .exit(.fail(io.err(msg)))
                    case nil, .macosPopupWindowsContainer:
                        return .exit(.fail(io.err(bugPrompt())))
                }
            case nil:
                node = .tilingContainer(target.workspace.rootTilingContainer)
        }

        let targetDescription = args.toggleBetween.val.first(where: { !node.matchesDescription($0) })
            ?? args.toggleBetween.val.first.orDie()
        if node.matchesDescription(targetDescription) {
            switch args.failIfNoop {
                case true: return .exit(.fail)
                case false:
                    let msg = "Already in the requested \(targetDescription.rawValue) mode. " +
                        "Tip: use --fail-if-noop to exit with non-zero exit code"
                    return .exit(.succ(io.err(msg)))
            }
        }
        return .resolved(target, node, targetDescription)
    }
}

@MainActor var global_layoutForNextDetectedWindow: LayoutCmdArgs.LayoutDescription? = nil

@MainActor private func changeTilingLayout(
    _ io: CmdIo,
    targetLayout: Layout?,
    targetOrientation: Orientation?,
    node: ConventionalWindowParentCases,
) -> BinaryExitCode {
    switch node {
        case .floatingWindowsContainer:
            return .fail(io.err("The window is non-tiling"))
        case .tilingContainer(let parent):
            let targetOrientation = targetOrientation ?? parent.orientation
            let targetLayout = targetLayout ?? parent.layout
            parent.layout = targetLayout
            parent.changeOrientation(targetOrientation)
            return .succ
    }
}

extension ConventionalWindowParentCases {
    fileprivate func matchesDescription(_ layout: LayoutCmdArgs.LayoutDescription) -> Bool {
        return switch layout {
            case .accordion:   tilingContainerOrNil?.layout == .accordion
            case .tiles:       tilingContainerOrNil?.layout == .tiles
            case .horizontal:  tilingContainerOrNil?.orientation == .h
            case .vertical:    tilingContainerOrNil?.orientation == .v
            case .h_accordion: tilingContainerOrNil.map { $0.layout == .accordion && $0.orientation == .h } == true
            case .v_accordion: tilingContainerOrNil.map { $0.layout == .accordion && $0.orientation == .v } == true
            case .h_tiles:     tilingContainerOrNil.map { $0.layout == .tiles && $0.orientation == .h } == true
            case .v_tiles:     tilingContainerOrNil.map { $0.layout == .tiles && $0.orientation == .v } == true
            case .tiling:      tilingContainerOrNil != nil
            case .floating:    floatingWindowsContainerOrNil != nil
        }
    }
}
