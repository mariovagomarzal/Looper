---
title: Commands and the shell
description: How commands are written in the config and in the CLI, and the environment they run in.
---

Everything Looper does is a **command**: bindings, wheel actions, gestures and callbacks run commands, and the
[`looper`](/Looper/docs/commands/) command line tool runs the same ones from a terminal or a script.

```bash
looper focus left
looper list-windows --workspace focused
```

## Looper's shell

Where the config takes a command, it takes a small shell expression:

```toml
alt-a = 'move left && layout accordion'      # the second runs if the first succeeds
alt-b = 'move left --boundaries-action fail || move-node-to-monitor left'  # the second if the first fails
alt-c = 'workspace 1; workspace 2'           # one after the other
alt-d = ['layout floating', 'mode main']     # a list is like ';'
```

The operators `&&`, `||` and `;` work like in a POSIX shell, and parentheses group them. From the command line,
[`eval`](/Looper/docs/commands/eval/) runs such an expression in one go.

To run anything else, [`exec-and-forget`](/Looper/docs/commands/exec-and-forget/) starts a shell command and doesn't wait for
it:

```toml
alt-enter = 'exec-and-forget open -a Ghostty'
```

## Conditions

[`test`](/Looper/docs/commands/test/) and [`test-not`](/Looper/docs/commands/test-not/) check the focused window, or the one passed
with `--window-id`, using the same variables as [`list-windows --format`](/Looper/docs/commands/list-windows/#output-format):

```bash
looper test %{app-bundle-id} = com.apple.Safari && looper layout floating
```

They're also the conditions of [wheel variants](/Looper/docs/guides/wheel/#variants) and [window rules](/Looper/docs/guides/window-rules/).

## Which window a command acts on

Commands act on the focused window, or the focused workspace, unless they get:

- A window, with `--window-id <id>`: a window ID, or `focused`, `pointer` (the window under the mouse pointer) or `wheel` (the window
  that was under the pointer when the wheel opened).
- A workspace, with `--workspace <name>`, and the visible workspace of another monitor with `--monitor <monitor>`.

## Environment variables

Commands started by Looper (callbacks, `exec-and-forget`) get these variables, and the `looper` CLI reads the first two
to act on the same window or workspace:

| Variable | Value |
| --- | --- |
| `LOOPER_WINDOW_ID` | The window the command acts on |
| `LOOPER_WORKSPACE` | The workspace the command acts on, when there's no window |
| `LOOPER_FOCUSED_WORKSPACE` | The newly focused workspace, in `exec-on-workspace-change` |
| `LOOPER_PREV_WORKSPACE` | The previously focused workspace, in `exec-on-workspace-change` |

The `--window-id` and `--workspace` flags take precedence over them. [`exec`](/Looper/docs/configuration/#environment) sets the rest of the
environment of the commands Looper starts.
