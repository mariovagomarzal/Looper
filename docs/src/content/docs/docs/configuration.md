---
title: Configuration
description: Every option of Looper's config file.
---

Looper reads `~/.looper.toml`, or else `$XDG_CONFIG_HOME/looper/looper.toml`. Every key is optional: a missing key takes
the value of the [default config](https://github.com/mariovagomarzal/Looper/blob/main/resources/default-config.toml),
which also documents every option in its comments. After editing, run `looper reload-config`, or turn on
`auto-reload-config`.

## General

| Key | Default | Description |
| --- | --- | --- |
| `config-version` | `1` | Version of the config format. Version `2` enables `persistent-workspaces`. |
| `start-at-login` | `false` | Start Looper when you log in. |
| `auto-reload-config` | `false` | Reload the config every time the file is saved. |
| `automatically-unhide-macos-hidden-apps` | `false` | Undo the macOS "Hide application" (<kbd>cmd</kbd> + <kbd>h</kbd>) right away. |
| `after-startup-command` | `[]` | Commands to run after Looper starts. |
| `persistent-workspaces` | `[]` | Workspaces that exist even when they're empty and not visible. Requires `config-version = 2`. |

## Layout

| Key | Default | Description |
| --- | --- | --- |
| `default-root-container-layout` | `'tiles'` | Layout of new workspaces: `'tiles'` or `'accordion'`. |
| `default-root-container-orientation` | `'auto'` | Orientation of new workspaces: `'horizontal'`, `'vertical'`, or `'auto'` for horizontal on monitors wider than tall. |
| `accordion-padding` | `30` | Points that the neighbors of the focused window peek out in an accordion. With `0`, they don't. |
| `enable-normalization-flatten-containers` | `true` | Remove containers with a single child. |
| `enable-normalization-opposite-orientation-for-nested-containers` | `true` | Give nested containers the opposite orientation of their parent. |

See [the tree](/Looper/docs/concepts/tree/) for what these mean.

### Gaps

| Key | Default | Description |
| --- | --- | --- |
| `gaps.inner.horizontal` | `0` | Points between windows side by side. |
| `gaps.inner.vertical` | `0` | Points between windows stacked vertically. |
| `gaps.outer.left`, `.right`, `.top`, `.bottom` | `0` | Points between the windows and the edges of the monitor. |

A gap can also take a value per monitor, with a fallback at the end. Monitors are matched by their 1-based number from
left to right, `main`, `secondary` or a case-insensitive regex of their name:

```toml
gaps.outer.top = [{ monitor.main = 16 }, { monitor.'dell' = 32 }, 8]
```

## Bindings

| Key | Default | Description |
| --- | --- | --- |
| `mode.<name>.binding` | | The [key bindings](/Looper/docs/guides/key-bindings/) of each [mode](/Looper/docs/concepts/modes/). |
| `mode.<name>.gesture` | | The [trackpad gestures](/Looper/docs/guides/gestures/) of each mode. |
| `gesture-swipe-distance` | `15` | How far the fingers must move for a swipe, in percent of the trackpad, from 1 to 100. |
| `key-mapping.preset` | `'system'` | How key names map to keys: `'system'` (single characters follow the keyboard layout), `'qwerty'`, `'dvorak'` or `'colemak'`. |
| `key-mapping.key-notation-to-key-code` | `{}` | Extra names for keys, as a table from the new name to an existing one. |

## Mouse

| Key | Default | Description |
| --- | --- | --- |
| `focus-follows-mouse.enabled` | `false` | Give the focus to the window under the pointer. |

## The wheel

See [the radial wheel](/Looper/docs/guides/wheel/) for how to use these.

| Key | Default | Description |
| --- | --- | --- |
| `wheel.size` | `100` | Diameter in points, from 60 to 240. |
| `wheel.thickness` | `22` | Ring thickness in points, from 10 to half the size minus 15. |
| `wheel.corner-radius` | `100` | Corner radius in percent: `0` is a square, `100` a circle. |
| `wheel.accent-color` | `'system'` | Selection color: `'system'`, `'wallpaper'`, a color like `'#3478f6'`, or two colors for a gradient. |
| `wheel.haptics` | `true` | Trackpad feedback when the selection changes. |
| `wheel.preview` | `'target'` | What the preview outlines: `'target'`, `'all'` or `'off'`. |
| `wheel.preview-corner-radius` | `10` | Corner radius of the preview, from 0 to 40 points. |
| `wheel.preview-border-width` | `2` | Border of the preview, from 0 to 10 points. |
| `wheel.icons` | `true` | Show an icon for the selected action in the center. |
| `wheel.triggers` | `{ fn = 'default' }` | Modifiers that open each profile. |
| `wheel.release-delay` | `150` | Milliseconds that a switch caused by releasing a modifier waits, from 0 to 1000. |

Each profile, in `wheel.profiles.<name>`, takes the style keys above without the `wheel.` prefix, and:

| Key | Description |
| --- | --- |
| `extends` | The profile whose style and actions it inherits. |
| `if` | A condition that makes it a [variant](/Looper/docs/guides/wheel/#variants) of the profile it extends. |
| `actions` | A table of slots: `center`, `up`, `down`, `left`, `right`, `up-left`, `up-right`, `down-left` and `down-right`. |

Each slot is a command, run on release, or a table with the keys `release`, `left-click`, `right-click`,
`other-click`, `preview` and `icon`.

## The menu bar

See [the menu bar](/Looper/docs/guides/menu-bar/) for the templates.

| Key | Description |
| --- | --- |
| `menu-bar.format` | The whole item, left to right. |
| `menu-bar.mode` | The active mode, as a template or as a table per mode. |
| `menu-bar.workspace` | Each workspace, per state: `focused`, `visible`, `occupied` and `empty`. |
| `menu-bar.named-workspace` | Single workspaces, by name. |
| `menu-bar.monitor-separator` | What goes between the workspaces of different monitors. |

## Window rules

The `on-window-detected` array runs commands for new windows that match a condition. See
[window rules](/Looper/docs/guides/window-rules/).

## Callbacks

| Key | Default | Description |
| --- | --- | --- |
| `on-focus-changed` | `[]` | Commands to run when the focused window changes. |
| `on-focused-monitor-changed` | `['move-mouse monitor-lazy-center']` | Commands to run when the focused monitor changes. |
| `on-mode-changed` | `[]` | Commands to run when the binding mode changes. |
| `exec-on-workspace-change` | `[]` | A program and its arguments, run when the focused workspace changes. |

The program of `exec-on-workspace-change` gets `LOOPER_FOCUSED_WORKSPACE` and `LOOPER_PREV_WORKSPACE`:

```toml
exec-on-workspace-change = ['/bin/bash', '-c', 'sketchybar --trigger looper_workspace_change FOCUSED=$LOOPER_FOCUSED_WORKSPACE']
```

## Environment

The `exec` table sets the environment of the programs Looper starts, like `exec-and-forget` and
`exec-on-workspace-change`:

| Key | Default | Description |
| --- | --- | --- |
| `exec.inherit-env-vars` | `true` | Start from Looper's own environment. |
| `exec.env-vars` | `{}` | Variables to set. A value can refer to others, like `${PATH}`. |

```toml
[exec.env-vars]
PATH = '/opt/homebrew/bin:${PATH}'
```
