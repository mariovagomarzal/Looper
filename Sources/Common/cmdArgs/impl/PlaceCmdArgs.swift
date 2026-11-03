public struct PlaceCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .place,
        help: place_help_generated,
        flags: ["--window-id": windowIdSubArgParser()],
        posArgs: [newMandatoryPosArgParser(\.placement, parsePlacement, placeholder: "<placement>")],
    )

    public var placement: Lateinit<Placement> = .uninitialized
}

public enum Placement: Equatable, Sendable {
    case preset(PlacementPreset)
    /// Percentages of the usable area of the monitor
    case rect(x: Int, y: Int, width: Int, height: Int)
}

public enum PlacementPreset: String, CaseIterable, Equatable, Sendable {
    case leftHalf = "left-half"
    case rightHalf = "right-half"
    case topHalf = "top-half"
    case bottomHalf = "bottom-half"
    case topLeftQuarter = "top-left-quarter"
    case topRightQuarter = "top-right-quarter"
    case bottomLeftQuarter = "bottom-left-quarter"
    case bottomRightQuarter = "bottom-right-quarter"
    case leftThird = "left-third"
    case centerThird = "center-third"
    case rightThird = "right-third"
    case leftTwoThirds = "left-two-thirds"
    case rightTwoThirds = "right-two-thirds"
    case center
    case maximize
    case almostMaximize = "almost-maximize"
}

func parsePlacement(i: PosArgParserInput) -> ParsedCliArgs<Placement> {
    if let preset = PlacementPreset(rawValue: i.arg) {
        return .succ(.preset(preset), advanceBy: 1)
    }
    guard i.arg == "rect" else {
        let possible = (PlacementPreset.allCases.map(\.rawValue) + ["rect"]).joined(separator: "|")
        return .fail("Unknown placement '\(i.arg)'. Possible values: (\(possible))", advanceBy: 1)
    }
    let values = (1 ... 4).map { i.getOrNil(relativeIndex: $0).flatMap { Int($0) } }
    guard let x = values[0], let y = values[1], let width = values[2], let height = values[3] else {
        return .fail("'rect' must be followed by four percentages: <x> <y> <width> <height>", advanceBy: 1)
    }
    guard (0 ... 100).contains(x), (0 ... 100).contains(y), width > 0, height > 0, x + width <= 100, y + height <= 100 else {
        return .fail("'rect \(x) \(y) \(width) \(height)' doesn't fit in the monitor. Percentages must stay within 0 and 100", advanceBy: 5)
    }
    return .succ(.rect(x: x, y: y, width: width, height: height), advanceBy: 5)
}
