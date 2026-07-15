#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ai_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
repo_root=$(CDPATH= cd -- "$ai_dir/../../.." && pwd)

required_paths=(
  "$repo_root/AGENTS.md"
  "$repo_root/CLAUDE.md"
  "$ai_dir/codex/AGENTS.md"
  "$ai_dir/codex/config.toml"
  "$ai_dir/codex/rules/dotfiles.rules"
  "$ai_dir/claude/CLAUDE.md"
  "$ai_dir/claude/settings.json"
  "$ai_dir/skills/common/dotfiles-maintenance/SKILL.md"
  "$ai_dir/skills/codex/dotfiles-maintenance"
  "$ai_dir/skills/claude/dotfiles-maintenance"
)

for path in "${required_paths[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "missing required AI configuration: $path" >&2
    exit 1
  fi
done

jq empty "$ai_dir/claude/settings.json"

nix eval --impure --expr \
  "builtins.fromTOML (builtins.readFile \"$ai_dir/codex/config.toml\")" \
  >/dev/null

for skill in "$ai_dir"/skills/common/*/SKILL.md; do
  rg -q '^name: [a-z0-9-]+$' "$skill"
  rg -q '^description: .+$' "$skill"
done

if find "$ai_dir" -type f \
  \( -name 'auth.json' -o -name 'history.jsonl' -o -name 'settings.local.json' \
     -o -name 'CLAUDE.local.md' -o -name '*.sqlite' -o -name '*.sqlite-shm' \
     -o -name '*.sqlite-wal' \) \
  | rg -q .; then
  echo "machine-local AI state found under $ai_dir" >&2
  exit 1
fi

if rg -n --hidden \
  "(api[_-]?key|access[_-]?token|auth[_-]?token|authorization|password)[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\$<{][^\"']+[\"']" \
  "$ai_dir/codex" "$ai_dir/claude" "$ai_dir/skills"; then
  echo "possible hard-coded credential found in managed AI configuration" >&2
  exit 1
fi

git -C "$repo_root" diff --check
bash -n "$repo_root/scripts/sync-ai-config.sh"
echo "AI configuration checks passed"
