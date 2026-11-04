---
title: "move-node-to-workspace"
description: "Move the focused window to the specified workspace"
---

## Synopsis

```text
looper move-node-to-workspace [-h|--help] [--focus-follows-window] [--wrap-around]
                                 [--stdin|--no-stdin] [--monitor <monitor>]
                                 (next|prev)
looper move-node-to-workspace [-h|--help] [--focus-follows-window] [--fail-if-noop]
                                 [--window-id <window-id>] [--monitor <monitor>] [--] <workspace-name>
```

Move the focused window to the specified workspace

With `next` or `prev`, it's identical to `workspace (next|prev)`

## Options

- `-h, --help`: Print help

- `--monitor <monitor>`: Move the window to a workspace of another monitor.
  Workspace names, `next` and `prev` refer to the workspaces of that monitor, `next` and `prev` relative to its
  visible workspace.
  Possible values of `<monitor>`: `(left|down|up|right|next|prev|focused|pointer|wheel|<monitor-pattern>)`.
  Directions, `next` and `prev` are relative to the monitor of the window.
  The `wheel` monitor is the one that was under the mouse pointer when the wheel opened, and is only valid in wheel actions.
  See [`focus-monitor`](/Looper/docs/commands/focus-monitor/) for monitor patterns.
- `--wrap-around`: Make it possible to jump between first and last workspaces using (next|prev)
- `--fail-if-noop`: Exit with non-zero code if move window to workspace it already belongs to

- `--focus-follows-window`: Make sure that the window in question receives focus after moving.
  This flag is a shortcut for manually running [`workspace`](/Looper/docs/commands/workspace/)/[`focus`](/Looper/docs/commands/focus/) after `move-node-to-workspace` successful execution.

- `--window-id <window-id>`: Act on the specified window instead of the focused window.
  A window ID, or one of:
  `focused` (the focused window),
  `pointer` (the window under the mouse pointer),
  `wheel` (the window that was under the mouse pointer when the wheel opened; only valid in wheel actions and conditions).
  The flag takes precedence over `LOOPER_WINDOW_ID` and `LOOPER_WORKSPACE` [environment variables](/Looper/docs/concepts/commands/#environment-variables).

- `--stdin`: Read the list of workspaces from stdin.
  Incompatible with `--no-stdin`

- `--no-stdin`: Ignore the list of workspaces from stdin, even if provided.
  Incompatible with `--stdin`

## Arguments

- `(next|prev)`: Move window to next or prev workspace
- `<workspace-name>`: Specifies workspace name where to move window to
