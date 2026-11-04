---
title: "move-node-to-monitor"
description: "Move window to monitor targeted by relative direction, by order, or by pattern"
---

## Synopsis

```text
looper move-node-to-monitor [-h|--help] [--window-id <window-id>] [--focus-follows-window]
                               [--wrap-around] (left|down|up|right|next|prev)
looper move-node-to-monitor [-h|--help] [--window-id <window-id>] [--focus-follows-window]
                               [--fail-if-noop] [--] (focused|pointer|wheel|<monitor-pattern>...)
```

Move window to monitor targeted by relative direction, by order, or by pattern

## Options

- `-h, --help`: Print help
- `--wrap-around`: Make it possible to wrap around the movement

- `--focus-follows-window`: Make sure that the window in question receives focus after moving.
  This flag is a shortcut for manually running [`workspace`](/Looper/docs/commands/workspace/)/[`focus`](/Looper/docs/commands/focus/) after `move-node-to-monitor` successful execution.

- `--fail-if-noop`: Exit with non-zero code if moving window to monitor it already belongs to

- `--window-id <window-id>`: Act on the specified window instead of the focused window.
  A window ID, or one of:
  `focused` (the focused window),
  `pointer` (the window under the mouse pointer),
  `wheel` (the window that was under the mouse pointer when the wheel opened; only valid in wheel actions and conditions).
  The flag takes precedence over `LOOPER_WINDOW_ID` and `LOOPER_WORKSPACE` [environment variables](/Looper/docs/concepts/commands/#environment-variables).

## Arguments

- `(left|down|up|right)`: The monitor in that direction

- `(next|prev)`: The next or previous monitor, in the order they appear in the tray icon

- `focused`: The monitor with the focused workspace

- `pointer`: The monitor under the mouse pointer

- `wheel`: The monitor that was under the mouse pointer when the wheel opened.
  Only valid in wheel actions and conditions

- `<monitor-pattern>...`: The first matching monitor.
  Multiple monitor patterns are useful for different monitor configurations.
  A monitor pattern is a 1-based sequence number of the monitor (from left to right), `main`, `secondary` (the
  non-main monitor when there are exactly two) or a case-insensitive regex substring of the monitor name
