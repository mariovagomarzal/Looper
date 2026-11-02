# Architecture

## Definitions

**SwiftPM.** Swift Package Manager and build tool, i.e. the `swift` CLI.

## Repository layout

- `Package.swift`. The whole project is a single SwiftPM package; there is no Xcode project.
- `Sources/AppBundle/`. The `Looper.app` server: window management, commands, config, UI.
- `Sources/LooperApp/`. Tiny executable target with the SwiftUI `@main` entry point of the app.
- `Sources/Cli/`. The `looper` CLI client.
- `Sources/Common/`. Code shared by server and client, mainly command argument parsing and utilities.
- `Sources/Macros/`, `Sources/PrivateApi/`. Swift macros and the private `_AXUIElementGetWindow` bridge.
- `Tests/AppBundleTests/`. Unit tests. `Fixtures/axDumps/` holds recorded accessibility dumps of real windows.
- `resources/`. App resources: asset catalog and `default-config.toml`.
- `docs/commands/`. Asciidoc sources of each command; `scripts/generate.sh` turns their synopses into CLI help.
- `docs/config-examples/`. Example configurations.
- `scripts/`. Build scripts (`generate.sh`, `bundle.sh`, `release.sh`) and the shell completion grammar.

SwiftPM can't produce app bundles, so `scripts/bundle.sh` builds the `LooperApp` executable with SwiftPM and
assembles `Looper.app` around it: `Info.plist`, compiled assets (`actool`) and code signature.

## client/server interaction

`looper` CLI binary is client. `Looper.app` is server. Client and server talk to each other via predefined UNIX file.

Each time you run a CLI command:
1. Args are parsed by the client, args parsing errors are reported if any. Help is shown if `-h`/`--help` is passed.
1. If args are parsed successfully, the args are sent to the server
1. Server parses the args once again, and runs the command
1. Server returns stdout, stderr, and exit code to the client
1. Client shows stdout, stderr, and ends the process with the requested exit code

## Commands subsystem

todo

Sources/AppBundle/command/
Sources/Common/cmdArgs/

Command checklist:
- [ ] Documentation in `docs/commands/looper-*.adoc`, then `just generate`
- [ ] Do `--window-id` and/or `--workspace` flags make sense for the command?
- [ ] Shell completion `scripts/completion/grammar.bnf`

## TOML Config parse subsystem

todo

Sources/AppBundle/config/

## Tree Model subsystem

todo

Sources/AppBundle/tree/

## Layout subsystem

todo

Sources/AppBundle/layout/
