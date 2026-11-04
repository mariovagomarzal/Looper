---
title: First steps
description: Where the config file lives, what the defaults do, and how to make Looper yours.
---

## The config file

Looper reads its configuration from the first of these files that exists:

1. `~/.looper.toml`
2. `$XDG_CONFIG_HOME/looper/looper.toml` (`~/.config/looper/looper.toml` by default)

Without a config file, Looper uses its [default config](https://github.com/mariovagomarzal/Looper/blob/main/resources/default-config.toml),
which also documents every option in its comments. The menu bar item's **Open config** copies it to `~/.looper.toml`
the first time, so that you can start from it.

After editing, reload with **Reload config** in the menu, `looper reload-config`, or turn on automatic reloading:

```toml
auto-reload-config = true
```

Mistakes in the config are reported in a window that names the exact key. Check a config without applying it with
`looper reload-config --dry-run`.

## The default bindings

The default config uses <kbd>alt</kbd> (option) as the main modifier, like i3:

| Keys | Command |
| --- | --- |
| <kbd>alt</kbd> + <kbd>h</kbd> <kbd>j</kbd> <kbd>k</kbd> <kbd>l</kbd> | Focus left, down, up, right |
| <kbd>alt</kbd> + <kbd>shift</kbd> + <kbd>h</kbd> <kbd>j</kbd> <kbd>k</kbd> <kbd>l</kbd> | Move the window |
| <kbd>alt</kbd> + <kbd>1</kbd>…<kbd>9</kbd>, <kbd>a</kbd>…<kbd>z</kbd> | Go to a workspace |
| <kbd>alt</kbd> + <kbd>shift</kbd> + <kbd>1</kbd>…<kbd>z</kbd> | Move the window to a workspace |
| <kbd>alt</kbd> + <kbd>/</kbd> | Tiles layout, toggling the orientation |
| <kbd>alt</kbd> + <kbd>,</kbd> | Accordion layout, toggling the orientation |
| <kbd>alt</kbd> + <kbd>-</kbd> / <kbd>=</kbd> | Shrink, grow |
| <kbd>alt</kbd> + <kbd>tab</kbd> | Previous workspace |
| <kbd>alt</kbd> + <kbd>shift</kbd> + <kbd>;</kbd> | The `service` mode: reload, reset the layout, float… |

:::tip[Keyboards where alt types symbols]
On many keyboards <kbd>alt</kbd> types characters like `@` or `[`. Bind Looper to one side only, for example
`lalt-h`, and keep the other alt for typing. See [Key bindings](/Looper/docs/guides/key-bindings/).
:::

## Make it yours

- Hold <kbd>fn</kbd>: that's the [radial wheel](/Looper/docs/guides/wheel/). It does nothing until you bind actions to it.
- Bind [trackpad gestures](/Looper/docs/guides/gestures/) to switch workspaces with a swipe.
- Design what the [menu bar](/Looper/docs/guides/menu-bar/) shows.
- Send apps to workspaces as they open with [window rules](/Looper/docs/guides/window-rules/).
- Browse every option in the [configuration reference](/Looper/docs/configuration/) and every [command](/Looper/docs/commands/).
