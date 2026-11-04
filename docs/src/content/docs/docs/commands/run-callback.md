---
title: "run-callback"
description: "Run Looper config callbacks on demand"
---

## Synopsis

```text
looper run-callback [-h|--help] [--for-every-window|--window-id <window-id>] on-window-detected
looper run-callback [-h|--help] (on-focus-changed|on-focused-monitor-changed)
```

Run Looper config callbacks on demand

The command lets you manually re-run callbacks that Looper normally invokes in response to events:

- `on-window-detected` - callbacks defined by `on-window-detected` config option.
  By default the callbacks are run for the focused window only.
  Pass `--for-every-window` to apply the callbacks to every currently known window
  (useful right after `reload-config` to retroactively apply new rules to already open windows),
  or pass `--window-id` to target a specific window.
- `on-focus-changed` - runs commands listed under the `on-focus-changed` config key.
- `on-focused-monitor-changed` - runs commands listed under the `on-focused-monitor-changed` config key.

The command forwards stdout and stderr of all commands run in the callback.
That opens up one more usecase - you can use this command to see the output of your callbacks.

## Options

- `-h, --help`: Print help

- `--for-every-window`: Run `on-window-detected` callbacks for every window.
  Only valid with `on-window-detected`.
  Mutually exclusive with `--window-id`.

- `--window-id <window-id>`: Act on the specified window instead of the focused window.
  A window ID, or one of:
  `focused` (the focused window),
  `pointer` (the window under the mouse pointer),
  `wheel` (the window that was under the mouse pointer when the wheel opened; only valid in wheel actions and conditions).
  The flag takes precedence over `LOOPER_WINDOW_ID` and `LOOPER_WORKSPACE` [environment variables](/Looper/docs/concepts/commands/#environment-variables).

  Only valid with `on-window-detected`.
  Mutually exclusive with `--for-every-window`.

## Arguments

- `<callback>`: One of: `on-window-detected`, `on-focus-changed`, `on-focused-monitor-changed`

## Exit codes

The command forwards the exit code of the callback.
