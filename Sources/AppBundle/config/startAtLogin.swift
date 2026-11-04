import AppKit
import Common
import ServiceManagement

enum StartAtLoginStep: Equatable {
    case nothing, register, unregister
    /// The user turned Looper off in the Login Items settings, which only they can undo
    case reportDisabledInSettings
}

func startAtLoginStep(isWanted: Bool, _ status: SMAppService.Status) -> StartAtLoginStep {
    switch (isWanted, status) {
        case (true, .enabled), (false, .notRegistered), (false, .notFound): .nothing
        case (true, .requiresApproval): .reportDisabledInSettings
        case (true, _): .register
        case (false, _): .unregister
    }
}

/// Returns why Looper's login item couldn't be brought in line with the config
@MainActor
func syncStartAtLogin(isWanted: Bool) -> ConfigParseDiagnostic? {
    if isUnitTest { return nil }
    if isDebug {
        if isWanted { print("'start-at-login = true' has no effect in debug builds") }
        return nil
    }
    let service = SMAppService.mainApp
    let backtrace = ConfigBacktrace.rootKey("start-at-login")
    do {
        switch startAtLoginStep(isWanted: isWanted, service.status) {
            case .nothing: return nil
            case .register: try service.register()
            case .unregister: try service.unregister()
            case .reportDisabledInSettings:
                return .init(backtrace, "\(looperAppName) is turned off in System Settings > General > Login Items & Extensions")
        }
        return nil
    } catch {
        return .init(backtrace, "Can't \(isWanted ? "add" : "remove") the login item: \(error.localizedDescription)")
    }
}
