public struct WheelCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .wheel,
        help: wheel_help_generated,
        flags: [:],
        posArgs: [newMandatoryPosArgParser(\.action, parseWheelAction, placeholder: WheelAction.argsUnion)],
    )

    public var action: Lateinit<WheelAction> = .uninitialized
}

public enum WheelAction: Equatable, Sendable {
    /// nil opens the default profile
    case open(profile: String?)
    case cancel

    static let argsUnion: String = "(open [<profile>]|cancel)"
}

func parseWheelAction(i: PosArgParserInput) -> ParsedCliArgs<WheelAction> {
    switch i.arg {
        case "open":
            if let profile = i.getOrNil(relativeIndex: 1), !profile.starts(with: "-") {
                return .succ(.open(profile: profile), advanceBy: 2)
            }
            return .succ(.open(profile: nil), advanceBy: 1)
        case "cancel":
            return .succ(.cancel, advanceBy: 1)
        default:
            return .fail("Unknown argument '\(i.arg)'. Possible values: \(WheelAction.argsUnion)", advanceBy: 1)
    }
}
