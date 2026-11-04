---
title: "move"
description: "Move the focused window in the given direction"
---

## Synopsis

```text
looper move [-h|--help] [--window-id <window-id>] [--boundaries <boundary>]
               [--boundaries-action <boundary-action>] [--fail-if-fullscreen]
               [--fail-if-macos-native-fullscreen] (left|down|up|right) [<distance>]
```

Move the focused window in the given direction. See the "Examples" section for more details.

A tiling window moves to the next place in the tree.
A floating window moves by `<distance>` and stops at the edge of the usable area of its monitor.
The distance is a number of points (`40`) or a percentage of the usable area along the direction (`10%`).
The default is: `5%`.
Distances only apply to floating windows.

When a floating window is already at the edge, `--boundaries all-monitors-outer-frame` takes it to the monitor in that
direction, against the edge it comes through.
Otherwise, `--boundaries-action fail` exits with non-zero code, and the other actions leave the window where it is.

Deprecated name: `move-through`

## Options

- `-h, --help`: Print help

- `--window-id <window-id>`: Act on the specified window instead of the focused window.
  A window ID, or one of:
  `focused` (the focused window),
  `pointer` (the window under the mouse pointer),
  `wheel` (the window that was under the mouse pointer when the wheel opened; only valid in wheel actions and conditions).
  The flag takes precedence over `LOOPER_WINDOW_ID` and `LOOPER_WORKSPACE` [environment variables](/Looper/docs/concepts/commands/#environment-variables).

- `--boundaries <boundary>`: Defines move boundaries.
  Possible values of `<boundary>`: `(workspace|all-monitors-outer-frame)`.
  The default is: `workspace`

- `--boundaries-action <boundary-action>`: Defines the behavior when requested to move across the `<boundary>`.
  For floating windows, `create-implicit-container` behaves like `stop`.
  Possible values of `<boundary-action>`: `(stop|fail|create-implicit-container)`.
  The default is: `create-implicit-container`

- `--fail-if-fullscreen`: Exit with non-zero code if the target window is fullscreen by the `fullscreen` command.

- `--fail-if-macos-native-fullscreen`: Exit with non-zero code if the target window is in macOS native fullscreen.

## Examples

1. Given this layout

```bash
h_tiles
├── window 1 (focused)
└── window 2
```

After `move right`, the layout is:

```bash
h_tiles
├── window 2
└── window 1 (focused)
```

1. Given this layout

```bash
h_tiles
├── window 1
├── window 2 (focused)
└── v_tiles
    ├── window 3
    └── window 4
```

After `move right`, the layout is:

```bash
h_tiles
├── window 1
└── v_tiles
    ├── window 3
    ├── window 2 (focused)
    └── window 4
```

1. Given this layout

```bash
h_tiles
├── window 1
└── v_tiles
    ├── window 3
    ├── window 2 (focused)
    └── window 4
```

After `move left`, the layout is:

```bash
h_tiles
├── window 1
├── window 2 (focused)
└── v_tiles
    ├── window 3
    └── window 4
```

1. **Implicit container example**

In some cases, `move` needs to implicitly create a container to fulfill your command.

Given this layout

```bash
h_tiles
├── window 1
├── window 2 (focused)
└── window 3
```

After `move up`, the layout is:

```bash
v_tiles
├── window 2 (focused)
└── h_tiles
    ├── window 1
    └── window 3
```

The `v_tiles` container is created implicitly.

**Remark**: If `--boundaries` is set to `all-monitors-outer-frame` and there is a monitor in the `up` direction,
the implicit container isn't created.

Instead, `window 2` would be moved to the monitor above the current.
