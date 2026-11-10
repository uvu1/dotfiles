# AeroSpace

- AeroSpace is the macOS window manager. Its settings live in `services.aerospace` in `nix/darwin.nix`, never in `mise/dotfiles`: the nix-darwin module always passes a generated TOML through `--config-path`, so a `~/.config/aerospace` file would be ignored. The `workspaces` map there is the single source of truth: each name gets `ctrl-alt-<name>` / `ctrl-alt-shift-<name>` bindings, and its bundle IDs are routed to it through `on-window-detected`; every other window goes floating to the `fallback` workspace, whose catch-all rule must stay last.
