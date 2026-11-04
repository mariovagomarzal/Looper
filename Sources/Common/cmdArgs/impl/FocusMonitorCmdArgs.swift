public struct FocusMonitorCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .focusMonitor,
        help: focus_monitor_help_generated,
        flags: [
            "--wrap-around": trueBoolFlag(\.wrapAround),
        ],
        posArgs: [
            doubleDashArg(mandatory: false),
            newMandatoryPosArgParser(\.target, parseMonitorTarget, placeholder: MonitorTarget.cases.joinedCliArgs),
        ],
    )

    public var wrapAround: Bool = false
    public var target: Lateinit<MonitorTarget> = .uninitialized
}

func parseFocusMonitorCmdArgs(_ args: StrArrSlice) -> ParsedCmd<FocusMonitorCmdArgs> {
    parseSpecificCmdArgs(FocusMonitorCmdArgs(rawArgs: args), args)
        .filter("--wrap-around requires a relative monitor: \(MonitorTarget.relativeCases.joinedCliArgs)") { !$0.wrapAround || $0.target.val.isRelative }
}

func parseMonitorTarget(i: PosArgParserInput) -> ParsedCliArgs<MonitorTarget> {
    switch (i.arg, i.sawDoubleDash) {
        case ("next", false):
            return .succ(.relative(.next), advanceBy: 1)
        case ("prev", false):
            return .succ(.relative(.prev), advanceBy: 1)
        case ("left", false):
            return .succ(.direction(.left), advanceBy: 1)
        case ("down", false):
            return .succ(.direction(.down), advanceBy: 1)
        case ("up", false):
            return .succ(.direction(.up), advanceBy: 1)
        case ("right", false):
            return .succ(.direction(.right), advanceBy: 1)
        case ("focused", false):
            return .succ(.focused, advanceBy: 1)
        case ("pointer", false):
            return .succ(.pointer, advanceBy: 1)
        case ("wheel", false):
            return .succ(.wheel, advanceBy: 1)
        default:
            let args = i.nonFlagArgs()
            return .init(args.mapAllOrFailure(parseMonitorDescription).map { .patterns($0) }, advanceBy: args.count)
    }
}

public enum MonitorTarget: Equatable, Sendable {
    case direction(CardinalDirection)
    case relative(NextPrev)
    case patterns([MonitorDescription])
    /// The monitor with the focused workspace
    case focused
    /// The monitor under the mouse pointer
    case pointer
    /// The monitor that was under the mouse pointer when the wheel opened. Only valid in wheel actions and conditions
    case wheel

    /// Relative to another monitor (directions, next and prev), as opposed to naming a monitor
    public var isRelative: Bool {
        switch self {
            case .direction, .relative: true
            case .patterns, .focused, .pointer, .wheel: false
        }
    }

    static var relativeCases: [String] { CardinalDirection.cliArgsCases + NextPrev.cliArgsCases }
    static var cases: [String] { relativeCases + ["focused", "pointer", "wheel", "<monitor-pattern>"] }

    public var directionOrNil: CardinalDirection? {
        switch self {
            case .direction(let direction): direction
            default: nil
        }
    }
}

/// '--monitor <monitor>': a single monitor target
func monitorSubArgParser<Root>(_ keyPath: SendableWritableKeyPath<Root, MonitorTarget?>) -> SubArgParser<Root, MonitorTarget?> {
    ArgParser(keyPath) { input in
        guard let arg = input.nonFlagArgOrNil() else {
            return .fail("'\(input.superArg)' must be followed by \(MonitorTarget.cases.joinedCliArgs)", advanceBy: 0)
        }
        return switch parseMonitorTarget(i: PosArgParserInput(index: 0, args: [arg].slice, sawDoubleDash: false)).value {
            case .success(let target): .succ(target, advanceBy: 1)
            case .failure(let msg): .fail("Failed to parse '\(arg)' CLI argument: \(msg)", advanceBy: 1)
        }
    }
}
