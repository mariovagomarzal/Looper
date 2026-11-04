---
title: "layout"
description: "Change layout of the focused node to the given layout"
---

## Synopsis

```text
looper layout [-h|--help] [--window-id <window-id>|--workspace <workspace>] [--monitor <monitor>]
                 [--root] [--fail-if-noop]
                 (<target-layout>)...
looper layout [-h|--help] --for-next-detected-window (tiling|floating)
```

Change layout of the focused node to the given layout

## Options

- `-h, --help`: Print help

- `--window-id <window-id>`: Act on the specified window instead of the focused window.
  A window ID, or one of:
  `focused` (the focused window),
  `pointer` (the window under the mouse pointer),
  `wheel` (the window that was under the mouse pointer when the wheel opened; only valid in wheel actions and conditions).
  The flag takes precedence over `LOOPER_WINDOW_ID` and `LOOPER_WORKSPACE` [environment variables](/Looper/docs/concepts/commands/#environment-variables).

- `--workspace <workspace>`: Act on the specified workspace instead of the focused workspace.
  The flag takes precedence over `LOOPER_WINDOW_ID` and `LOOPER_WORKSPACE` environment variables.

- `--monitor <monitor>`: Act on the visible workspace of the specified monitor, or, together with `--workspace`, look the workspace name up
  among the workspaces of that monitor.
  Possible values of `<monitor>`: `(left|down|up|right|next|prev|focused|pointer|wheel|<monitor-pattern>)`.
  Directions, `next` and `prev` are relative to the focused monitor.
  The `wheel` monitor is the one that was under the mouse pointer when the wheel opened, and is only valid in wheel actions.
  See [`focus-monitor`](/Looper/docs/commands/focus-monitor/) for monitor patterns.
  Requires `--root`.

- `--root`: Instead of the focused window, change the layout of the workspace tiling root node.
  When you use this flag, `tiling` and `floating` become invalid values for `<target-layout>`.

- `--fail-if-noop`: Exit with non-zero exit code if already in the requested layout.
  When you use this flag, the command permits only one `<target-layout>` argument.

- `--for-next-detected-window`: Don't change the layout of any currently existing window.
  Instead, schedule the layout change, and apply it to the next window that Looper detects.

  The scheduled layout change is applied both before and after the [on-window-detected callbacks](/Looper/docs/guides/window-rules/) are run,
  so that the callbacks observe the scheduled layout, and so that the scheduled layout wins over the callbacks.
  Running the `layout --for-next-detected-window` command again replaces the previously scheduled layout change.

  When you use this flag, the command permits exactly one `<target-layout>` argument,
  and `tiling` and `floating` are its only valid values.
  The flag is incompatible with all the other flags.

## Arguments

- `<target-layout>`: Possible values:

  * `h_tiles|v_tiles|h_accordion|v_accordion` - Change both tiling layout and orientation in one go
  * `tiles|accordion` - Change tiling layout but preserve orientation
  * `horizontal|vertical` - Change orientation but preserve layout
  * `tiling|floating` - Toggle between floating/tiling mode

  If several `<target-layout>` are supplied, then the first one that doesn't describe the currently active layout is applied.

## Examples

- Toggle between `floating` and `tiling` layouts (order of args doesn't matter):
  ```bash
  looper layout floating tiling
  ```

- Toggle orientation (order of args doesn't matter):
  ```bash
  looper layout horizontal vertical
  ```

- Toggle between `tiles` and `accordion` layouts (order of args doesn't matter):
  ```bash
  looper layout tiles accordion
  ```

- Switch to `tiles` layout. Toggle the layout orientation if already in `tiles` layout:
  ```bash
  looper layout tiles horizontal vertical
  ```

- Make the next window that opens floating:
  ```bash
  looper layout floating --for-next-detected-window
  ```
