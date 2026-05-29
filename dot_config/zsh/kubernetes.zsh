function kube_context_fzf() {
  local context
  local fzf_status

  zle -I
  context="$(
    kubectl config get-contexts -o name 2>/dev/null |
      fzf \
        --height=40% \
        --reverse \
        --border \
        --prompt='kube context> ' \
        --preview='kubectl config view --minify --context={} -o jsonpath="{range .contexts[*]}context: {.name}{\"\n\"}cluster: {.context.cluster}{\"\n\"}namespace: {.context.namespace}{\"\n\"}{end}{range .clusters[*]}server: {.cluster.server}{\"\n\"}{end}" 2>/dev/null'
  )"
  fzf_status=$?

  zle reset-prompt
  zle -R
  (( fzf_status == 0 )) || return

  [[ -n "$context" ]] || return

  kubectl config use-context "$context" >/dev/null
  zle reset-prompt
  zle -R
}

function kube_context_or_kill_line() {
  if [[ -z "${BUFFER//[[:space:]]/}" ]]; then
    BUFFER=""
    CURSOR=0
    kube_context_fzf
  else
    BUFFER=""
    CURSOR=0
    zle reset-prompt
  fi
}

function kube_bindkeys() {
  bindkey -r $'\C-k'
  bindkey $'\C-k' kube_context_or_kill_line
}

zle -N kube_context_fzf
zle -N kube_context_or_kill_line

kube_bindkeys
