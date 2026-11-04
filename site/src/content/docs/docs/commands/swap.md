---
title: "swap"
description: "Swaps the focused window with another window."
---

## Synopsis

```text
looper swap [-h|--help] [--window-id <window-id>] [--swap-focus]
               [--wrap-around] (left|down|up|right|dfs-next|dfs-prev)
```

Swaps the focused window with another window.

The operation is equivalent to dragging a window with the mouse.

## Options

- `-h, --help`: Print help

- `--window-id <window-id>`: Act on the specified window instead of the focused window.
  A window ID, or one of:
  `focused` (the focused window),
  `pointer` (the window under the mouse pointer),
  `wheel` (the window that was under the mouse pointer when the wheel opened; only valid in wheel actions and conditions).
  The flag takes precedence over `LOOPER_WINDOW_ID` and `LOOPER_WORKSPACE` [environment variables](/Looper/docs/concepts/commands/#environment-variables).

- `--swap-focus`: Swap focus away from the currently focused window.
  By default, this command does not change the focused window.

- `--wrap-around`: Wrap around if the window is at the edge of the workspace (for `(left|down|up|right)`) or the start/end of the depth first order (for `(dfs-next|dfs-prev)`).

## Arguments

- `(left|down|up|right)`: Swaps the focused window with the nearest window in the given direction.

- `(dfs-next|dfs-prev)`: Swaps the focused window with the next or previous window in the depth-first order (top-to-bottom and left-to-right) of windows in the current workspace tree.
