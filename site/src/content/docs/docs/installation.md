---
title: Installation
description: Build Looper from source, install it and grant it the Accessibility permission.
---

:::caution[Work in progress]
Looper is under construction and has no published releases yet. For now, you build it from source. Expect breaking
changes.
:::

## Requirements

- macOS 27 or later.
- [Xcode](https://developer.apple.com/xcode/), which provides Swift, the macOS SDK and the build tools.
- [devenv](https://devenv.sh/), which provides the development tools (`just`, the formatters and linters). It doesn't
  build the app: Swift and the SDK always come from Xcode.

## Build

```bash
git clone https://github.com/mariovagomarzal/Looper.git
cd Looper
devenv shell -- just release 0.1.0
```

This leaves `Looper.app` and the `looper` command line tool in `.build/dist`, and a zip with both.

macOS ties the Accessibility permission to the app's code signature. The build signs with a `Looper Development`
identity so that the permission survives rebuilds; see [Development](/Looper/docs/development/#code-signing) to create it, or
pass `--identity -` to sign ad hoc.

## Install

1. Move `Looper.app` to `/Applications`.
2. Put the `looper` command line tool somewhere in your `PATH`, for example:

   ```bash
   cp .build/dist/looper /usr/local/bin/
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
