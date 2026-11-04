---
title: "close"
description: "Close the focused window"
---

## Synopsis

```text
looper close [-h|--help] [--quit-if-last-window] [--window-id <window-id>]
```

Close the focused window

Normally, you don’t need to use this command, because macOS offers its own `cmd+w` binding.
You might want to use the command from CLI for scripting purposes

## Options

- `-h, --help`: Print help
- `--quit-if-last-window`: Quit the app instead of closing if it's the last window of the app

- `--window-id <window-id>`: Act on the specified window instead of the focused window.
  A window ID, or one of:
  `focused` (the focused window),
  `pointer` (the window under the mouse pointer),
  `wheel` (the window that was under the mouse pointer when the wheel opened; only valid in wheel actions and conditions).
  The flag takes precedence over `LOOPER_WINDOW_ID` and `LOOPER_WORKSPACE` [environment variables](/Looper/docs/concepts/commands/#environment-variables).
