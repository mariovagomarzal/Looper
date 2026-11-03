import AppKit
import Common

struct WheelCommand: Command {
    let args: WheelCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        switch args.action.val {
            case .open(let profile):
                let profile = profile ?? defaultWheelProfile
                guard config.wheel.profiles[profile] != nil else {
                    let known = config.wheel.profiles.keys.sorted().joined(separator: ", ")
                    return .fail(io.err("Unknown wheel profile '\(profile)'. Known profiles: \(known)"))
                }
                let wasOpen = WheelController.shared.isOpen
                WheelController.shared.request(profile: profile)
                if !wasOpen { wheelDidOpenFromCommand() }
                return .succ
            case .cancel:
                WheelController.shared.cancel("command")
                return .succ
        }
    }
}
