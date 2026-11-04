---
title: "resize"
description: "Resize the focused window"
---

## Synopsis

```text
looper resize [-h|--help] [--window-id <window-id>] (smart|smart-opposite|width|height) [+|-]<number>
```

Resize the focused window

The dimension to resize is chosen by the first argument

- `width` changes width
- `height` changes height
- `smart` changes width if the parent has horizontal orientation, and
it changes height if the parent has vertical orientation
- `smart-opposite` resizes the opposite axis of smart

Floating windows keep their center: `width` and `height` change one dimension, `smart` changes both, and
`smart-opposite` fails because floating windows have no parent container.
They are never smaller than 50 points nor bigger than the usable area of their monitor, and a window that grows past an
edge of that area is pushed back inside.

Second argument controls how much the size changes

- If the `<number>` is prefixed with `+` then the dimension is increased
- If the `<number>` is prefixed with `-` then the dimension is decreased
- If the `<number>` is prefixed with neither `+` nor `-` then the command changes the absolute value of the dimension

## Options

- `-h, --help`: Print help

- `--window-id <window-id>`: Act on the specified window instead of the focused window.
  A window ID, or one of:
  `focused` (the focused window),
  `pointer` (the window under the mouse pointer),
  `wheel` (the window that was under the mouse pointer when the wheel opened; only valid in wheel actions and conditions).
  The flag takes precedence over `LOOPER_WINDOW_ID` and `LOOPER_WORKSPACE` [environment variables](/Looper/docs/concepts/commands/#environment-variables).
