---
title: "macos-native-minimize"
description: "Minimize focused window"
---

## Synopsis

```text
looper macos-native-minimize [-h|--help] [--window-id <window-id>]
```

Minimize focused window

## Options

- `-h, --help`: Print help

- `--window-id <window-id>`: Act on the specified window instead of the focused window.
  A window ID, or one of:
  `focused` (the focused window),
  `pointer` (the window under the mouse pointer),
  `wheel` (the window that was under the mouse pointer when the wheel opened; only valid in wheel actions and conditions).
  The flag takes precedence over `LOOPER_WINDOW_ID` and `LOOPER_WORKSPACE` [environment variables](/Looper/docs/concepts/commands/#environment-variables).
