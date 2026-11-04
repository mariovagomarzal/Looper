---
title: "enable"
description: "Temporarily disable window management"
---

## Synopsis

```text
looper enable [-h|--help] toggle
looper enable [-h|--help] on [--fail-if-noop]
looper enable [-h|--help] off [--fail-if-noop]
```

Temporarily disable window management

When you disable Looper, windows from currently invisible workspaces will be placed to the visible area of the screen

Key events are not intercepted when Looper is disabled

## Options

- `-h, --help`: Print help
- `--fail-if-noop`: Exit with non-zero exit code if already in the requested mode
