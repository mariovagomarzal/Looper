---
title: "balance-sizes"
description: "Balance sizes of all windows in the current workspace"
---

## Synopsis

```text
looper balance-sizes [-h|--help] [--workspace <workspace>] [--monitor <monitor>]
```

Balance sizes of all windows in the current workspace

## Options

- `-h, --help`: Print help

- `--workspace <workspace>`: Act on the specified workspace instead of the focused workspace.
  The flag takes precedence over `LOOPER_WINDOW_ID` and `LOOPER_WORKSPACE` environment variables.

- `--monitor <monitor>`: Act on the visible workspace of the specified monitor, or, together with `--workspace`, look the workspace name up
  among the workspaces of that monitor.
  Possible values of `<monitor>`: `(left|down|up|right|next|prev|focused|pointer|wheel|<monitor-pattern>)`.
  Directions, `next` and `prev` are relative to the focused monitor.
  The `wheel` monitor is the one that was under the mouse pointer when the wheel opened, and is only valid in wheel actions.
  See [`focus-monitor`](/Looper/docs/commands/focus-monitor/) for monitor patterns.
