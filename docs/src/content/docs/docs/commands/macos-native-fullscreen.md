---
title: "macos-native-fullscreen"
description: "Toggle macOS fullscreen for the focused window"
---

## Synopsis

```text
looper macos-native-fullscreen [-h|--help] [--window-id <window-id>]
looper macos-native-fullscreen [-h|--help] [--window-id <window-id>] [--fail-if-noop] on
looper macos-native-fullscreen [-h|--help] [--window-id <window-id>] [--fail-if-noop] off
```

Toggle macOS fullscreen for the focused window

## Options

- `-h, --help`: Print help
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
