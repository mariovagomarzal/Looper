import AppKit
import Common

struct ResizeCommand: Command {
    let args: ResizeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        if let window = target.windowOrNil, case .floatingWindowsContainer = window.windowParentCases {
            guard let (window, frame) = await floatingFrame(env, io) else { return .fail }
            window.isFullscreen = false
            window.setAxFrame(frame.topLeftCorner, frame.size)
            return .succ
        }
        return apply(env, io)
    }

    /// The new frame of a floating window. Shared with the wheel preview
    @MainActor func floatingFrame(_ env: CmdEnv, _ io: CmdIo) async -> (Window, Rect)? {
        guard let target = args.resolveTargetOrReportError(env, io), let window = target.windowOrNil else {
            io.err(noWindowIsFocused)
            return nil
        }
        guard case .floatingWindowsContainer = window.windowParentCases else { return nil }
        guard let rect = try? await window.getAxRect(.nonCancellable) else {
            io.err("Can't read the frame of the window")
            return nil
        }
        let area = target.workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps
        guard let frame = resizedFloatingFrame(rect, args.dimension.val, args.units.val, area: area) else {
            io.err("'smart-opposite' doesn't apply to floating windows: they have no parent container. Use 'smart', 'width' or 'height'")
            return nil
        }
        return (window, frame)
    }

    /// Resizes tiling windows by changing weights. Synchronous, so that the wheel preview can simulate it
    @MainActor func apply(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }

        let candidates = target.windowOrNil?.parentsWithSelf
            .filter { ($0.parent as? TilingContainer)?.layout == .tiles }
            .filter {
                guard let parent = $0.parent as? TilingContainer else { return false }
                return switch parent.lifeStatus {
                    case .alive: true
                    case .mustBeFlattened, .deadOrInvisible: false
                }
            }
            ?? []

        let orientation: Orientation?
        let parent: TilingContainer?
        let node: TreeNode?
        switch args.dimension.val {
            case .width:
                orientation = .h
                node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
                parent = node?.parent as? TilingContainer
            case .height:
                orientation = .v
                node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
                parent = node?.parent as? TilingContainer
            case .smart:
                node = candidates.first
                parent = node?.parent as? TilingContainer
                orientation = parent?.orientation
            case .smartOpposite:
                orientation = (candidates.first?.parent as? TilingContainer)?.orientation.opposite
                node = candidates.first(where: { ($0.parent as? TilingContainer)?.orientation == orientation })
                parent = node?.parent as? TilingContainer
        }
        guard let parent else {
            return .fail(io.err("resize command doesn't support floating windows yet https://github.com/nikitabobko/AeroSpace/issues/9"))
        }
        guard let orientation else { return .fail }
        guard let node else { return .fail }
        let diff: CGFloat = switch args.units.val {
            case .set(let unit): CGFloat(unit) - node.getWeight(orientation)
            case .add(let unit): CGFloat(unit)
            case .subtract(let unit): -CGFloat(unit)
        }

        let inhabitedSiblings = parent.inhabitedChildren.filter { $0 != node }
        guard let childDiff = diff.div(inhabitedSiblings.count) else { return .fail }
        for sibling in inhabitedSiblings {
            sibling.setWeight(parent.orientation, sibling.getWeight(parent.orientation) - childDiff)
        }

        node.setWeight(orientation, node.getWeight(orientation) + diff)
        return .succ
    }
}

/// Floating windows keep their center: 'width' and 'height' change one dimension, 'smart' changes both. The size stays
/// between a minimum and the usable area, and a window that grows past an edge of the area is pushed back inside.
/// nil for 'smart-opposite', which needs a parent container
func resizedFloatingFrame(_ rect: Rect, _ dimension: ResizeCmdArgs.Dimension, _ units: ResizeCmdArgs.Units, area: Rect) -> Rect? {
    let changesWidth: Bool
    let changesHeight: Bool
    switch dimension {
        case .width: (changesWidth, changesHeight) = (true, false)
        case .height: (changesWidth, changesHeight) = (false, true)
        case .smart: (changesWidth, changesHeight) = (true, true)
        case .smartOpposite: return nil
    }
    let minimumSize: CGFloat = 50
    // Never smaller than the minimum (unless it already was), never bigger than the area (unless it already was)
    func resized(_ size: CGFloat, _ areaLength: CGFloat) -> CGFloat {
        let new = switch units {
            case .set(let value): CGFloat(value)
            case .add(let value): size + CGFloat(value)
            case .subtract(let value): size - CGFloat(value)
        }
        let lowest = min(minimumSize, size)
        return new.coerce(in: lowest ... max(lowest, areaLength, min(size, new)))
    }
    // Centered on the old frame. A window that grows past an edge of the area is pushed back, at most to the old
    // position of that edge, so that a window that was already beyond it doesn't jump
    func placed(_ start: CGFloat, _ size: CGFloat, _ newSize: CGFloat, _ areaStart: CGFloat, _ areaEnd: CGFloat) -> CGFloat {
        let newStart = start + (size - newSize) / 2
        guard newSize > size else { return newStart }
        let growth = (newSize - size) / 2
        if newStart < areaStart { return newStart + min(areaStart - newStart, growth) }
        if newStart + newSize > areaEnd { return newStart - min(newStart + newSize - areaEnd, growth) }
        return newStart
    }
    let width = changesWidth ? resized(rect.width, area.width) : rect.width
    let height = changesHeight ? resized(rect.height, area.height) : rect.height
    return Rect(
        topLeftX: placed(rect.minX, rect.width, width, area.minX, area.maxX),
        topLeftY: placed(rect.minY, rect.height, height, area.minY, area.maxY),
        width: width,
        height: height,
    )
}
