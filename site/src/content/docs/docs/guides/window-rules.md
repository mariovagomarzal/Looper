---
title: Window rules
description: Run commands for new windows, like sending an app to its workspace or making it float.
---

The `on-window-detected` table runs commands for every new window that matches a condition:

```toml
[[on-window-detected]]
if = 'test %{app-bundle-id} = com.apple.finder'
run = 'layout floating'

[[on-window-detected]]
if = 'test %{app-name} ~= slack || test %{app-name} ~= mail'
run = 'move-node-to-workspace M'

[[on-window-detected]]
if = 'test %{window-title} ~= "picture-in-picture"'
run = ['layout floating', 'move-node-to-workspace P']
```

- The `if` key is a condition written with [`test` and `test-not`](/Looper/docs/concepts/commands/#conditions), joined with `&&`, `||`
  and parentheses. The operator `=` compares exactly, and `~=` matches a case-insensitive regex. Without `if`, the rule matches every
  window.
- The `run` key is a command, or a list of commands, run on the new window.
- With `check-further-callbacks = true`, Looper keeps checking the next rules after a match. By default, the first matching rule
  is the only one that runs.

Find the bundle ID and name of an app with `looper list-apps`, and the windows' titles with
`looper list-windows --all`.

:::tip
To send the next window you open somewhere else, `looper layout floating --for-next-detected-window` makes it float
without a rule.
:::

## The table form

The conditions can also be a table, like in AeroSpace:

```toml
[[on-window-detected]]
if.app-id = 'com.apple.Safari'
if.window-title-regex-substring = 'private'
if.during-looper-startup = false
run = 'move-node-to-workspace S'
```

The keys are `app-id`, `app-name-regex-substring`, `window-title-regex-substring`, `workspace` and
`during-looper-startup`.
