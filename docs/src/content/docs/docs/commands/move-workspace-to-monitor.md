---
title: "move-workspace-to-monitor"
description: "Move the windows of a workspace to the workspace of the same name on another monitor"
---

## Synopsis

```text
looper move-workspace-to-monitor [-h|--help] [--workspace <workspace>] [--wrap-around]
                                    (left|down|up|right|next|prev)
looper move-workspace-to-monitor [-h|--help] [--workspace <workspace>] [--] (focused|pointer|wheel|<monitor-pattern>...)
```

Move the windows of a workspace to the workspace of the same name on another monitor

Workspace names belong to a monitor, so every monitor has its own workspace '3'.
This command moves everything the workspace holds (its tiling tree with its layout, floating windows, and windows in
macOS native fullscreen or of hidden apps) into the workspace with the same name on the target monitor.
That workspace becomes visible and focused.

The sizes of the tiling tree are scaled to the target monitor.
Floating windows keep their position relative to the monitor.
If the target workspace already has windows, they stay, and the moved tiling tree joins them as a nested container.

## Options

- `-h, --help`: Print help

- `--workspace <workspace>`: The workspace to move, among the workspaces of the focused monitor.
  The default is the focused workspace.

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
