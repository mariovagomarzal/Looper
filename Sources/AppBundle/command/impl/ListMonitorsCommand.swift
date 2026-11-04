import AppKit
import Common

struct ListMonitorsCommand: Command {
    let args: ListMonitorsCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        let focus = globalFocus
        var result = globalSortedMonitorInfos
        if let focused = args.focused {
            result = result.filter { (monitor) in (monitor.visibleWorkspace == focus.workspace) == focused }
        }
        if let pointer = args.pointer {
            let pointerWorkspace = mouseLocation.monitorApproximation.visibleWorkspace
            result = result.filter { (monitor) in (monitor.visibleWorkspace == pointerWorkspace) == pointer }
        }

        lazy var list = result.map(AeroObj.monitor)
        return switch true {
            case args.outputOnlyCount:
                .succ(io.out("\(result.count)"))
            case args.json:
                switch list.formatToJson(args.format, ignoreRightPaddingVar: args._format.isEmpty) {
                    case .success(let json): .succ(io.out(json))
                    case .failure(let msg): .fail(io.err(msg))
                }
            default:
                switch list.format(args.format) {
                    case .success(let lines): .succ(io.out(lines))
                    case .failure(let msg): .fail(io.err(msg.map(\.description).joinErrors()))
                }
        }
    }
}
