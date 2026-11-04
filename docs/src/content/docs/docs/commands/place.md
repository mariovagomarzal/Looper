---
title: "place"
description: "Move and resize a floating window to a region of its monitor"
---

## Synopsis

```text
looper place [-h|--help] [--window-id <window-id>] <placement>
looper place [-h|--help] [--window-id <window-id>] rect <x> <y> <width> <height>
```

Move and resize a floating window to a region of its monitor

Regions are relative to the usable area of the monitor: without the menu bar and the Dock, and with the outer gaps applied.
Edges shared with another region (e.g. the right edge of `left-half`) leave half of the inner gap, so that two windows placed side by side are separated like tiled windows.

The command only works with floating windows.
Make a window floating first with `layout floating`.

## Options

- `-h, --help`: Print help

- `--window-id <window-id>`: Act on the specified window instead of the focused window.
  A window ID, or one of:
  `focused` (the focused window),
  `pointer` (the window under the mouse pointer),
  `wheel` (the window that was under the mouse pointer when the wheel opened; only valid in wheel actions and conditions).
  The flag takes precedence over `LOOPER_WINDOW_ID` and `LOOPER_WORKSPACE` [environment variables](/Looper/docs/concepts/commands/#environment-variables).

## Arguments

- `<placement>`: `left-half`, `right-half`, `top-half`, `bottom-half`,
  `top-left-quarter`, `top-right-quarter`, `bottom-left-quarter`, `bottom-right-quarter`,
  `left-third`, `center-third`, `right-third`, `left-two-thirds`, `right-two-thirds`,
  `maximize` (the whole usable area), `almost-maximize` (90% of it, centered) or
  `center` (keeps the size and centers the window).

- `rect <x> <y> <width> <height>`: A custom region, in percentages of the usable area.
  For example, `rect 10 10 80 80`.

## Examples

Put the window under the mouse pointer on the left half: `looper place --window-id pointer left-half`
