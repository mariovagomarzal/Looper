import AppKit
import Common

struct PlaceCommand: Command {
    let args: PlaceCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        guard let (window, frame) = await targetFrame(env, io) else { return .fail }
        window.isFullscreen = false
        window.setAxFrame(frame.topLeftCorner, frame.size)
        return .succ
    }

    /// The window to place and where it goes. Shared with the wheel preview
    @MainActor func targetFrame(_ env: CmdEnv, _ io: CmdIo) async -> (Window, Rect)? {
        guard let target = args.resolveTargetOrReportError(env, io) else { return nil }
        guard let window = target.windowOrNil else {
            io.err(noWindowIsFocused)
            return nil
        }
        guard case .floatingWindowsContainer = window.windowParentCases else {
            io.err("'place' only works with floating windows. Make the window floating first, e.g. 'layout floating && place \(args.placement.val.description)'")
            return nil
        }
        let monitor = target.workspace.workspaceMonitorInfo
        let gaps = ResolvedGaps(gaps: config.gaps, monitor: monitor)
        let currentSize = try? await window.getAxRect(.nonCancellable)?.size
        guard let frame = placementFrame(
            args.placement.val,
            area: monitor.visibleRectPaddedByOuterGaps,
            innerGaps: CGSize(width: gaps.inner.horizontal, height: gaps.inner.vertical),
            currentSize: currentSize,
        ) else {
            io.err("Can't read the size of the window")
            return nil
        }
        return (window, frame)
    }
}

/// Where the placement puts a window, in the usable area of its monitor (outer gaps already applied).
///
/// Edges shared with a neighbor region (e.g. the right edge of 'left-half') are inset by half of the inner gap, so that
/// two windows placed side by side are separated like tiled windows. `currentSize` is only needed by 'center'.
func placementFrame(_ placement: Placement, area: Rect, innerGaps: CGSize, currentSize: CGSize?) -> Rect? {
    let fractions: (minX: CGFloat, minY: CGFloat, maxX: CGFloat, maxY: CGFloat)
    switch placement {
        case .preset(.center):
            guard let currentSize else { return nil }
            let width = min(currentSize.width, area.width)
            let height = min(currentSize.height, area.height)
            return Rect(topLeftX: area.center.x - width / 2, topLeftY: area.center.y - height / 2, width: width, height: height)
        case .preset(.almostMaximize):
            let margin: CGFloat = 0.05
            return Rect(
                topLeftX: area.minX + area.width * margin,
                topLeftY: area.minY + area.height * margin,
                width: area.width * (1 - 2 * margin),
                height: area.height * (1 - 2 * margin),
            )
        case .preset(let preset):
            fractions = preset.fractions
        case .rect(let x, let y, let width, let height):
            fractions = (CGFloat(x) / 100, CGFloat(y) / 100, CGFloat(x + width) / 100, CGFloat(y + height) / 100)
    }
    var minX = area.minX + area.width * fractions.minX
    var maxX = area.minX + area.width * fractions.maxX
    var minY = area.minY + area.height * fractions.minY
    var maxY = area.minY + area.height * fractions.maxY
    if fractions.minX > 0 { minX += innerGaps.width / 2 }
    if fractions.maxX < 1 { maxX -= innerGaps.width / 2 }
    if fractions.minY > 0 { minY += innerGaps.height / 2 }
    if fractions.maxY < 1 { maxY -= innerGaps.height / 2 }
    return Rect(topLeftX: minX, topLeftY: minY, width: maxX - minX, height: maxY - minY)
}

extension PlacementPreset {
    /// The region of the usable area, as fractions. Y grows downwards
    fileprivate var fractions: (minX: CGFloat, minY: CGFloat, maxX: CGFloat, maxY: CGFloat) {
        switch self {
            case .leftHalf: (0, 0, 0.5, 1)
            case .rightHalf: (0.5, 0, 1, 1)
            case .topHalf: (0, 0, 1, 0.5)
            case .bottomHalf: (0, 0.5, 1, 1)
            case .topLeftQuarter: (0, 0, 0.5, 0.5)
            case .topRightQuarter: (0.5, 0, 1, 0.5)
            case .bottomLeftQuarter: (0, 0.5, 0.5, 1)
            case .bottomRightQuarter: (0.5, 0.5, 1, 1)
            case .leftThird: (0, 0, 1.0 / 3, 1)
            case .centerThird: (1.0 / 3, 0, 2.0 / 3, 1)
            case .rightThird: (2.0 / 3, 0, 1, 1)
            case .leftTwoThirds: (0, 0, 2.0 / 3, 1)
            case .rightTwoThirds: (1.0 / 3, 0, 1, 1)
            case .maximize, .center, .almostMaximize: (0, 0, 1, 1)
        }
    }
}

extension Placement: CustomStringConvertible {
    public var description: String {
        switch self {
            case .preset(let preset): preset.rawValue
            case .rect(let x, let y, let width, let height): "rect \(x) \(y) \(width) \(height)"
        }
    }
}
