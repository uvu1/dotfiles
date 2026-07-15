---
name: dotfiles-maintenance
description: Safely maintain uvu1's Nix, Home Manager, nix-darwin, mise, and dotflow dotfiles across macOS and WSL. Use only when changing or diagnosing the dotfiles repository.
---

# Dotfiles maintenance

Keep the repository reproducible without absorbing machine-local state.

## Workflow

1. Read `README.md`, `.dotflow.toml`, and the relevant files under `nix/`, `mise/`, or `scripts/` before editing.
2. Preserve the platform split: Nix provides the base, mise provides tools and user dotfiles, and dotflow orchestrates updates.
3. Keep macOS and WSL behavior aligned when the capability is shared. Do not add AI CLI configuration to the Windows profiles unless the user asks for Windows support.
4. Put project-independent AI instructions and skills under `mise/dotfiles/ai/`. Keep repository-specific guidance in the repository's `AGENTS.md` or `CLAUDE.md`.
5. Never track authentication, OAuth state, API keys, histories, sessions, caches, generated memories, installation IDs, trust decisions, or absolute machine-specific project paths.
6. Run `mise/dotfiles/ai/scripts/check-ai-config.sh` after changing AI configuration.
7. Run focused validation for the affected layer. Prefer `nix flake check --no-build`, `mise -C mise -E <profile> dotfiles status`, and `dotflow update --dry-run` when applicable.
8. Do not apply a profile, rebuild the system, install tools, or contact the network unless the requested task requires that side effect.

## Skill compatibility

Shared skills must use the frontmatter supported by both tools: `name` and `description`. Put tool-specific metadata or behavior in a Codex-only or Claude-only skill instead of adding it to a shared skill.
