---
title: "move-mouse"
description: "Move mouse to the requested position"
---

## Synopsis

```text
looper move-mouse [-h|--help] [--fail-if-noop] <mouse-position>
```

Move mouse to the requested position

## Options

- `-h, --help`: Print help

- `--fail-if-noop`: Exit with non-zero exit code if mouse is already at the requested position.
  The flag is compatible only with `window-lazy-center` and `monitor-lazy-center` arguments.

## Arguments

- `<mouse-position>`: Position to move mouse to.
  Possible values:

  * `monitor-lazy-center`. Move mouse to the center of the focused monitor, **unless** it is already within the monitor boundaries.
  * `monitor-force-center`. Move mouse to the center of the focused monitor.
  * `window-lazy-center`. Move mouse to the center of the focused window, **unless** it is already within the window boundaries. Exit with non-zero code if no window is focused.
  * `window-force-center`. Move mouse to the center of the focused window. Exit with non-zero code if no window is focused.

## Examples

- Try to move mouse to the center of the window. If there is no window in focus, move mouse to the center of the monitor:
  ```bash
  looper move-mouse window-lazy-center || looper move-mouse monitor-lazy-center
  ```
