# Repository guidance

## Architecture

- Treat this repository's `master` branch as the source of truth. `chezmoi-master` is migration history only.
- Keep every globally available tool in Nix and Home Manager: the base environment, language servers, linters, formatters, everyday CLIs, and the fallback language runtimes. `flake.lock` is what pins them.
- Keep mise for per-project version switching plus the vendor CLIs that must track upstream weekly (`claude`, `cloudflared`, `aqua:openai/codex`). Declare project runtimes in that project's own `mise.toml` or idiomatic version file, never in the global toolset.
- Keep ordinary dotfiles in `mise/`.
- Keep update orchestration in `.dotflow.toml` and `scripts/`; do not duplicate it in shell startup files.
- Preserve the environment split: shared `unix` for macOS and WSL, `darwin` for macOS-only dotfiles (wezterm), and `windows` for the complete native Windows environment including PowerShell.

## Changes

- Read the relevant profile and its source dotfile before editing.
- Add globally available tools to `nix/home.nix`. Its `devTools` / `debugTools` / `cliTools` / `runtimes` lists are the single source of truth for them.
- A tool must never be declared in both `nix/home.nix` and the global mise toolset. mise prepends its install directories ahead of the Nix profile, so mise silently wins and the Nix entry becomes dead weight.
- Sheldon activates mise with `mise activate zsh` (PATH activation), not `--shims`. Shims abort with `No version is set for shim: <tool>` instead of falling through to the Nix profile, which would break every fallback runtime. Keep `wsl-local-bin` ordered before the mise plugin so `~/.local/bin` survives in `__MISE_ORIG_PATH`.
- Put the remaining shared macOS/WSL mise entries in `mise/dotfiles/mise/config.unix.toml`. It is the single source of truth and is symlinked to `~/.config/mise/config.toml`, so never duplicate the toolset in `mise/mise.unix.toml`. Editing it takes effect immediately, so land the matching Nix change first.
- Put shared macOS/WSL dotfiles in `mise/mise.unix.toml`; keep only OS-specific entries in `mise.darwin.toml` (currently just wezterm).
- Put Windows tools in `mise/dotfiles/mise/config.windows.toml`. It is the single source of truth and is copied to `~/.config/mise/config.toml`, so never duplicate the toolset in `mise/mise.windows.toml`.
- Do not add project-only tools such as `bun` or `uv` to the global toolsets.
- Write nested values in `mise/dotfiles/ai/codex/config.toml` as dotted keys (`tui.notification_method = "bel"`), never as `[table]` headers. `scripts/sync-ai-config.sh` puts the managed block at the top of `~/.codex/config.toml` and keeps the machine-local settings below it, so a table header would swallow every top-level key that follows. The script refuses to run when the source has a table header, and it drops body keys by reading the source's own top-level key names, so adding a default there needs no change to the script.
- Do not track credentials, OAuth state, histories, sessions, caches, generated memories, installation IDs, or machine-local trust decisions.
- Preserve unrelated worktree changes and avoid destructive Git operations.

## Validation

- Run `nix flake check --no-build` after Nix or Home Manager changes. It only evaluates, so it cannot catch `buildEnv` filename collisions between two packages; build the profile as a dry run to catch those: `nix build --no-link '.#darwinConfigurations."uvu1-mac".config.home-manager.users.uvu1.home.path'`.
- Regenerate the shim directory after removing anything from the global mise toolset (`rm -rf ~/.local/share/mise/shims && mise reshim`). `mise reshim` alone keeps orphans and `mise prune` only removes installed versions, so a stale shim would shadow the Nix profile.
- Run the relevant `mise -C mise -E <env> dotfiles status` after dotfile changes (`unix`, `darwin`, or `windows`).
- Run `mise/dotfiles/ai/scripts/check-ai-config.sh` after AI configuration changes.
- Run `stylua --check mise/dotfiles/.config/wezterm` after wezterm changes. A new wezterm module cannot be smoke-tested from a scratch directory: `require` only searches the real config dir (`~/.config/wezterm`), and neither `--config-file`'s directory nor `WEZTERM_CONFIG_DIR` changes that, so `wezterm show-keys` silently keeps loading the deployed config. Deploy the profile first, or exercise the module against a stubbed `wezterm` table under a plain Lua interpreter.
- Use `dotflow doctor` to validate dotflow configuration. `dotflow update --dry-run` requires a clean worktree.
