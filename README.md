<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="resources/brand/icon-animated.svg">
    <img src="resources/brand/icon-animated-light.svg" width="160" alt="Looper icon: the ring of the radial wheel with the macOS window buttons in its center">
  </picture>
</p>

<h1 align="center">Looper</h1>

> [!WARNING]
> **Work in progress.** Looper is a fork of [AeroSpace](https://github.com/nikitabobko/AeroSpace) by Nikita Bobko
> and is currently under construction. Expect breaking changes, missing documentation and rough edges.

Looper is a personal tiling window manager for macOS, built on AeroSpace's tree-based tiling and adapted to the
author's workflow.

## Goals

- Keep AeroSpace's tree-based tiling, commands and plain-text configuration.
- Add a radial wheel, inspired by [Loop](https://github.com/MrKai77/Loop), that runs Looper commands,
  shell commands and other actions, with previews for window-management actions.
- Wheel profiles activated by context or by an additional modifier key.
- Trackpad gestures (3- and 4-finger swipes and taps) bound to commands per mode, like keys.
- Independent workspaces per monitor and per native macOS Space (desktop). Looper reads Spaces but never moves
  windows between them.

## Identity

| | |
| --- | --- |
| App | `Looper.app` (`com.mariovagomarzal.looper`) |
| CLI | `looper` |
| Config | `~/.looper.toml` or `${XDG_CONFIG_HOME}/looper/looper.toml` |
| Environment variables | `LOOPER_WINDOW_ID`, `LOOPER_WORKSPACE`, `LOOPER_FOCUSED_WORKSPACE`, `LOOPER_PREV_WORKSPACE` |

Command reference lives in [docs/commands/](./docs/commands) as Asciidoc sources (`looper-<command>.adoc`), which also generate
the CLI `--help` output. For now, the [AeroSpace guide](https://nikitabobko.github.io/AeroSpace/guide) describes
the shared concepts.

## Brand

The icon, its animated version and the one-color glyph live in [resources/brand/](./resources/brand) as SVG
(`icon.svg`, `icon-light.svg`, `icon-animated.svg`, `icon-animated-light.svg`, `glyph.svg`). The app icon in
`resources/Assets.xcassets` is `icon.svg` rendered at 1024 px.

## Credits

- [AeroSpace](https://github.com/nikitabobko/AeroSpace) by Nikita Bobko: Looper is a fork of it (MIT).
- [Loop](https://github.com/MrKai77/Loop) by Kai Azim: the radial wheel's design and interaction are modeled
  on Loop's radial menu. Looper's implementation is written from scratch and shares no code with Loop (GPL-3.0).

## Development

Looper is a single SwiftPM package built with the Xcode toolchain; development tools come from
[devenv](https://devenv.sh/) and tasks are [just](https://just.systems/) recipes:

```sh
devenv shell
just run    # build and launch Looper-Debug.app
just check  # strict build, tests and lint
```

See [docs/dev/development.md](./docs/dev/development.md) and [docs/dev/architecture.md](./docs/dev/architecture.md).

## License

MIT, like AeroSpace. See [LICENSE.txt](./LICENSE.txt) and [legal/](./legal).
