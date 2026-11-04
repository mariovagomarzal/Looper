---
title: Development
description: Build Looper from source, run the checks and find your way around the code.
---

Looper is a single SwiftPM package: `Looper.app` (`Sources/AppBundle`), the `looper` CLI (`Sources/Cli`) and the code
they share (`Sources/Common`). These docs are an [Astro Starlight](https://starlight.astro.build) site in `site/`.
For the architecture, read [`docs/dev/architecture.md`](https://github.com/mariovagomarzal/Looper/blob/main/docs/dev/architecture.md).

## Requirements

- **Xcode**, for Swift, the macOS SDK, `actool` and `codesign`. There is no Xcode project: open `Package.swift` to use
  the IDE.
- **[devenv](https://devenv.sh/)**, for the development tools: `just`, `swiftformat`, `swiftlint`, `periphery`,
  `complgen`, Node and pnpm, and the git hooks. It only provides tools; the app is never built with Nix.

Run any recipe with `devenv shell -- just <recipe>`, or enter the environment with `devenv shell`.

## Recipes

| Recipe | What it does |
| --- | --- |
| `just check` | Generated sources up to date, strict build, tests and lint. Must pass before a commit. |
| `just run` | Builds the debug app (`Looper-Debug.app`) and (re)launches it. |
| `just test` | Unit tests. |
| `just generate` | Regenerates the CLI help from the command pages of these docs. |
| `just release` | Signed release of the version in `VERSION`, in `.build/dist`, tagged `v<version>`. |
| `just site` | Runs these docs locally. |
| `just completion` | Shell completions in `.build/completion`. |

Run `just` to list them all.

The debug app has its own bundle id (`com.mariovagomarzal.looper.debug`), so it runs next to a release `Looper.app`.
Its logs are in the unified log, under that subsystem:

```bash
/usr/bin/log show --last 5m --style compact --predicate 'subsystem == "com.mariovagomarzal.looper.debug"'
```

## Code signing

macOS ties the Accessibility permission to the app's code signature: sign every build with the same identity, or grant
the permission again after each rebuild. Builds are signed with a `Looper Development` identity. To create it, open
**Keychain Access › Certificate Assistant › Create a Certificate…**, name it `Looper Development`, with identity type
**Self-Signed Root** and certificate type **Code Signing**.

To sign with another identity, set `LOOPER_CODESIGN_IDENTITY` or pass `--identity`; the identity `-` signs ad hoc.

## Commands and their help

Every command has a page in `site/src/content/docs/docs/commands/`. Its `description` and the `text` block under
**Synopsis** are also the CLI's `--help`: after editing them, run `just generate` and commit the generated sources.

## Conventions

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org).
- Strict memory safety is on, warnings are errors, and Periphery rejects unused code.
- Use `Task.startUnstructured` rather than `Task {}`.
