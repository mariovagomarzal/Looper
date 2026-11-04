---
title: "eval"
description: "Send multiple commands to Looper at once"
---

## Synopsis

```text
looper eval [-h|--help] [--stdin] [--] <looper-shell-expr>
```

Send multiple commands to Looper at once

## Options

- `-h, --help`: Print help

- `--stdin`: Capture CLIs stdin and forward it to `<looper-shell-expr>`.
  If not supplied, stdin is ignored.

## Arguments

- `<looper-shell-expr>`: This argument is Looper's shell expression.
  See ../../concepts/commands/#loopers-shell for more info.

## Examples

- Cycle between workspaces a, b, and c:
  ```bash
  looper eval 'echo a b c | workspace --wrap-around --stdin next'
  ```
