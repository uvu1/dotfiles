#!/usr/bin/env bash
set -euo pipefail

export MISE_EXPERIMENTAL=1

if [[ $# -ne 1 ]]; then
  echo "usage: $0 darwin|linux" >&2
  exit 2
fi

environment="$1"
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mise_dir="$repo_root/mise"

if [[ -z "${HOME:-}" || "$HOME" == "/" ]]; then
  echo "unsafe HOME: ${HOME:-<unset>}" >&2
  exit 1
fi

case "$environment" in
  darwin)
    targets=(
      "$HOME/.config/nvim"
      "$HOME/.config/mise"
      "$HOME/.config/sheldon"
      "$HOME/.config/zsh"
      "$HOME/.config/starship.toml"
      "$HOME/.config/wezterm"
      "$HOME/.zshrc"
      "$HOME/.gitconfig"
    )
    ;;
  linux)
    targets=(
      "$HOME/.config/nvim"
      "$HOME/.config/mise"
      "$HOME/.config/sheldon"
      "$HOME/.config/zsh"
      "$HOME/.config/starship.toml"
      "$HOME/.zshrc"
      "$HOME/.gitconfig"
    )
    ;;
  *)
    echo "unsupported environment: $environment" >&2
    exit 2
    ;;
esac

command -v mise >/dev/null

mise -C "$mise_dir" -E "$environment" dotfiles apply --dry-run --force --verbose

printf 'The following chezmoi-applied paths will be deleted:\n'
printf '  %s\n' "${targets[@]}"
read -r -p 'Type delete to continue: ' confirmation

if [[ "$confirmation" != "delete" ]]; then
  echo "cancelled"
  exit 1
fi

for target in "${targets[@]}"; do
  case "$target" in
    "$HOME"/*) ;;
    *)
      echo "refusing path outside HOME: $target" >&2
      exit 1
      ;;
  esac

  if [[ -e "$target" || -L "$target" ]]; then
    rm -rf -- "$target"
  fi
done

mise -C "$mise_dir" -E "$environment" dotfiles apply --dry-run --verbose
mise -C "$mise_dir" -E "$environment" dotfiles apply --yes
mise -C "$mise_dir" -E "$environment" dotfiles apply --yes
mise -C "$mise_dir" -E "$environment" dotfiles status --missing
mise -C "$mise_dir" -E "$environment" dotfiles status
