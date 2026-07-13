autoload -Uz compinit

ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
mkdir -p "${ZSH_COMPDUMP:h}"

if [[ -r "$ZSH_COMPDUMP" ]]; then
  compinit -C -d "$ZSH_COMPDUMP"
else
  compinit -d "$ZSH_COMPDUMP"
fi

ZSH_COMPLETION_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions"
mkdir -p "$ZSH_COMPLETION_CACHE_DIR"

function _source_cached_completion() {
  local name="$1"
  local command_path="$commands[$name]"
  local cache_file="$ZSH_COMPLETION_CACHE_DIR/$name.zsh"
  local tmp_file="$cache_file.$$"
  shift

  [[ -r "$cache_file" ]] && source "$cache_file"

  if [[ -n "$command_path" && ( ! -r "$cache_file" || "$command_path" -nt "$cache_file" ) ]]; then
    {
      "$@" >| "$tmp_file" 2>/dev/null && mv "$tmp_file" "$cache_file"
      [[ -e "$tmp_file" ]] && rm "$tmp_file"
    } &!
  fi
}

_source_cached_completion kubectl kubectl completion zsh
_source_cached_completion gh gh completion -s zsh

# vault cli
if (( $+commands[vault] )); then
  autoload -Uz bashcompinit
  bashcompinit
  complete -o nospace -C "$commands[vault]" vault
fi

unfunction _source_cached_completion
