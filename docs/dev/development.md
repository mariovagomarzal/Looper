# Development

## Requirements

- Xcode (the app). It provides Swift, the macOS SDK, `actool` and `codesign`. Looper targets macOS 27 and is built
  with the Swift toolchain bundled with Xcode; the project contains no Xcode project file.
- [devenv](https://devenv.sh/) for the development tools: `just`, `swiftformat`, `swiftlint`, `periphery`,
  `complgen`, Node and pnpm (for the website), and the git hooks (gitlint for Conventional Commits, Alejandra for Nix files).
  devenv only provides tools; the app is never built with Nix.

Enter the environment with `devenv shell`, or run a single command with `devenv shell -- just <recipe>`.

## Code signing

macOS ties the Accessibility permission to the app's code signature. Sign every build with the same identity, or
the permission has to be granted again after each rebuild.

Builds are signed with the `Looper Development` identity by default. To create it:

1. Open `Keychain Access.app`
2. Menu → `Keychain Access` → `Certificate Assistant` → `Create a Certificate...`
   - Name: `Looper Development`
   - Identity Type: `Self-Signed Root`
   - Certificate Type: `Code Signing`

Use `LOOPER_CODESIGN_IDENTITY` (or `--identity`) to sign with another identity; `-` signs ad hoc.

## Recipes

Run `just` to list them all.

| Recipe | What it does |
| --- | --- |
| `just build` | Debug build of every target, including tests |
| `just test` | Unit tests |
| `just app` | Debug bundle `.build/bundle/Looper-Debug.app` and the `looper` CLI next to it |
| `just run` | Builds the debug bundle and (re)launches it |
| `just cli <args>` | Runs the debug CLI |
| `just generate` | Regenerates CLI help from the command pages of the docs |
| `just site` | Runs the website and docs locally |
| `just format` / `just lint` | SwiftFormat; SwiftFormat check, SwiftLint and Periphery |
| `just check` | Generated sources up to date, strict build, tests and lint |
| `just completion` | zsh, fish and bash completions in `.build/completion` |
| `just release` | Signed release zip of the version in `VERSION` in `.build/dist`, tagged `v<version>` (requires a clean working tree) |
| `just reset-permission` | Resets the Accessibility permission of the debug app |
| `just clean` | Removes `.build` |

The debug app uses its own bundle id (`com.mariovagomarzal.looper.debug`), socket and permission entry, so it
can run next to a release `Looper.app`. When the debug app starts, it disables the release one; quitting the
debug app re-enables it.

## Generated sources

`Sources/Common/cmdHelpGenerated.swift` and `Sources/Cli/subcommandDescriptionsGenerated.swift` are generated
from the command pages of the docs (`site/src/content/docs/docs/commands/*.md`: the `description` and the `text` block
under **Synopsis**) by `scripts/generate.sh` and committed. `versionGenerated.swift` holds
the next release with a `-dev` suffix and `gitHashGenerated.swift` holds `SNAPSHOT`; `just release` fills them in
temporarily and restores them afterwards.

## Versions

`VERSION` is the only source of the version. Development builds report it with a `-dev` suffix (`0.1.0-dev`). To
release, set `VERSION` to the new version, run `just generate`, commit, and run `just release`: it builds the signed
zip and tags the commit `v<version>`.

## Editors

- Open `Package.swift` in Xcode to debug with the IDE.
- Any editor with [sourcekit-lsp](https://github.com/swiftlang/sourcekit-lsp) understands the package directly.

## Tips

- Use the built-in "Accessibility Inspector.app" to inspect accessibility properties of windows.
- Use [DeskPad](https://github.com/Stengo/DeskPad) or [BetterDisplay](https://github.com/waydabber/BetterDisplay)
  to emulate several monitors.
