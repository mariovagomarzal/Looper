---
title: "exec-and-forget"
description: "Run /bin/bash -c '<bash-script>'"
---

## Synopsis

```text
looper exec-and-forget <bash-script>
```

Run `/bin/bash -c '<bash-script>'`, and **don't wait for the command termination**.
**Stdout, stderr and exit code are ignored**.

For example, you can use this command to launch applications:

```bash
alt-enter = 'exec-and-forget open -n /System/Applications/Utilities/Terminal.app'
```

The script is passed as-is to bash without any transformations or escaping for convenience.
The script is treated as the suffix of the TOML string, it's not even an argument in classic CLI sense

In the above example, `exec-and-forget` is percieved as String suffix and simply stripped.
The remaining ` open -n /System/Applications/Utilities/Terminal.app` is passed as-is to `/bin/bash -c '<bash-script>'`

- The command is available in config
- The command is available **neither** in CLI, **nor** in Looper shell (see [the shell](/Looper/docs/concepts/commands/#loopers-shell))
