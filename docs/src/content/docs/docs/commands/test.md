---
title: "test"
description: "Condition evaluation utility"
---

## Synopsis

```text
looper test [-h|--help] [--window-id <window-id>] <lhs> = <rhs>
looper test [-h|--help] [--window-id <window-id>] <lhs> ~= <rhs>
```

Condition evaluation utility

The `test` utility evaluates the expression and, if it evaluates to true, returns a zero (true) exit status; otherwise it returns 1 (false).

The utility is inspired by the builtin `/bin/test` utility.

- `<lhs> = <rhs>`: Tests that `<lhs>` equals to `<rhs>`.
- `<lhs> ~= <rhs>`: Tests that `<lhs>` contains case insensitive `<rhs>` regex. The command fails if `<lhs>` is not of type string.

## Examples

Test if the application ID equals to Chrome: `looper test %{app-bundle-id} = com.google.Chrome`

Test if the application name contains "chrome" (case insensitive): `looper test %{app-name} ~= chrome`

## Options

- `-h, --help`: Print help

- `--window-id <window-id>`: Evaluate the expression against the specified window instead of the focused window.
  A window ID, or one of `focused`, `pointer` or `wheel` (see the `--window-id` flag of other commands).

## Arguments

- `<lhs>`: The left hand side of the expression.
  The left hand side must be one of the interpolation variables (see below).

- `<rhs>`: An integer, a boolean (`true`/`false`), a regex, or just a plain string.
  The way the expression is interpreted depends on the type of `<lhs>` and the infix operator.

## Interpolation variables

- `%{window-id}`: Number. Window unique ID
- `%{window-title}`: String. Window title
- `%{window-is-fullscreen}`: Boolean. Is window in fullscreen by `looper fullscreen` command
- `%{window-layout}`: String. An alias for `%{window-parent-container-layout}`
- `%{window-parent-container-layout}`: String. The layout (`v_tiles`, `h_tiles`, `v_accordion`, `h_accordion`, `floating`) of the window's parent container.

- `%{app-bundle-id}`: String. Application unique identifier. [Bundle ID](https://developer.apple.com/documentation/appstoreconnectapi/bundle_ids)
- `%{app-name}`: String. Application name
- `%{app-pid}`: Number. [UNIX process identifier](https://en.wikipedia.org/wiki/Process_identifier)
- `%{app-exec-path}`: String. Application executable path
- `%{app-bundle-path}`: String. Application bundle path

- `%{workspace}`: String. Name of the belonging workspace
- `%{workspace-is-focused}`: Boolean, `true` if the workspace has focus
- `%{workspace-is-visible}`: Boolean, `true` if the workspace is visible. A workspace can be visible but not focused in a multi-monitor setup
- `%{workspace-root-container-layout}`: String. The layout (`v_tiles`, `h_tiles`, `v_accordion`, `h_accordion`) of the workspace the window belongs to.

- `%{monitor-id}`: 1-based Number. Sequential number of the belonging monitor.
- `%{monitor-appkit-nsscreen-screens-id}`: 1-based index of the belonging monitor in `NSScreen.screens` array. Useful for integration with other tools that might be using `NSScreen.screens` ordering (like sketchybar).
- `%{monitor-name}`: String. Name of the belonging monitor
- `%{monitor-is-main}`: Boolean, `true` if the monitor is main.

## Exit codes

- `0`: The expression has evaluated to `true`.
- `1`: The expression has evaluated to `false`.

- `>1`: An error occurred.
  For instance, when `<rhs>` type doesn't match `<lhs>` type, or if the `test` subcommand couldn't be parsed.
