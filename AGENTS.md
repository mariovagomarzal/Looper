# AGENTS.md

Looper is a tiling window manager for macOS, forked from AeroSpace: a single SwiftPM package with the `Looper.app`
server (`Sources/AppBundle`), the `looper` CLI (`Sources/Cli`) and shared code (`Sources/Common`).
Read `docs/dev/architecture.md` before larger changes.

## Commands

Tools (just, swiftformat, swiftlint, periphery, Node and pnpm) come from devenv; Swift and the SDK come from the system Xcode.
Run everything through `devenv shell -- <command>`. Never build the app with Nix.

- `just check`: regenerated sources, strict build (warnings are errors), tests and lint. Must pass before a commit.
- `just test`, `swift test --filter <TestClass>`: tests.
- `just run`: builds and relaunches the debug app (`Looper-Debug`, logs under `com.mariovagomarzal.looper.debug`).
- `just generate`: after editing the command pages (`site/src/content/docs/docs/commands/*.md`), which generate the
  CLI help.
- `just site`: the website and docs (Astro Starlight in `site/`). `cd site && pnpm build` checks every internal link.

## Rules

- Strict memory safety is on: mark pointer expressions with `unsafe`; classes can't store unsafe types.
- Use `Task.startUnstructured`, never `Task {}` or `Task.init` (the lint fails).
- No unused code: Periphery runs in `just lint`.
- New config keys: parse errors as config diagnostics, document them in `resources/default-config.toml` (a test
  parses it) and add tests in `Tests/AppBundleTests`. Keep logic pure and testable apart from AppKit.
- Private frameworks (SkyLight, MultitouchSupport) are resolved at runtime, so Looper keeps working without them.
- Looper reads native Spaces but never moves windows between them.
- Read os logs with `/usr/bin/log` (`log` is a zsh builtin).

## Git

- Conventional Commits in English (gitlint checks them). Commit or push only when asked.
