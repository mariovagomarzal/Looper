---
title: "swap-workspace-with-monitor"
description: "Swap the windows of the focused workspace with the visible workspace of another monitor"
---

## Synopsis

```text
looper swap-workspace-with-monitor [-h|--help] [--wrap-around] (left|down|up|right|next|prev)
looper swap-workspace-with-monitor [-h|--help] [--] (focused|pointer|wheel|<monitor-pattern>...)
```

Swap the windows of the focused workspace with the visible workspace of another monitor

What is shown on the two monitors is exchanged: everything each workspace holds (its tiling tree with its layout,
floating windows, and windows in macOS native fullscreen or of hidden apps) moves to the other one.
Each monitor keeps its workspaces and their names.
The focus follows the focused window to the other monitor.

The sizes of the tiling trees are scaled to their new monitor.
Floating windows keep their position relative to the monitor.

## Options

- `-h, --help`: Print help
- `--wrap-around`: Make it possible to wrap around the movement

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
