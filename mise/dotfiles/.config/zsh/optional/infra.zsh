# infra の mise enter/leave hook からだけ読み込む。通常のシェルでは有効化しない。
case "${1:-}" in
  enter)
    [[ -n ${_dotfiles_infra_active:-} ]] && return 0
    () {
      emulate -L zsh
      local config_dir="${${(%):-%x}:A:h:h}"
      local name completion prompt prompt_dir prompt_tmp

      # mise の最初の hook が Sheldon の遅延読み込みより先でも補完を登録できる。
      (( $+functions[compdef] )) || source "$config_dir/completion.zsh"
      typeset -gA _dotfiles_infra_saved
      _dotfiles_infra_saved=(
        alias_set "${+aliases[k]}" alias "${aliases[k]-}"
        prompt_set "${+STARSHIP_CONFIG}" prompt "${STARSHIP_CONFIG-}"
        prompt_exported "${parameters[STARSHIP_CONFIG]-}"
      )
      for name in emacs viins; do
        _dotfiles_infra_saved[key.$name]="$(bindkey -L -M "$name" '^K')"
      done
      for name in kubectl k vault; do
        _dotfiles_infra_saved[comp_set.$name]=${+_comps[$name]}
        _dotfiles_infra_saved[comp.$name]="${_comps[$name]-}"
      done

      # プロンプトの共通部分は複製せず、その時点の管理設定から派生させる。
      prompt="$(<"$config_dir/../starship.toml")"
      prompt=${prompt/'$username'/'$username$kubernetes'}
      prompt_dir="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
      mkdir -p "$prompt_dir" || return 1
      prompt_tmp=$(mktemp "$prompt_dir/infra-starship.XXXXXX") || return 1
      {
        print -r -- "$prompt"
        print -rl -- '[kubernetes]' 'disabled = false' 'symbol = " "'
      } > "$prompt_tmp"
      mv -f -- "$prompt_tmp" "$prompt_dir/infra-starship.toml" || return 1
      export STARSHIP_CONFIG="$prompt_dir/infra-starship.toml"

      source "$config_dir/optional/kubernetes.zsh"
      alias k=kubectl
      for name in emacs viins; do
        bindkey -M "$name" '^K' _dotfiles_kube_context_or_kill_line
      done
      if (( $+commands[kubectl] )); then
        completion=$(command kubectl completion zsh) && eval "$completion"
        (( $+_comps[kubectl] )) && compdef "${_comps[kubectl]}" k
      fi
      if (( $+commands[vault] )); then
        autoload -Uz bashcompinit
        bashcompinit
        complete -o nospace -C "$commands[vault]" vault
      fi
      typeset -g _dotfiles_infra_active=1
    }
    ;;
  leave)
    [[ -n ${_dotfiles_infra_active:-} ]] || return 0
    () {
      emulate -L zsh
      local name
      if (( _dotfiles_infra_saved[alias_set] )); then
        aliases[k]="${_dotfiles_infra_saved[alias]}"
      else
        unalias k
      fi
      for name in emacs viins; do
        eval "${_dotfiles_infra_saved[key.$name]}"
      done
      for name in kubectl k vault; do
        if (( _dotfiles_infra_saved[comp_set.$name] )); then
          _comps[$name]="${_dotfiles_infra_saved[comp.$name]}"
        else
          unset "_comps[$name]"
        fi
      done
      if (( _dotfiles_infra_saved[prompt_set] )); then
        typeset -g STARSHIP_CONFIG="${_dotfiles_infra_saved[prompt]}"
        if [[ ${_dotfiles_infra_saved[prompt_exported]} == *export* ]]; then
          export STARSHIP_CONFIG
        else
          typeset +x STARSHIP_CONFIG
        fi
      else
        unset STARSHIP_CONFIG
      fi
      zle -D _dotfiles_kube_context_fzf _dotfiles_kube_context_or_kill_line
      unfunction _dotfiles_kube_context_fzf _dotfiles_kube_context_or_kill_line
      unset _dotfiles_infra_saved _dotfiles_infra_active
    }
    ;;
  *)
    print -u2 'usage: source optional/infra.zsh enter|leave'
    return 2
    ;;
esac
