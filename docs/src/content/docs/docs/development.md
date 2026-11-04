---
title: Development
description: Build Looper from source, run the checks and release a version.
---

Looper is a single SwiftPM package: `Looper.app` (`Sources/AppBundle`), the `looper` CLI (`Sources/Cli`) and the code
they share (`Sources/Common`). These docs are an [Astro Starlight](https://starlight.astro.build) site in `docs/`. The
[architecture](/Looper/docs/architecture/) page explains how the code is organized.

## Requirements

- **Xcode**, for Swift, the macOS SDK, `actool` and `codesign`. Looper targets macOS 27 and has no Xcode project.
- **[devenv](https://devenv.sh/)**, for the development tools: `just`, `swiftformat`, `swiftlint`, `periphery`,
  `complgen`, Node and pnpm, and the git hooks (gitlint for Conventional Commits, Alejandra for Nix files). It only
  provides tools; the app is never built with Nix.

Run any recipe with `devenv shell -- just <recipe>`, or enter the environment with `devenv shell`.

## Recipes

| Recipe | What it does |
| --- | --- |
| `just check` | Generated sources up to date, strict build, tests and lint. Must pass before a commit. |
| `just run` | Builds the debug app (`Looper-Debug.app`) and (re)launches it. |
| `just build` | Debug build of every target, including tests. |
| `just test` | Unit tests. |
| `just app` | Debug bundle `.build/bundle/Looper-Debug.app`, with the `looper` CLI next to it. |
| `just cli <args>` | Runs the debug CLI. |
| `just generate` | Regenerates the CLI help from the command pages of these docs. |
| `just format`, `just lint` | Formats the code; checks the format, SwiftLint and Periphery. |
| `just docs` | Runs these docs locally. |
| `just completion` | Shell completions in `.build/completion`. |
| `just release` | Signed release zip of the version in `VERSION`, in `.build/dist`. |
| `just reset-permission` | Resets the Accessibility permission of the debug app. |
| `just clean` | Removes `.build`. |

Run `just` to list them all.

## The debug app

The debug app has its own bundle id (`com.mariovagomarzal.looper.debug`), socket and permission entry, so it runs next
to a release `Looper.app`. While it runs, the release app is disabled, and quitting it enables the release app again.

Its logs are in the unified log, under that subsystem:

```bash
/usr/bin/log show --last 5m --style compact --predicate 'subsystem == "com.mariovagomarzal.looper.debug"'
```

Use the full path: in zsh, `log` is a builtin.

## Code signing

macOS ties the Accessibility permission to the app's code signature: sign every build with the same identity, or grant
the permission again after each rebuild. Builds are signed with a `Looper Development` identity. To create it, open
**Keychain Access › Certificate Assistant › Create a Certificate…**, name it `Looper Development`, with identity type
**Self-Signed Root** and certificate type **Code Signing**.

To sign with another identity, set `LOOPER_CODESIGN_IDENTITY` or pass `--identity`; the identity `-` signs ad hoc.

## Generated sources

Every command has a page in `docs/src/content/docs/docs/commands/`. Its `description` and the `text` block under
**Synopsis** are also the CLI's help: `scripts/generate.sh` turns them into `cmdHelpGenerated.swift` and
`subcommandDescriptionsGenerated.swift`. After editing a command page, run `just generate` and commit the generated
sources with it.

`versionGenerated.swift` holds the next release with a `-dev` suffix, and `gitHashGenerated.swift` holds `SNAPSHOT`;
`just release` fills them in temporarily and restores them afterwards.

## Versions

`VERSION` is the only source of the version. Development builds report it with a `-dev` suffix, like `0.1.0-dev`. To
release, set `VERSION` to the new version, run `just generate` and commit to `main`.

## Continuous integration

- **Check** runs on pushes to `main` and on pull requests against it: `just check` on macOS, and the build of the
  website, which fails on broken internal links.
- **Release** runs when a push to `main` raises `VERSION`. It repeats the checks, builds the signed zip, creates the
  GitHub release with its tag, its checksum and notes from the Conventional Commits since the previous tag, and
  publishes the website. A version that isn't newer than the latest release publishes nothing.
- **Pages** publishes the website on its own when run by hand, to get a fix to the docs out without a release.

Signing needs the `Looper Development` identity as the `LOOPER_CERTIFICATE_P12` secret (the exported `.p12`, in base64)
and its password as `LOOPER_CERTIFICATE_PASSWORD`.

## Conventions

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org).
- Strict memory safety is on, warnings are errors, and Periphery rejects unused code.
- Use `Task.startUnstructured` rather than `Task {}`.

## Tips

- Open `Package.swift` in Xcode to debug with the IDE. Any editor with
  [sourcekit-lsp](https://github.com/swiftlang/sourcekit-lsp) understands the package directly.
- The built-in **Accessibility Inspector** shows the accessibility properties of windows.
- [DeskPad](https://github.com/Stengo/DeskPad) or [BetterDisplay](https://github.com/waydabber/BetterDisplay) emulate
  several monitors.
