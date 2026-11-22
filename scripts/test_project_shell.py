"""Check opt-in shell state using an isolated HOME and fake project clients."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
ENTRY = ROOT / "mise/dotfiles/.config/zsh/optional/infra.zsh"
ZSH = shutil.which("zsh")
MISE = shutil.which("mise")


@unittest.skipUnless(ZSH, "zsh is required")
class ProjectShellTests(unittest.TestCase):
    def run_shell(self, script):
        with tempfile.TemporaryDirectory(prefix="project-shell-") as directory:
            home = Path(directory)
            binaries = home / "bin"
            binaries.mkdir()
            clients = {
                "kubectl": "cat <<'COMPLETION'\n_kubectl() { :; }\ncompdef _kubectl kubectl\nCOMPLETION\n",
                "gh": "cat <<'COMPLETION'\n_gh() { :; }\ncompdef _gh gh\nCOMPLETION\n",
                "vault": "exit 0\n",
            }
            for name, body in clients.items():
                path = binaries / name
                path.write_text("#!/bin/sh\n" + body)
                path.chmod(0o755)
            env = dict(os.environ)
            env.pop("STARSHIP_CONFIG", None)
            env.update(
                HOME=directory,
                XDG_CONFIG_HOME=str(home / ".config"),
                XDG_CACHE_HOME=str(home / ".cache"),
                ZDOTDIR=directory,
                PATH=str(binaries) + os.pathsep + env["PATH"],
                TEST_INFRA_ENTRY=str(ENTRY),
            )
            for key in list(env):
                if key.startswith("__MISE_"):
                    env.pop(key)
            env.update(
                MISE_GLOBAL_CONFIG_FILE=str(home / "global.toml"),
                MISE_SYSTEM_CONFIG_FILE=str(home / "system.toml"),
                MISE_DATA_DIR=str(home / "mise-data"),
                MISE_STATE_DIR=str(home / "mise-state"),
                MISE_CACHE_DIR=str(home / "mise-cache"),
                MISE_OFFLINE="1",
                MISE_NOT_FOUND_AUTO_INSTALL="0",
                MISE_TRUSTED_CONFIG_PATHS=directory,
            )
            result = subprocess.run(
                [ZSH, "-dfc", "set -eu\n" + script],
                env=env, cwd=directory, text=True, capture_output=True, timeout=30,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_enter_leave_without_prior_state(self):
        self.run_shell(r'''
before_emacs=$(bindkey -L -M emacs '^K')
before_viins=$(bindkey -L -M viins '^K')
source "$TEST_INFRA_ENTRY" enter
[[ ${aliases[k]} == kubectl ]]
[[ ${_comps[kubectl]} == _kubectl && ${_comps[k]} == _kubectl ]]
[[ ${_comps[vault]} == *vault* ]]
[[ $(bindkey -M emacs '^K') == *_dotfiles_kube_context_or_kill_line ]]
[[ $(bindkey -M viins '^K') == *_dotfiles_kube_context_or_kill_line ]]
[[ -f $STARSHIP_CONFIG && ${parameters[STARSHIP_CONFIG]} == *export* ]]
python3 -c 'import os, tomllib; c=tomllib.load(open(os.environ["STARSHIP_CONFIG"], "rb")); assert "$kubernetes" in c["format"]; assert not c["kubernetes"]["disabled"]'
source "$TEST_INFRA_ENTRY" enter
source "$TEST_INFRA_ENTRY" leave
source "$TEST_INFRA_ENTRY" leave
[[ ${+aliases[k]} == 0 && ${+STARSHIP_CONFIG} == 0 ]]
[[ ${+_comps[kubectl]} == 0 && ${+_comps[k]} == 0 && ${+_comps[vault]} == 0 ]]
[[ $(bindkey -L -M emacs '^K') == $before_emacs ]]
[[ $(bindkey -L -M viins '^K') == $before_viins ]]
[[ ${+widgets[_dotfiles_kube_context_or_kill_line]} == 0 ]]
[[ ${+_dotfiles_infra_active} == 0 ]]
''')

    def test_restore_existing_alias_completion_key_macro_and_prompt(self):
        self.run_shell(r'''
autoload -Uz compinit
compinit -D
alias k='printf original'
_comps[k]=old_k
_comps[kubectl]=old_kubectl
_comps[vault]=old_vault
export STARSHIP_CONFIG="$HOME/custom prompt.toml"
bindkey -s -M emacs '^K' 'previous macro'
before=$(bindkey -L -M emacs '^K')
source "$TEST_INFRA_ENTRY" enter
source "$TEST_INFRA_ENTRY" leave
[[ ${aliases[k]} == 'printf original' ]]
[[ ${_comps[k]} == old_k && ${_comps[kubectl]} == old_kubectl && ${_comps[vault]} == old_vault ]]
[[ $STARSHIP_CONFIG == "$HOME/custom prompt.toml" ]]
[[ ${parameters[STARSHIP_CONFIG]} == *export* ]]
[[ $(bindkey -L -M emacs '^K') == $before ]]
''')

    def test_restore_unexported_prompt_variable(self):
        self.run_shell(r'''
STARSHIP_CONFIG=custom
source "$TEST_INFRA_ENTRY" enter
source "$TEST_INFRA_ENTRY" leave
[[ $STARSHIP_CONFIG == custom && ${parameters[STARSHIP_CONFIG]} != *export* ]]
''')

    @unittest.skipUnless(MISE, "mise is required")
    def test_mise_hooks_across_subdirectories_and_worktree_like_roots(self):
        self.run_shell(r'''
mkdir -p "$HOME/project/nested" "$HOME/worktree" "$HOME/outside"
cat > "$HOME/project/mise.toml" <<'CONFIG'
[hooks.enter]
shell = "zsh"
script = 'source "$TEST_INFRA_ENTRY" enter'
[hooks.leave]
shell = "zsh"
script = 'source "$TEST_INFRA_ENTRY" leave'
CONFIG
cp "$HOME/project/mise.toml" "$HOME/worktree/mise.toml"
alias k=original
before=$(bindkey -L -M emacs '^K')
eval "$(mise activate zsh)"
cd "$HOME/project/nested"
[[ ${aliases[k]} == kubectl && ${_dotfiles_infra_active} == 1 ]]
cd "$HOME/project"
[[ ${aliases[k]} == kubectl ]]
cd "$HOME/worktree"
[[ ${aliases[k]} == kubectl && ${_dotfiles_infra_active} == 1 ]]
cd "$HOME/outside"
[[ ${aliases[k]} == original && ${+STARSHIP_CONFIG} == 0 ]]
[[ $(bindkey -L -M emacs '^K') == $before ]]
''')


if __name__ == "__main__":
    unittest.main()
