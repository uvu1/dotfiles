#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This profile is only supported on macOS" >&2
  exit 1
fi

case "$(uname -m)" in
  arm64) system="aarch64-darwin" ;;
  x86_64) system="x86_64-darwin" ;;
  *) echo "Unsupported macOS CPU architecture" >&2; exit 1 ;;
esac

if [[ -z "${USER:-}" || -z "${HOME:-}" ]]; then
  echo "USER and HOME must be set for the work Home Manager profile" >&2
  exit 1
fi

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flake="${repo}#work-${system}"

# Work profile is standalone Home Manager, not nix-darwin: no sudo,
# Homebrew Casks, 1Password identity, Tailscale service or OS preferences.
if command -v home-manager >/dev/null 2>&1; then
  exec home-manager switch --impure --flake "$flake"
fi

exec nix --extra-experimental-features 'nix-command flakes' run \
  github:nix-community/home-manager/release-26.05 -- \
  switch --impure --flake "$flake"
