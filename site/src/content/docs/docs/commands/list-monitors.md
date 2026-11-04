---
title: "list-monitors"
description: "Print monitors that satisfy conditions"
---

## Synopsis

```text
looper list-monitors [-h|--help] [--focused [no]] [--pointer [no]] [--format <output-format>] [--count] [--json]
```

Print monitors that satisfy conditions

## Options

- `-h, --help`: Print help

- `--focused [no]`: Filter results to only print the focused monitor.
  The `no` prefix inverts the condition

- `--pointer [no]`: Filter results to only print the monitor under the mouse pointer.
  The `no` prefix inverts the condition

- `--format <output-format>`: Specify output format.
  See "Output Format" section for more details.
  Incompatible with `--count`

- `--count`: Output only the number of monitors.
  Incompatible with `--format`

- `--json`: Output in JSON format.
  Can be used in combination with `--format` to specify which data to include into the json.
  Incompatible with `--count`

## Output format

Output format can be configured with optional `[--format <output-format>]` option.
The output format supports [string interpolation](https://en.wikipedia.org/wiki/String_interpolation).

If not specified, the default `<output-format>` is:
`%{monitor-id}%{right-padding} | %{monitor-name}`

The following variables can be used inside `<output-format>`:

- `%{monitor-id}`: 1-based Number. Sequential number of the belonging monitor
- `%{monitor-appkit-nsscreen-screens-id}`: 1-based index of the belonging monitor in `NSScreen.screens` array. Useful for integration with other tools that might be using `NSScreen.screens` ordering (like sketchybar).
- `%{monitor-name}`: String. Name of the belonging monitor
- `%{monitor-is-main}`: Boolean. True if the monitor is main.

- `%{right-padding}`: A special variable which expands with a minimum number of spaces required to form a right padding in the appropriate column
- `%{newline}`: Unicode U+000A newline symbol `\n`
- `%{tab}`: Unicode U+0009 tab symbol `\t`
