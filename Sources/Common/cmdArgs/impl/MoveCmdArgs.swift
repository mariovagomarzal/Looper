public struct MoveCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .move,
        help: move_help_generated,
        flags: [
            "--window-id": windowIdSubArgParser(),
            "--boundaries": ArgParser(\.rawBoundaries, upcastArgParserFun(parseBoundaries)),
            "--boundaries-action": ArgParser(\.rawBoundariesAction, upcastArgParserFun(parseBoundariesAction)),
            "--fail-if-fullscreen": trueBoolFlag(\.failIfFullscreen),
            "--fail-if-macos-native-fullscreen": trueBoolFlag(\.failIfMacosNativeFullscreen),
        ],
        posArgs: [
            newMandatoryPosArgParser(\.direction, parseCardinalDirectionArg, placeholder: CardinalDirection.unionLiteral),
            ArgParser(\.distance, upcastArgParserFun(parseMoveDistance)),
        ],
    )

    public var direction: Lateinit<CardinalDirection> = .uninitialized
    public var rawBoundaries: Boundaries? = nil
    public var rawBoundariesAction: WhenBoundariesCrossed? = nil
    public var failIfFullscreen: Bool = false
    public var failIfMacosNativeFullscreen: Bool = false
    /// How far a floating window moves. Tiling windows move to the next place in the tree instead
    public var distance: MoveDistance? = nil

    public enum Boundaries: String, CaseIterable, Equatable, Sendable {
        case workspace
        case allMonitorsOuterFrame = "all-monitors-outer-frame"
    }

    public enum WhenBoundariesCrossed: String, CaseIterable, Equatable, Sendable {
        case stop = "stop"
        case fail = "fail"
        case createImplicitContainer = "create-implicit-container"
    }
}

extension MoveCmdArgs {
    public var boundaries: Boundaries { rawBoundaries ?? .workspace }
    public var boundariesAction: WhenBoundariesCrossed { rawBoundariesAction ?? .createImplicitContainer }
}

func parseMoveCmdArgs(_ args: StrArrSlice) -> ParsedCmd<MoveCmdArgs> {
    parseSpecificCmdArgs(MoveCmdArgs(rawArgs: args), args)
}

public enum MoveDistance: Equatable, Sendable {
    case points(UInt)
    /// Of the usable area of the monitor, along the direction of the move
    case percent(UInt)

    public static let `default`: MoveDistance = .percent(5)
}

private func parseMoveDistance(i: PosArgParserInput) -> ParsedCliArgs<MoveDistance> {
    let isPercent = i.arg.hasSuffix("%")
    guard let number = UInt(isPercent ? String(i.arg.dropLast()) : i.arg), number > 0 else {
        return .fail("<distance> must be a positive number of points, or a percentage like 10%. Got: \(i.arg.singleQuoted)", advanceBy: 1)
    }
    return .succ(isPercent ? .percent(number) : .points(number), advanceBy: 1)
}

private func parseBoundaries(i: SubArgParserInput) -> ParsedCliArgs<MoveCmdArgs.Boundaries> {
    if let arg = i.nonFlagArgOrNil() {
        return .init(parseEnum(arg, MoveCmdArgs.Boundaries.self), advanceBy: 1)
    } else {
        return .fail("<boundary> is mandatory", advanceBy: 0)
    }
}

private func parseBoundariesAction(i: SubArgParserInput) -> ParsedCliArgs<MoveCmdArgs.WhenBoundariesCrossed> {
    if let arg = i.nonFlagArgOrNil() {
        return .init(parseEnum(arg, MoveCmdArgs.WhenBoundariesCrossed.self), advanceBy: 1)
    } else {
        return .fail("<action> is mandatory", advanceBy: 0)
    }
}
