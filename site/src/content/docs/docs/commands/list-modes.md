---
title: "list-modes"
description: "Print a list of modes currently specified in the configuration"
---

## Synopsis

```text
looper list-modes [-h|--help] [--current] [--count] [--json]
```

Print a list of modes currently specified in the configuration

See [the guide](/Looper/docs/concepts/modes/) for documentation about binding modes

## Options

- `-h, --help`: Print help

- `--current`: Only print the currently active mode.
  Incompatible with `--count`

- `--count`: Output only the number of modes.
  Incompatible with `--current`, `--json`

- `--json`: Output in JSON format.
  Incompatible with `--count`
