---
title: Commands
description: Every Looper command, for key bindings, the wheel, gestures and the looper CLI.
sidebar:
  label: Overview
  order: 0
---

## Synopsis

```text
looper [-h|--help] [-v|--version] <subcommand> [<subcommand-options>...] [<subcommand-arguments>...]
```

Commands are what bindings, wheel actions, gestures and callbacks run, and what the `looper` command line tool sends to
Looper. Each command has its own page, and `looper <command> --help` prints its synopsis.

See [Commands and the shell](/Looper/docs/concepts/commands/) for joining commands with `&&`, `||` and `;`, and for the window
they act on.

## Options

- `-h, --help`: Print help
- `-v, --version`: Print the version of the CLI and of Looper

## Windows and layout

[`focus`](/Looper/docs/commands/focus/), [`move`](/Looper/docs/commands/move/), [`swap`](/Looper/docs/commands/swap/), [`join-with`](/Looper/docs/commands/join-with/), [`split`](/Looper/docs/commands/split/),
[`layout`](/Looper/docs/commands/layout/), [`resize`](/Looper/docs/commands/resize/), [`balance-sizes`](/Looper/docs/commands/balance-sizes/),
[`flatten-workspace-tree`](/Looper/docs/commands/flatten-workspace-tree/), [`fullscreen`](/Looper/docs/commands/fullscreen/), [`place`](/Looper/docs/commands/place/),
[`close`](/Looper/docs/commands/close/), [`close-all-windows-but-current`](/Looper/docs/commands/close-all-windows-but-current/),
[`focus-back-and-forth`](/Looper/docs/commands/focus-back-and-forth/), [`macos-native-fullscreen`](/Looper/docs/commands/macos-native-fullscreen/),
[`macos-native-minimize`](/Looper/docs/commands/macos-native-minimize/)

## Workspaces and monitors

[`workspace`](/Looper/docs/commands/workspace/), [`workspace-back-and-forth`](/Looper/docs/commands/workspace-back-and-forth/),
[`move-node-to-workspace`](/Looper/docs/commands/move-node-to-workspace/), [`focus-monitor`](/Looper/docs/commands/focus-monitor/),
[`move-node-to-monitor`](/Looper/docs/commands/move-node-to-monitor/), [`move-workspace-to-monitor`](/Looper/docs/commands/move-workspace-to-monitor/),
[`swap-workspace-with-monitor`](/Looper/docs/commands/swap-workspace-with-monitor/)

## Looper

[`wheel`](/Looper/docs/commands/wheel/), [`mode`](/Looper/docs/commands/mode/), [`trigger-binding`](/Looper/docs/commands/trigger-binding/), [`enable`](/Looper/docs/commands/enable/),
[`reload-config`](/Looper/docs/commands/reload-config/), [`config`](/Looper/docs/commands/config/), [`move-mouse`](/Looper/docs/commands/move-mouse/), [`volume`](/Looper/docs/commands/volume/)

## Scripting

[`list-windows`](/Looper/docs/commands/list-windows/), [`list-workspaces`](/Looper/docs/commands/list-workspaces/), [`list-monitors`](/Looper/docs/commands/list-monitors/),
[`list-apps`](/Looper/docs/commands/list-apps/), [`list-modes`](/Looper/docs/commands/list-modes/), [`list-exec-env-vars`](/Looper/docs/commands/list-exec-env-vars/),
[`test`](/Looper/docs/commands/test/), [`test-not`](/Looper/docs/commands/test-not/), [`eval`](/Looper/docs/commands/eval/), [`exec-and-forget`](/Looper/docs/commands/exec-and-forget/),
[`echo`](/Looper/docs/commands/echo/), [`true`](/Looper/docs/commands/true/), [`false`](/Looper/docs/commands/false/), [`subscribe`](/Looper/docs/commands/subscribe/), [`run-callback`](/Looper/docs/commands/run-callback/),
[`debug-windows`](/Looper/docs/commands/debug-windows/)
