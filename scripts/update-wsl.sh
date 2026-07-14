# shellcheck shell=bash

set -Eeuo pipefail

if (( $# != 0 )); then
  printf 'dotfiles-update: this command does not accept arguments\n' >&2
  exit 2
fi

exec dotflow update
