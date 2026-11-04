---
title: "split"
description: "Split focused window"
---

## Synopsis

```text
looper split [-h|--help] [--window-id <window-id>] (horizontal|vertical|opposite)
```

The `split` command exists solely for compatibility with i3.
Unless you're hardcore i3 user who knows what they are doing, it's recommended to use `join-with`

**If the parent of focused window contains more than one child**, then the command

1. Creates a new tiling container
1. Replaces the focused window with the container
1. Puts the focused window into the container as its only child

The argument configures orientation of the newly created container.
With `opposite`, the orientation is the opposite of the parent container's.

**If the parent of the focused window contains only a single child** (the window itself), then `split` command changes the orientation of the parent container

:::caution
The `split` command has no effect if `enable-normalization-flatten-containers` is turned on.
:::
Consider using `join-with` if you want to keep `enable-normalization-flatten-containers` enabled

## Options

- `-h, --help`: Print help

- `--window-id <window-id>`: Act on the specified window instead of the focused window.
  A window ID, or one of:
  `focused` (the focused window),
  `pointer` (the window under the mouse pointer),
  `wheel` (the window that was under the mouse pointer when the wheel opened; only valid in wheel actions and conditions).
  The flag takes precedence over `LOOPER_WINDOW_ID` and `LOOPER_WORKSPACE` [environment variables](/Looper/docs/concepts/commands/#environment-variables).
