---
title: "workspace"
description: "Focus the specified workspace"
---

## Synopsis

```text
looper workspace [-h|--help] [--monitor <monitor>] [--auto-back-and-forth] [--fail-if-noop] [--] <workspace-name>
looper workspace [-h|--help] [--monitor <monitor>] [--wrap-around] [--stdin|--no-stdin] (next|prev)
```

**1. <workspace-name> syntax**

Focus the specified workspace

Every monitor, and every native macOS Space (desktop) of a monitor, has its own independent set of workspaces.
A workspace name refers to the workspace with that name on the focused monitor and its active Space.

**2. (next|prev) syntax**

Focuses next or previous workspace in **the list**.

- If `--stdin` is specified, then **the list** is taken from stdin
- Otherwise, **the list** is defined as all workspaces (even empty ones) of the focused monitor and its active Space
in alphabetical order

## Options

- `-h, --help`: Print help

- `--monitor <monitor>`: Switch the workspace of another monitor, and focus it.
  Workspace names, `next` and `prev` refer to the workspaces of that monitor.
  Possible values of `<monitor>`: `(left|down|up|right|next|prev|focused|pointer|wheel|<monitor-pattern>)`.
  Directions, `next` and `prev` are relative to the focused monitor.
  The `wheel` monitor is the one that was under the mouse pointer when the wheel opened, and is only valid in wheel actions.
  See [`focus-monitor`](/Looper/docs/commands/focus-monitor/) for monitor patterns.
- `--wrap-around`: Make it possible to jump between first and last workspaces using `(next|prev)`

- `--auto-back-and-forth`: Automatic `back-and-forth` when switching to already focused workspace.
  Incompatible with `--fail-if-noop`

- `--fail-if-noop`: Exit with non-zero exit code if switch to the already focused workspace.
  Incompatible with `--auto-back-and-forth`

- `--stdin`: Read the list of workspaces from stdin.
  Incompatible with `--no-stdin`

- `--no-stdin`: Ignore the list of workspaces from stdin, even if provided.
  Incompatible with `--stdin`

## Arguments

- `<workspace-name>`: Workspace name to focus.

## Examples

- Go to the next non empty workspace on the focused monitor:
  ```bash
  looper list-workspaces --monitor focused --empty no | looper workspace --stdin next
  ```
