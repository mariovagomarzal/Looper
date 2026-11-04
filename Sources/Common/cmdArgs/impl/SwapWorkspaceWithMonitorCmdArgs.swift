public struct SwapWorkspaceWithMonitorCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .swapWorkspaceWithMonitor,
        help: swap_workspace_with_monitor_help_generated,
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

func parseSwapWorkspaceWithMonitorCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SwapWorkspaceWithMonitorCmdArgs> {
    parseSpecificCmdArgs(SwapWorkspaceWithMonitorCmdArgs(rawArgs: args), args)
        .filter("--wrap-around requires a relative monitor: \(MonitorTarget.relativeCases.joinedCliArgs)") { $0.wrapAround.implies($0.target.val.isRelative) }
}
