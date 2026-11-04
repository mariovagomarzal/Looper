---
title: "debug-windows"
description: "Interactive command to record Accessibility API debug information to create bug reports"
---

## Synopsis

```text
looper debug-windows [-h|--help] [--window-id <window-id>]
```

Interactive command to record Accessibility API debug information to create bug reports

Use this command output to report bug reports about incorrect windows handling
(e.g. some windows are floated when they shouldn't).

The intended usage is the following:

1. Run the command to start the debug session recording
1. Focus problematic window or make the window appear.
1. Run the command one more time to stop the debug session recording and print the results

The `debug-windows` command is **not stable API**.
Please **don't rely on** the command existence and output format.
The only intended use case is to report bugs about incorrect windows handling.

## Options

- `-h, --help`: Print help

- `--window-id <window-id>`: Print debug information of the specified window right away.
  Usage of this flag disables interactive mode.
