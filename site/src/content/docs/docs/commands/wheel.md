---
title: "wheel"
description: "Open or close the radial wheel"
---

## Synopsis

```text
looper wheel [-h|--help] open [<profile>]
looper wheel [-h|--help] cancel
```

Open or close the radial wheel

The wheel is usually opened by holding the modifiers of a trigger (see `wheel.triggers` in the config), and the gesture
finishes when they are released.
This command is for the other cases: bindings that don't hold keys, scripts and the CLI.

- `open [<profile>]`: Open the wheel under the mouse pointer with the profile (`default` if omitted).
  If the wheel is already open, switch it to the profile.
  A wheel opened by this command isn't held: finish the gesture with a left, right or other click, or close it with any key.

- `cancel`: Close the wheel without running any action.

## Options

- `-h, --help`: Print help
