# Repository guidance

## Architecture

- Treat this repository's `master` branch as the source of truth. `chezmoi-master` is migration history only.
- Keep Nix and Home Manager limited to the reproducible base environment.
- Keep user tools and ordinary dotfiles in `mise/`.
- Keep update orchestration in `.dotflow.toml` and `scripts/`; do not duplicate it in shell startup files.
- Preserve the profile split: `darwin` for macOS, `linux` for WSL, and the two Windows profiles for native Windows.

## Changes

- Read the relevant profile and its source dotfile before editing.
- Apply shared macOS/WSL changes to both profiles unless the difference is intentional.
- Do not add project-only tools such as `bun` or `uv` to the global toolsets.
- Do not track credentials, OAuth state, histories, sessions, caches, generated memories, installation IDs, or machine-local trust decisions.
- Preserve unrelated worktree changes and avoid destructive Git operations.

## Validation

- Run `nix flake check --no-build` after Nix or Home Manager changes.
- Run the relevant `mise -C mise -E <profile> dotfiles status` after dotfile changes.
- Run `mise/dotfiles/ai/scripts/check-ai-config.sh` after AI configuration changes.
- Use `dotflow doctor` to validate dotflow configuration. `dotflow update --dry-run` requires a clean worktree.
