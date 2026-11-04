---
title: "focus-monitor"
description: "Focus monitor by relative direction, by order, or by pattern"
---

## Synopsis

```text
looper focus-monitor [-h|--help] [--wrap-around] (left|down|up|right)
looper focus-monitor [-h|--help] [--wrap-around] (next|prev)
looper focus-monitor [-h|--help] [--] (focused|pointer|wheel|<monitor-pattern>...)
```

Focus monitor by relative direction, by order, or by pattern

## Options

- `-h, --help`: Print help
- `--wrap-around`: Make it possible to wrap around focus

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
