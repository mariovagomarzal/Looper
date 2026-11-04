---
title: "trigger-binding"
description: "Trigger Looper binding as if it was pressed by user"
---

## Synopsis

```text
looper trigger-binding [-h|--help] --mode <mode-id> [--] <binding>
```

Trigger Looper binding as if it was pressed by user

You can use looper-config command to inspect available bindings:
```bash
looper config --get mode.main.binding --keys
```

## Options

- `-h, --help`: Print help
- `--mode <mode-id>`: Mode to search `<binding>` in

## Arguments

- `<binding>`: Binding to trigger

## Examples

- Run alphabetically first binding from config (useless and synthetic example):
  ```bash
  looper trigger-binding --mode main "$(looper config --get mode.main.binding --keys | head -1)"
  ```
- Trigger `alt-tab` binding:
  ```bash
  looper trigger-binding --mode main alt-tab
  ```
