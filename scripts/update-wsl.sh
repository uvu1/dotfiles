# shellcheck shell=bash

set -Eeuo pipefail

stage="initialization"

on_error() {
  local exit_code=$?
  printf 'dotfiles-update: failed during %s (exit %d)\n' "$stage" "$exit_code" >&2
  exit "$exit_code"
}

die() {
  printf 'dotfiles-update: %s\n' "$1" >&2
  exit "${2:-1}"
}

announce() {
  stage="$1"
  printf '\n==> %s\n' "$stage"
}

trap on_error ERR

[[ $# -eq 0 ]] || die "this command does not accept arguments" 2
[[ -n "${HOME:-}" && "$HOME" != "/" ]] || die "unsafe HOME: ${HOME:-<unset>}"

readonly repo="$HOME/dotfiles"
readonly mise_dir="$repo/mise"
readonly expected_branch="master"

announce "preflight checks"

for required_command in git home-manager mise; do
  command -v "$required_command" >/dev/null || die "required command not found: $required_command"
done

[[ -d "$repo" ]] || die "repository not found: $repo"
[[ "$(git -C "$repo" rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]] ||
  die "not a Git worktree: $repo"
[[ "$(git -C "$repo" rev-parse --show-toplevel)" == "$repo" ]] ||
  die "Git worktree root must be exactly $repo"

branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
[[ "$branch" == "$expected_branch" ]] ||
  die "expected branch $expected_branch, found ${branch:-detached HEAD}"

origin="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"
case "$origin" in
  https://github.com/uvu1/dotfiles | https://github.com/uvu1/dotfiles.git | git@github.com:uvu1/dotfiles.git) ;;
  *) die "origin must point to uvu1/dotfiles, found ${origin:-<missing>}" ;;
esac

worktree_status="$(git -C "$repo" status --porcelain=v1 --untracked-files=all)"
if [[ -n "$worktree_status" ]]; then
  printf 'dotfiles-update: worktree is not clean:\n%s\n' "$worktree_status" >&2
  die "commit or restore these changes before updating"
fi

announce "fast-forward master"
git -C "$repo" pull --ff-only origin master

local_head="$(git -C "$repo" rev-parse HEAD)"
fetched_head="$(git -C "$repo" rev-parse FETCH_HEAD)"
[[ "$local_head" == "$fetched_head" ]] ||
  die "local master does not exactly match origin/master after pull"

announce "apply Home Manager"
home-manager switch --flake "$repo#uvu1@arch-wsl"

announce "trust mise configs"
mise trust "$mise_dir/mise.toml"
mise trust "$mise_dir/mise.linux.toml"

announce "install mise tools"
mise -C "$mise_dir" -E linux install

announce "apply dotfiles"
mise -C "$mise_dir" -E linux dotfiles apply --yes

announce "verify dotfiles"
mise -C "$mise_dir" -E linux dotfiles status --missing
mise -C "$mise_dir" -E linux dotfiles status

printf '\ndotfiles-update: complete at %s\n' "$local_head"
