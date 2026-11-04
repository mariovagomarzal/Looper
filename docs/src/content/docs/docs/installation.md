---
title: Installation
description: Download or build Looper, install it and grant it the Accessibility permission.
---

:::caution[Work in progress]
Looper is under construction. Expect breaking changes.
:::

Looper requires macOS 27 or later.

## Download

Download the zip of the [latest release](https://github.com/mariovagomarzal/Looper/releases/latest). It contains
`Looper.app`, the `looper` command line tool in `bin/`, and the shell completions.

## Build from source

Building only requires [Xcode](https://developer.apple.com/xcode/), which provides Swift, the macOS SDK and the build
tools:

```bash
git clone https://github.com/mariovagomarzal/Looper.git
cd Looper
scripts/bundle.sh --release --identity - --output .build/dist
```

This leaves `Looper.app` and the `looper` command line tool in `.build/dist`.

macOS ties the Accessibility permission to the app's code signature, and `--identity -` signs ad hoc: macOS asks for the
permission again after each rebuild. To keep it across rebuilds, sign with your own identity, as explained in
[Development](/Looper/docs/development/#code-signing).

## Install

1. Move `Looper.app` to `/Applications`.
2. Put the `looper` command line tool somewhere in your `PATH`, for example:

   ```bash
   cp looper /usr/local/bin/
   ```

3. Open Looper. It asks for the **Accessibility** permission, which it needs to move and resize windows. Grant it in
   **System Settings › Privacy & Security › Accessibility**.

Looper lives in the menu bar: there is no Dock icon. The menu bar item shows your workspaces, and its menu has the
options to reload or open the config, disable Looper and quit.

## Recommended macOS settings

- **Displays have separate Spaces** (System Settings › Desktop & Dock) works best on multiple monitors.
- If you bind [trackpad gestures](/Looper/docs/guides/gestures/), turn off the macOS gestures that use the same fingers, or both
  run.

## Next

Continue with [First steps](/Looper/docs/first-steps/).
