# Looper

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
- Per-monitor workspaces and awareness of native macOS Spaces.

## Identity

| | |
| --- | --- |
| App | `Looper.app` (`com.mariovagomarzal.looper`) |
| CLI | `looper` |
| Config | `~/.looper.toml` or `${XDG_CONFIG_HOME}/looper/looper.toml` |
| Environment variables | `LOOPER_WINDOW_ID`, `LOOPER_WORKSPACE`, `LOOPER_FOCUSED_WORKSPACE`, `LOOPER_PREV_WORKSPACE` |

Command reference lives in [docs/](./docs) as man page sources (`looper-<command>.adoc`), which also generate
the CLI `--help` output. For now, the [AeroSpace guide](https://nikitabobko.github.io/AeroSpace/guide) describes
the shared concepts.

## Development

See [dev-docs/development.md](./dev-docs/development.md) and [dev-docs/architecture.md](./dev-docs/architecture.md).

## License

MIT, like AeroSpace. See [LICENSE.txt](./LICENSE.txt) and [legal/](./legal).
