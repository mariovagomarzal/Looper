---
title: "echo"
description: "Print arguments and interpolation variables to stdout"
---

## Synopsis

```text
looper echo [-h|--help] [--stderr] [--window-id <window-id>] -- <string>...
```

Print `<string>...` arguments and **interpolation variables** to stdout.

You can use this command in combination with other commands to do various things:

- You can test shell operators
- You can pipe an explicit input to some other command (e.g. [`workspace`](/Looper/docs/commands/workspace/)) inside an [`eval`](/Looper/docs/commands/eval/)
- You can print interpolation variables for the focused window (see [`list-windows`](/Looper/docs/commands/list-windows/) for the list of interpolation variables)

## Options

- `-h, --help`: Print help
- `--stderr`: Print to stderr instead of stdout
- `--window-id <window-id>`: Act on the specified window instead of the focused window.
  A window ID, or one of:
  `focused` (the focused window),
  `pointer` (the window under the mouse pointer),
  `wheel` (the window that was under the mouse pointer when the wheel opened; only valid in wheel actions and conditions).
  The flag takes precedence over `LOOPER_WINDOW_ID` and `LOOPER_WORKSPACE` [environment variables](/Looper/docs/concepts/commands/#environment-variables).

## Arguments

- `<string>`: The argument to print.
  Each `<string>` argument can contain **interpolation variables** similar to those in [`list-windows`](/Looper/docs/commands/list-windows/).
  You can specify multiple `<string>` arguments - each of them is printed on a separate line.

## Examples

- Print the focused window title: `+looper echo -- %{window-title}+`
