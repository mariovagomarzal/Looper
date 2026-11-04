---
title: "join-with"
description: "Put the focused window and the nearest node in the specified direction under a common parent container"
---

## Synopsis

```text
looper join-with [-h|--help] [--window-id <window-id>] (left|down|up|right)
```

Put the focused window and the nearest node in the specified direction under a common parent container

## Examples

Given this layout

```bash
h_tiles
├── window 1
├── window 2 (focused)
└── window 3
```

After `join-with right`, the layout is:

```bash
h_tiles
├── window 1
└── v_tiles
    ├── window 2 (focused)
    └── window 3
```

:::note
The `join-with` command is a high-level replacement for i3's [split command](https://i3wm.org/docs/userguide.html#_splitting_containers).
:::
There is an observation that the only reason why you might want to split a node is to put several windows under a common "umbrella" parent. Unlike `split`, `join-with` can be used with [`enable-normalization-flatten-containers`](/Looper/docs/concepts/tree/#normalization)

## Options

- `-h, --help`: Print help

- `--window-id <window-id>`: Act on the specified window instead of the focused window.
  A window ID, or one of:
  `focused` (the focused window),
  `pointer` (the window under the mouse pointer),
  `wheel` (the window that was under the mouse pointer when the wheel opened; only valid in wheel actions and conditions).
  The flag takes precedence over `LOOPER_WINDOW_ID` and `LOOPER_WORKSPACE` [environment variables](/Looper/docs/concepts/commands/#environment-variables).
