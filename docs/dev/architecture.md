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

### Hotkeys

Bindings are captured with a `CGEventTap` (`HotkeyEventTap.swift`), not with Carbon's `RegisterEventHotKey`, because
Carbon can't tell left and right modifiers apart. The tap reads the device dependent bits of the event flags
(`PressedModifiers`) and matches them against the bindings of the active mode (`HotkeyModifiers.matches`). Sided
bindings (`lalt-h`) win over generic ones (`alt-h`).

- The tap runs on its own thread with a snapshot of the active bindings, so typing never waits for the main thread.
  Matched bindings are run on the main actor.
- A swallowed key down also swallows its key up. Autorepeat key downs are swallowed without running the binding again.
- macOS disables slow taps; the callback re-enables it. Creating the tap requires the Accessibility permission, so the
  thread retries until it's granted.
- While Secure Input is on (password fields), macOS doesn't deliver key events to taps, so bindings don't work there.

## Wheel subsystem

Sources/AppBundle/wheel/

- `WheelConfig.swift`: `wheel.*` config. Profiles are resolved at parse time: every profile starts from the style of
  `default`, and `extends` also inherits the actions of another profile. Actions are bound per (slot, finish) pair.
- `WheelTapMachine.swift`: pure state machine driven by the hotkey tap (held modifiers, clicks and keys). It decides
  when the wheel opens, switches profile, finishes or cancels. Its effects are applied on the main actor.
- `WheelController.swift`: the panel, pointer tracking (`WheelPointer`, with edge overshoot) and running the bound
  action in a light refresh session.
- `WheelView.swift`: SwiftUI view, selection zones (dead zone, center, eight directions) and animatable shapes.
- `wheel open|cancel` commands open the wheel without holding keys, for bindings, scripts and the CLI.
- `WheelPreview.swift`: previews of the release action of the selection, drawn in one transparent panel per screen.
  `place`, `fullscreen` and `focus` are computed directly (`FocusCommand.destination`; floating windows seen as tiling
  ones go through `FloatingAsTilingPlan`, whose frames are read first and applied synchronously in a snapshot).
- `WheelSimulation.swift`: previews of commands that rearrange windows, alone or in a shell (`&&`, `||`, `;`, run like
  `Shell.run`, normalizing the tree after every command). The commands are applied for real to the tree, the frames are
  computed with `layoutFrames` (a side effect free mirror of `layoutWorkspace`), and `TreeSnapshot` puts the tree back
  exactly as it was: same node objects, order, weights, layouts, MRU orders, focus and visible workspaces. Everything
  is synchronous on the main actor, so nothing else can observe the tree in between. That's why commands expose
  synchronous entry points (`MoveCommand.apply`, `SwapCommand.apply`, `LayoutCommand.applySynchronously`). A window
  that floats keeps its position and gets its last floating size, like `layout floating` does. The snapshot covers
  every workspace of the active native Space of each monitor, because commands may move windows and whole workspaces
  between monitors and change which workspace is visible; workspaces and containers created meanwhile are removed.
  Taking it must not create anything, so it avoids accessors like `rootTilingContainer` that create what is missing.
  `WheelSimulationTest` checks that the mirror matches the real layout and that simulations leave no trace.
- Finished gestures are logged in the `wheel` category of the os log.

## Tree Model subsystem

Sources/AppBundle/tree/

```
Monitor
└── WorkspacesContainer (one per native macOS Space seen on the monitor)
    └── Workspace (names are unique only inside their container)
        ├── TilingContainer (root) → TilingContainer… → Window
        ├── FloatingWindowsContainer → Window
        └── macOS fullscreen / hidden app windows containers → Window
```

### Workspaces per monitor and per native Space

Every (monitor, native Space) pair owns an independent set of workspaces. Workspace names are resolved in the
container of the focused workspace, so `workspace 2` means "workspace 2 of the focused monitor and its active Space".
`--monitor` (on `workspace`, `move-node-to-workspace` and the commands with `--workspace`) resolves them in the active
Space of another monitor instead (`MonitorTarget.resolveWorkspacesContainer`). `move-workspace-to-monitor` and
`swap-workspace-with-monitor` move the contents of workspaces (`WorkspaceContents`), never the workspaces themselves,
since every monitor has its own workspaces with the same names.

Native Spaces are read, never driven (`Sources/AppBundle/model/NativeSpaces.swift`):
- Private SkyLight functions, resolved at runtime with `dlsym`, report the active Space of every display and the
  Space of every window. They don't require disabling SIP. If they are unavailable, every monitor has a single
  container (`spaceId == nil`).
- Looper never moves windows between Spaces. When a window shows up on a hidden Space (Mission Control, "Assign To",
  the app moved it, its Space was removed), `reconcileWindowsWithNativeSpaces` treats it as a newly opened window of
  that Space. Moves between two Spaces that are both shown (two monitors) are left to Looper's layout.
- Windows of hidden Spaces are never laid out or hidden in a corner.
- When the active Space changes, focus moves to the visible workspace of the new Space unless macOS already focused a
  window there.
- Containers of removed Spaces are garbage collected once their windows have moved elsewhere.
- Windows of hidden Spaces are invisible (`WindowLifeStatus.invisible`). A window moved into a hidden Space takes
  its weight from those invisible siblings, see `TreeNode.bind`.

## Layout subsystem

todo

Sources/AppBundle/layout/
