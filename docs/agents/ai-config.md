# Codex / Claude Code configuration

- Write nested values in `mise/dotfiles/ai/codex/config.toml` as dotted keys (`tui.status_line = [...]`), never as `[table]` headers. `scripts/sync-ai-config.sh` puts the managed block at the top of `~/.codex/config.toml` and keeps the machine-local settings below it, so a table header would swallow every top-level key that follows. The script refuses to run when the source has a table header, and it drops body keys by reading the source's own top-level key names, so adding a default there needs no change to the script.
- Do not add AI CLI configuration to the Windows profiles unless the user asks for Windows support.
- Shared skills under `mise/dotfiles/ai/skills/common/` must use only the frontmatter both tools support: `name` and `description`. Put tool-specific metadata or behavior in a Claude-only or Codex-only skill instead.
