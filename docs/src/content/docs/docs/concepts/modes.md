---
title: Binding modes
description: Sets of key bindings and gestures that you switch between, like vim's modes.
---

Key bindings and gestures belong to a **binding mode**. Only the bindings of the active mode work. The `main` mode is
always there and is active when Looper starts.

```toml
[mode.main.binding]
alt-r = 'mode resize'

[mode.resize.binding]
h = 'resize width -50'
l = 'resize width +50'
enter = 'mode main'
esc = 'mode main'
```

In the example, <kbd>alt</kbd> + <kbd>r</kbd> enters the `resize` mode, where plain <kbd>h</kbd> and <kbd>l</kbd> resize
the window, until <kbd>enter</kbd> or <kbd>esc</kbd> go back to `main`.

- A binding runs a list of commands: `esc = ['reload-config', 'mode main']`.
- Each mode has its own [trackpad gestures](/Looper/docs/guides/gestures/) in `[mode.<name>.gesture]`.
- [`on-mode-changed`](/Looper/docs/configuration/#callbacks) runs commands every time the mode changes.
- The [menu bar](/Looper/docs/guides/menu-bar/) shows the active mode.
- [`trigger-binding`](/Looper/docs/commands/trigger-binding/) runs the binding of a mode as if you pressed it.
