---
title: "volume"
description: "Manipulate volume"
---

## Synopsis

```text
looper volume [-h|--help] (up|down) [--no-gui]
looper volume [-h|--help] (mute-toggle|mute-off|mute-on) [--no-gui]
looper volume [-h|--help] set <number> [--no-gui]
```

Manipulate volume

## Options

- `-h, --help`: Print help
- `--no-gui`: Don't show volume GUI indicator

## Arguments

- `(up|down)`: Increase or decrease the volume
- `(mute-toggle|mute-on|mute-off)`: Toggle/On/Off mute
- `set <number>`: Set volume to the exact value on scale from 0 to 100
