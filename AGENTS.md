# Repository guidance

## Architecture

- Treat this repository's `master` branch as the source of truth. `chezmoi-master` is migration history only.
- Keep every globally available tool in Nix and Home Manager: the base environment, language servers, linters, formatters, everyday CLIs, and the fallback language runtimes. `flake.lock` is what pins them.
- Keep mise for per-project version switching plus the vendor CLIs that must track upstream weekly (`claude`, `aqua:openai/codex`, `herdr`, `aqua:vercel-labs/agent-browser`, `aqua:anomalyco/opencode`). Declare project runtimes in that project's own `mise.toml` or idiomatic version file, never in the global toolset.
- Keep ordinary dotfiles in `mise/`.
- Keep update orchestration in `.dotflow.toml` and `scripts/`; do not duplicate it in shell startup files.
- Preserve the environment split: shared `unix` for macOS and WSL, `darwin` for macOS-only dotfiles (Karabiner and the WezTerm config symlink), and `wsl` for WezTerm settings copied into Windows from WSL. Native Arch and native Windows development environments are not managed. Keep Windows interop in the WSL Home Manager profile.

## Changes

- Read the relevant profile and its source dotfile before editing.
- Add globally available tools to `nix/home.nix`. Its `devTools` / `debugTools` / `cliTools` / `runtimes` lists are the single source of truth for them.
- A tool must never be declared in both `nix/home.nix` and the global mise toolset. mise prepends its install directories ahead of the Nix profile, so mise silently wins and the Nix entry becomes dead weight.
- Sheldon activates mise with `mise activate zsh` (PATH activation), not `--shims`. Shims abort with `No version is set for shim: <tool>` instead of falling through to the Nix profile, which would break every fallback runtime. Keep `wsl-local-bin` ordered before the mise plugin so `~/.local/bin` survives in `__MISE_ORIG_PATH`.
- On WSL, `wsl-local-bin` drops the Windows PATH (`/mnt/<drive>/...`) inside zsh, because scanning it over 9P cost about 80 ms before the first prompt and 40 ms after it. Expose a Windows command that must be callable by name through the `wslCommands` map in `nix/home.nix`, which writes a `~/.local/bin` wrapper; never re-add `/mnt/c` directories to PATH.
- Put the remaining shared macOS/WSL mise entries in `mise/dotfiles/mise/config.unix.toml`. It is the single source of truth and is symlinked to `~/.config/mise/config.toml`, so never duplicate the toolset in `mise/mise.unix.toml`. Editing it takes effect immediately, so land the matching Nix change first.
- Put shared macOS/WSL dotfiles in `mise/mise.unix.toml`; keep only OS-specific entries in `mise.darwin.toml` (currently Karabiner and the WezTerm config symlink).
- Do not add project-only tools such as `bun`, `uv`, PostgreSQL, or libpq to the global toolsets.
- Keep Kubernetes/Vault shell UI opt-in under `mise/dotfiles/.config/zsh/optional/`. The infra repository loads it through mise enter/leave hooks; do not activate it globally.
- Do not track credentials, OAuth state, histories, sessions, caches, generated memories, installation IDs, or machine-local trust decisions.
- Preserve unrelated worktree changes and avoid destructive Git operations.

## Component notes

Before editing a path below, read its note in `docs/agents/`; it holds that component's constraints and validation steps.

- `mise/dotfiles/.config/nvim/`, `scripts/test_nvim_config.py`: `docs/agents/nvim.md`
- `mise/dotfiles/ai/`, `scripts/sync-ai-config.*`: `docs/agents/ai-config.md`
- `mise/dotfiles/.config/wezterm/`: `docs/agents/wezterm.md`
- `mise/dotfiles/.config/zsh/optional/`: `docs/agents/project-shell.md`
- `mise/dotfiles/.config/herdr/`, `mise/dotfiles/.config/starship.toml`, the herdr hook scripts: `docs/agents/herdr.md`
- `services.aerospace` in `nix/darwin.nix`: `docs/agents/aerospace.md`
- `scripts/sync-takumi-guard.sh`: `docs/agents/takumi-guard.md`

## Validation

- Run `nix flake check --no-build` after Nix or Home Manager changes. It only evaluates, so it cannot catch `buildEnv` filename collisions between two packages; build the profile as a dry run to catch those: `nix build --no-link '.#darwinConfigurations."uvu1-mac".config.home-manager.users.uvu1.home.path'`.
- During actual deployment, regenerate the shim directory after removing anything from the global mise toolset (`rm -rf ~/.local/share/mise/shims && mise reshim`). `mise reshim` alone keeps orphans and `mise prune` only removes installed versions, so a stale shim would shadow the Nix profile. Do not modify live shims during a repository-only change.
- Run the relevant `mise -C mise -E <env> dotfiles status` after dotfile changes (`unix`, `darwin`, or `wsl`).
- Run `mise/dotfiles/ai/scripts/check-ai-config.sh` after AI configuration changes.
- Use `dotflow doctor` to validate dotflow configuration. `dotflow update --dry-run` requires a clean worktree.
