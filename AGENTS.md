# Repository guidance

## Architecture

- Treat this repository's `master` branch as the source of truth. `chezmoi-master` is migration history only.
- Keep Nix and Home Manager limited to the reproducible base environment.
- Keep user tools and ordinary dotfiles in `mise/`.
- Keep update orchestration in `.dotflow.toml` and `scripts/`; do not duplicate it in shell startup files.
- Preserve the environment split: shared `unix` for macOS and WSL, `darwin` for macOS-only dotfiles (wezterm), and the two Windows environments (`windows`, `windows-powershell`) for native Windows.

## Changes

- Read the relevant profile and its source dotfile before editing.
- Put shared macOS/WSL tools and dotfiles in `mise/mise.unix.toml`; keep only OS-specific entries in `mise.darwin.toml` (currently just wezterm).
- Do not add project-only tools such as `bun` or `uv` to the global toolsets.
- Do not track credentials, OAuth state, histories, sessions, caches, generated memories, installation IDs, or machine-local trust decisions.
- Preserve unrelated worktree changes and avoid destructive Git operations.

## Validation

- Run `nix flake check --no-build` after Nix or Home Manager changes.
- Run the relevant `mise -C mise -E <env> dotfiles status` after dotfile changes (`unix`, `darwin`, `windows`, or `windows-powershell`).
- Run `mise/dotfiles/ai/scripts/check-ai-config.sh` after AI configuration changes.
- Use `dotflow doctor` to validate dotflow configuration. `dotflow update --dry-run` requires a clean worktree.
