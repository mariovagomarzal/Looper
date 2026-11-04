---
title: "workspace-back-and-forth"
description: "Switch between the focused workspace and previously focused workspace back and forth"
---

## Synopsis

```text
looper workspace-back-and-forth [-h|--help]
```

Switch between the focused workspace and previously focused workspace back and forth

Unlike `focus-back-and-forth`, `workspace-back-and-forth` always succeeds.
Because unlike windows, workspaces can not be "closed".
Workspaces are name-addressable objects.
They are created and destroyed on the fly.

Also see: [focus-back-and-forth](/Looper/docs/commands/focus-back-and-forth/)

## Options

- `-h, --help`: Print help
