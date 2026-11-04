<picture>
  <source media="(prefers-color-scheme: dark)" srcset="resources/brand/banner.svg">
  <img src="resources/brand/banner-light.svg" width="100%" alt="Looper: tile with your keyboard, steer with a wheel. A tiling window manager for macOS.">
</picture>

> [!WARNING]
> **Work in progress.** Looper is under construction. Expect breaking changes and rough edges.

Looper is a tiling window manager for macOS. It arranges your windows in a tree of containers as they open, and lets
you move them around with key bindings, a radial wheel under the pointer, trackpad gestures, the mouse or the `looper`
command line.

Looper is a fork of [AeroSpace](https://github.com/nikitabobko/AeroSpace) and keeps its tree-based tiling, its commands
and its plain-text configuration. On top of that it adds:

- **The radial wheel**, modeled on the radial menu of [Loop](https://github.com/MrKai77/Loop): hold a key, point in a
  direction and release to run a command, with a preview of where the windows will land, profiles, context-aware
  variants and icons.
- **Trackpad gestures**: three- and four-finger swipes and taps bound to commands, per mode, like keys.
- **Workspaces per native Space**: every monitor and every macOS Space keeps its own workspaces.
- **A configurable menu bar**, written as templates with variables, filters and SF Symbols.
- **Side-specific modifiers**, like the left or the right alt only, and key bindings that follow your keyboard layout.
- Commands that cross monitors, and moving and resizing floating windows from the keyboard.

<!-- Video: Looper in 20 seconds (docs/public/videos/hero.mp4). GitHub only plays videos uploaded as attachments:
     drag hero.mp4 into the README editor on GitHub and put the URL it gives on its own line here. -->

## Documentation

Everything is in the docs at **[mariovagomarzal.github.io/Looper](https://mariovagomarzal.github.io/Looper/docs/)**:

- [Installation](https://mariovagomarzal.github.io/Looper/docs/installation/): build Looper and grant it permission.
- [First steps](https://mariovagomarzal.github.io/Looper/docs/first-steps/): your config file and the default bindings.
- [The tree](https://mariovagomarzal.github.io/Looper/docs/concepts/tree/): how Looper arranges windows.
- [The radial wheel](https://mariovagomarzal.github.io/Looper/docs/guides/wheel/): Looper's signature feature, step by
  step.

The docs are built from [docs/](./docs). To work on Looper itself, see
[Development](https://mariovagomarzal.github.io/Looper/docs/development/).

## Credits

Looper is a fork of [AeroSpace](https://github.com/nikitabobko/AeroSpace) by Nikita Bobko and its contributors, released
under the MIT License. Looper keeps its tree-based tiling, its commands and its configuration, and many of the command
pages in the docs come from AeroSpace's.

The radial wheel's design and interaction are modeled on the radial menu of [Loop](https://github.com/MrKai77/Loop) by
Kai Azim. Looper's implementation is written from scratch and shares no code with Loop, which is licensed under the
GPL-3.0.

## License

Looper is released under the [MIT License](./LICENSE). The licenses of its dependencies are in the [`legal`](./legal)
folder.
