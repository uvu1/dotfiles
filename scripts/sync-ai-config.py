#!/usr/bin/env python3
"""Synchronize owned TOML keys without discarding machine-local settings."""

import argparse
import copy
import os
from pathlib import Path
import tempfile
import tomllib

BEGIN = '# >>> dotfiles:codex-defaults >>> managed by sync-ai-config.sh'
END = '# <<< dotfiles:codex-defaults <<<'


def leaves(data, prefix=()):
    for key, value in data.items():
        path = (*prefix, key)
        if isinstance(value, dict):
            yield from leaves(value, path)
        else:
            yield path, value


def without_managed(data, owned):
    result = copy.deepcopy(data)
    for path in owned:
        node = result
        parents = []
        for key in path[:-1]:
            if not isinstance(node.get(key), dict):
                break
            parents.append((node, key))
            node = node[key]
        else:
            node.pop(path[-1], None)
            for parent, key in reversed(parents):
                if not parent[key]:
                    del parent[key]
    return result


def synchronize(source, target):
    defaults = tomllib.loads(source)
    original = tomllib.loads(target)
    owned = dict(leaves(defaults))
    # Source remains dotted-key-only so local top-level settings stay top-level.
    if any(line.lstrip().startswith('[') for line in source.splitlines()):
        raise ValueError('managed defaults must use dotted keys, not table headers')
    prefixes = {path[:i] for path in owned for i in range(1, len(path))}
    source_comments = {line.strip() for line in source.splitlines() if line.lstrip().startswith('#')}
    body = []
    dotted = []
    context = ()
    table_prefix = ''
    in_managed = False
    pending = ''
    for line in target.splitlines(keepends=True):
        if not pending:
            if line.strip() in (BEGIN, END):
                in_managed = line.strip() == BEGIN
                continue
            if not line.strip() or line.lstrip().startswith('#'):
                if not (in_managed and line.strip() in source_comments):
                    body.append(line)
                continue
        pending += line
        try:
            parsed = tomllib.loads(pending)
        except tomllib.TOMLDecodeError:
            continue  # Multi-line arrays, strings and inline tables are one statement.
        if pending.lstrip().startswith('['):
            context = ()
            node = parsed
            while isinstance(node, dict) and len(node) == 1:
                key, node = next(iter(node.items()))
                context += (key,)
            table_prefix = ''
            if context in prefixes and not pending.lstrip().startswith('[['):
                # [tui] cannot coexist with managed tui.* keys. Keep its unknown
                # fields as dotted keys instead, including their original values.
                table_prefix = pending.strip().split(']', 1)[0][1:].strip() + '.'
            else:
                body.append(pending)
        else:
            paths = {context + path for path, _ in leaves(parsed)}
            if paths & owned.keys():
                if not paths <= owned.keys():
                    raise ValueError('an assignment mixes managed and local keys; split it before syncing')
            else:
                if table_prefix:
                    dotted.append(table_prefix + pending.lstrip())
                else:
                    body.append(pending)
        pending = ''
    if pending:
        raise ValueError('could not safely separate TOML statements')
    local = ''.join(dotted + body).strip()
    result = f'{BEGIN}\n{source.strip()}\n{END}\n'
    if local:
        result += '\n' + local + '\n'
    merged = tomllib.loads(result)
    if without_managed(original, owned) != without_managed(merged, owned):
        raise ValueError('sync would change machine-local settings')
    merged_values = dict(leaves(merged))
    if any(merged_values.get(path) != value for path, value in owned.items()):
        raise ValueError('managed defaults did not match after sync')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    source_path = Path(__file__).resolve().parents[1] / 'mise/dotfiles/ai/codex/config.toml'
    target_path = Path(os.environ.get('CODEX_HOME', Path.home() / '.codex')) / 'config.toml'
    original = target_path.read_text() if target_path.exists() else ''
    try:
        result = synchronize(source_path.read_text(), original)
    except (ValueError, tomllib.TOMLDecodeError):
        # Never echo TOML values: local config may contain credentials.
        parser.exit(1, 'Cannot safely synchronize Codex config; original file left unchanged.\n')
    if result == original:
        print('Codex defaults already synchronized')
        return
    if args.dry_run:
        print('Would synchronize Codex defaults; machine-local settings verified unchanged')
        return
    target_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=target_path.parent, prefix='.codex-config-', delete=False) as tmp:
        temporary = Path(tmp.name)
        try:
            tmp.write(result)
            tmp.flush()
            if target_path.exists() and target_path.read_text() != original:
                raise ValueError('config changed during synchronization; retry')
            os.replace(temporary, target_path)
        finally:
            temporary.unlink(missing_ok=True)
    print('Synchronized managed Codex defaults; machine-local settings preserved')


if __name__ == '__main__':
    main()
