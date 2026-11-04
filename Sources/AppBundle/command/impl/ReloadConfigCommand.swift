import AppKit
import Common

struct ReloadConfigCommand: Command {
    let args: ReloadConfigCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        let result = await reloadConfig_nonCancellable(args: args)
        if !result.stdout.isEmpty {
            io.out(result.stdout)
        }
        if !result.stderr.isEmpty {
            io.err(result.stderr)
        }
        return .from(bool: result.isOk)
    }
}

struct ReloadConfigResult {
    let isOk: Bool
    let stdout: String
    let stderr: String
}

@MainActor func reloadConfig_nonCancellable(
    args: ReloadConfigCmdArgs = ReloadConfigCmdArgs(rawArgs: []),
    forceConfigUrl: URL? = nil,
) async -> ReloadConfigResult {
    let result = readConfig(forceConfigUrl: forceConfigUrl)
    let parseResult = result.parseConfigResult
    let warningsAsErrors = args.warningsAsErrors

    var warningDiagnostics = parseResult.warnings
    if parseResult.allowReloadConfig && !args.dryRun, let warning = syncStartAtLogin(isWanted: parseResult.config.startAtLogin) {
        warningDiagnostics.append(warning)
    }
    var errors = parseResult.errors.map { $0.description(.error) }
    var warnings = warningDiagnostics.map { $0.description(.warning) }
    let containsWarnings = !warnings.isEmpty

    if !args.noGui {
        if !errors.isEmpty || (warningsAsErrors && !warnings.isEmpty) {
            let path = (result.configUrl.absoluteURL.path as NSString).abbreviatingWithTildeInPath
            let diagnostics = ConfigDiagnostics(path: path, errors: parseResult.errors, warnings: warningDiagnostics)
            MessageModel.shared.message = Message(content: .configDiagnostics(diagnostics))
        } else {
            MessageModel.shared.message = nil
        }
    }
    if parseResult.allowReloadConfig && !args.dryRun {
        TrayMenuModel.shared.lastReloadConfigContainedWarnings = containsWarnings
        config = parseResult.config
        configUrl = result.configUrl
        await activateMode_nonCancellable(activeMode)
        syncFocusFollowsMouse(config)
        syncConfigFileWatcher()
    }

    if warningsAsErrors {
        errors += warnings
        warnings = []
    }

    return ReloadConfigResult(
        isOk: errors.isEmpty,
        stdout: errors.joined(separator: "\n\n"),
        stderr: warnings.joined(separator: "\n\n"),
    )
}
