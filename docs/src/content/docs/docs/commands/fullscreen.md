---
title: "fullscreen"
description: "Toggle the fullscreen mode for the focused window"
---

## Synopsis

```text
looper fullscreen [-h|--help]     [--window-id <window-id>] [--no-outer-gaps]
looper fullscreen [-h|--help] on  [--window-id <window-id>] [--no-outer-gaps] [--fail-if-noop]
looper fullscreen [-h|--help] off [--window-id <window-id>] [--fail-if-noop]
```

Toggle the fullscreen mode for the focused window

Switching to a different tiling window within the same workspace while the current focused window is in fullscreen mode results in the fullscreen window exiting fullscreen mode.

## Options

- `-h, --help`: Print help
- `--no-outer-gaps`: Remove the outer gaps when in fullscreen mode
- `--fail-if-noop`: Exit with non-zero exit code if already fullscreen or already not fullscreen

- `--window-id <window-id>`: Act on the specified window instead of the focused window.
  A window ID, or one of:
  `focused` (the focused window),
  `pointer` (the window under the mouse pointer),
  `wheel` (the window that was under the mouse pointer when the wheel opened; only valid in wheel actions and conditions).
  The flag takes precedence over `LOOPER_WINDOW_ID` and `LOOPER_WORKSPACE` [environment variables](/Looper/docs/concepts/commands/#environment-variables).

## Arguments

- `on, off`: with `on`, the window enters fullscreen mode, and with `off`, it exits it.
  Toggle between the two if not specified
