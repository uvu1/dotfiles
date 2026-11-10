---
name: herdr
description: "Control Herdr, a terminal multiplexer for coding agents. Use only when the user explicitly mentions Herdr or asks to use Herdr to inspect or control panes, tabs, workspaces, commands, or another agent. Do not use merely because a task could benefit from a background terminal, delegation, or parallel work. Requires HERDR_ENV=1."
---

# Herdr

This file is a discovery stub, not the usage guide. Before running any other `herdr` command, load the skill that ships with the installed binary and follow it:

```bash
herdr --skill
```

The binary prints the guide that matches its own version, so it never goes stale; this stub stays fixed across upgrades.

herdr is installed by mise (`mise/dotfiles/mise/config.unix.toml`). Do not run `herdr integration install`: the claude and codex integrations are vendored in the dotfiles repository.
