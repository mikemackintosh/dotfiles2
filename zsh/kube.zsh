# kube.zsh — run kubectl through a Docker image, no local kubectl needed.
#
# `k` is a drop-in kubectl: it runs the configured container image with your
# kubeconfig mounted read-only and forwards every argument straight through.
#
#   k get pods
#   k -n qondom rollout restart deployment qondom-web
#   echo "$manifest" | k apply -f -
#
# Everything is overridable via env vars, so it works across clusters/projects
# without editing this file. Set them globally in zsh/private.zsh, or per-repo
# with a direnv `.envrc` (direnv is already wired up in .zshrc):
#
#   KUBE_IMAGE         container image to run         (default: bitnami/kubectl:latest)
#   KUBECONFIG_FILE    host kubeconfig, mounted RO    (default: $HOME/dcs-pro1-kubeconfig.yaml)
#   KUBE_NAMESPACE     default namespace, adds -n     (default: empty → kubeconfig/context default)
#   KUBE_DOCKER_ARGS   extra `docker run` args        (array, e.g. (--network host))
#   KUBE_KUBECTL_ARGS  extra kubectl args, prepended  (array, e.g. (--context prod))
#
# Example .envrc for the qondom repo:
#   export KUBE_NAMESPACE=qondom
#   export KUBECONFIG_FILE="$HOME/dcs-pro1-kubeconfig.yaml"

: ${KUBE_IMAGE:=bitnami/kubectl:latest}
: ${KUBECONFIG_FILE:=$HOME/dcs-pro1-kubeconfig.yaml}
: ${KUBE_NAMESPACE:=}

k() {
  if ! command -v docker &>/dev/null; then
    print -u2 "k: docker not found on PATH"
    return 127
  fi

  if [[ ! -f $KUBECONFIG_FILE ]]; then
    print -u2 "k: kubeconfig not found: $KUBECONFIG_FILE"
    print -u2 "   set KUBECONFIG_FILE to a valid path (env or .envrc)."
    return 1
  fi

  # Build argv incrementally so unset/empty arrays contribute nothing
  # (a quoted expansion of an unset array yields a stray "" in zsh).
  local -a run_args
  run_args=(run --rm -i -v "${KUBECONFIG_FILE}:/kc.yaml:ro")
  (( ${#KUBE_DOCKER_ARGS} ))  && run_args+=("${KUBE_DOCKER_ARGS[@]}")
  run_args+=("$KUBE_IMAGE" --kubeconfig /kc.yaml)
  [[ -n $KUBE_NAMESPACE ]]    && run_args+=(-n "$KUBE_NAMESPACE")
  (( ${#KUBE_KUBECTL_ARGS} )) && run_args+=("${KUBE_KUBECTL_ARGS[@]}")
  run_args+=("$@")

  docker "${run_args[@]}"
}

# Show the effective config `k` will use.
kconfig() {
  print "cluster:    ${KUBE_CLUSTER:-<none>} (kuse)"
  print "image:      $KUBE_IMAGE"
  print "kubeconfig: $KUBECONFIG_FILE$([[ -f $KUBECONFIG_FILE ]] || print ' (MISSING)')"
  print "namespace:  ${KUBE_NAMESPACE:-<context default>}"
  print "sops key:   ${${SOPS_AGE_KEY_CMD:+$SOPS_AGE_KEY_CMD}:-<none>}"
  [[ -n $KUBE_CLUSTER ]] && { _kube_load; print "registries: ${KUBE_REGISTRIES[$KUBE_CLUSTER]:-<none>} (registry-login)" }
  (( ${#KUBE_DOCKER_ARGS} ))  && print "docker args:  ${KUBE_DOCKER_ARGS[*]}"
  (( ${#KUBE_KUBECTL_ARGS} )) && print "kubectl args: ${KUBE_KUBECTL_ARGS[*]}"
  return 0
}

# kuse — render a cluster's kubeconfig from 1Password into this shell only.
#
#   kuse prod      render, then point KUBECONFIG and `k` at it
#   kuse           pick one with fzf (prints the active cluster without a tty)
#   kuse -         forget it and delete the rendered file
#
# Template: ~/.kube/<name>.tpl if present, else kube/config.tpl in this repo.
# Where each cluster lives comes from `kclusters sync`, which writes
# $KUBE_CLUSTERS_FILE (KUBE_SYNCED, by vault/item ID). Hand-kept entries go
# in ~/.private/*.zsh and win over synced ones:
#   KUBE_CLUSTERS=(edge Infra/k8s-edge)
# Value is a vault (item defaults to kube-<name>) or vault/item. Unlisted
# names fall back to kube-<name> in $KUBE_OP_VAULT (default: Personal).
#
# SOPS: a synced item with a valid sops-age-key field (see KUBE_SOPS in the
# map) gets SOPS_AGE_KEY_CMD="op read op://<vault>/<item>/sops-age-key", so
# sops decrypts with that cluster's key and the key never touches disk.
# Switching to a cluster without one, or `kuse -`, clears it.

: ${KUBE_OP_VAULT:=Personal}
: ${KUBE_TEMPLATE:=${0:A:h:h}/kube/config.tpl}
# The map's arrays must be declared associative before it is sourced, or
# its `NAME=(…)` lines make plain arrays.
typeset -gA KUBE_CLUSTERS KUBE_SYNCED KUBE_SOPS KUBE_REGISTRIES
: ${KUBE_CLUSTERS_FILE:=$HOME/.private/kube-clusters.zsh}

# Reread on every use so a sync lands in shells that are already open.
_kube_load() { KUBE_SOPS=() KUBE_REGISTRIES=(); [[ -r $KUBE_CLUSTERS_FILE ]] && source $KUBE_CLUSTERS_FILE }

kuse() {
  local name=$1
  if [[ -z $name ]]; then
    if [[ ! -t 0 || ! -t 1 ]] || ! command -v fzf &>/dev/null; then
      print "${KUBE_CLUSTER:-<none>}${KUBECONFIG:+  ($KUBECONFIG)}"
      return
    fi
    name=$(_kube_pick) || return 0
    [[ -n $name ]] || return 0
  fi
  if [[ $name == - ]]; then
    _kube_forget
    _kube_sops ""
    unset KUBECONFIG KUBE_CLUSTER
    KUBECONFIG_FILE=$HOME/dcs-pro1-kubeconfig.yaml
    return
  fi
  if ! command -v op &>/dev/null; then
    print -u2 "kuse: 1Password CLI (op) not found"
    return 127
  fi

  _kube_load
  local ref=${KUBE_CLUSTERS[$name]:-${KUBE_SYNCED[$name]:-$KUBE_OP_VAULT}}
  local vault=${ref%%/*} item=kube-$name
  [[ $ref == */* ]] && item=${ref#*/}

  local tpl=$HOME/.kube/$name.tpl
  [[ -f $tpl ]] || tpl=$KUBE_TEMPLATE
  [[ -f $tpl ]] || { print -u2 "kuse: no template: $tpl"; return 1 }

  # One 0700 dir per shell, removed on exit, so tokens never outlive the
  # shell or leak into a sibling one. $TMPDIR is under /var/folders, which
  # Docker Desktop shares by default, so `k` can still mount the file.
  if [[ ! -d $_KUBE_DIR ]]; then
    _kube_sweep
    _KUBE_DIR=$(mktemp -d "${${TMPDIR:-/tmp}%/}/kube.$$.XXXXXX") || return
  fi
  local out=$_KUBE_DIR/$name.yaml in=$_KUBE_DIR/.$name.tpl body rc=0
  body=$(<$tpl) || return
  # __NAME__ is filled in before op runs, so secrets never pass through zsh.
  # op wants -i or a pipe; it reads a here-string as empty stdin.
  print -r -- "${body//__NAME__/$name}" >| $in || return
  ( umask 077
    KUBE_OP_VAULT=$vault KUBE_OP_ITEM=$item \
      op inject -f -i "$in" -o "$out" >/dev/null ) || rc=$?
  rm -f -- "$in"
  if (( rc )); then
    rm -f -- "$out"
    print -u2 "kuse: op inject failed for $vault/$item"
    return 1
  fi

  export KUBECONFIG=$out KUBE_CLUSTER=$name
  KUBECONFIG_FILE=$out
  _kube_sops "${KUBE_SOPS[$name]}"
}

# _kube_sops <vaultID/itemID | ""> — point sops at that item's key, or drop
# the one kuse set. A SOPS_AGE_KEY_CMD you exported yourself is left alone.
_kube_sops() {
  if [[ -n $_KUBE_SOPS_CMD && $SOPS_AGE_KEY_CMD == $_KUBE_SOPS_CMD ]]; then
    unset SOPS_AGE_KEY_CMD
  fi
  unset _KUBE_SOPS_CMD
  [[ -n $1 ]] || return 0
  # sops splits this with shlex and execs it — no shell — and the IDs hold
  # no spaces, so it needs no quoting.
  _KUBE_SOPS_CMD="op read op://$1/sops-age-key"
  export SOPS_AGE_KEY_CMD=$_KUBE_SOPS_CMD
}

# zshexit does not run when a shell is killed, so the next kuse clears dirs
# whose owning shell (the pid in the name) is gone.
_kube_sweep() {
  local d pid
  for d in ${${TMPDIR:-/tmp}%/}/kube.<->.*(N/); do
    pid=${${d:t}#kube.}; pid=${pid%%.*}
    kill -0 $pid 2>/dev/null && continue
    rm -f -- $d/*(DN)
    rmdir -- $d 2>/dev/null
  done
}

# One line per known cluster: name, then where it comes from. Synced
# entries show the vault/item names kclusters left in its comments.
_kube_pick() {
  _kube_load
  local -A from
  local line n
  if [[ -r $KUBE_CLUSTERS_FILE ]]; then
    for line in ${(f)"$(<$KUBE_CLUSTERS_FILE)"}; do
      [[ $line =~ '^ +([^ ]+) +[^ ]+ +# (.*)$' ]] && from[$match[1]]=$match[2]
    done
  fi
  for n in ${(k)KUBE_CLUSTERS}; do from[$n]="${KUBE_CLUSTERS[$n]} (hand-kept)"; done
  for n in $HOME/.kube/*.tpl(N:t:r); do from[$n]="~/.kube/$n.tpl"; done
  (( ${#from} )) || { print -u2 "kuse: no clusters; run: kclusters sync"; return 1 }

  local -a lines
  for n in ${(ko)from}; do
    lines+=("$(printf "%-24s %s%s" $n $from[$n] "${${(M)n:#$KUBE_CLUSTER}:+   ● active}")")
  done
  [[ -n $KUBE_CLUSTER ]] && lines+=("$(printf "%-24s %s" - "none: forget the active kubeconfig")")

  local choice
  choice=$(print -rl -- $lines | fzf --height=~40% --reverse --no-multi \
    --prompt="kube> " --header="active: ${KUBE_CLUSTER:-none}") || return 1
  print -r -- ${choice%% *}
}

_kube_forget() {
  [[ -d $_KUBE_DIR ]] || return 0
  rm -f -- $_KUBE_DIR/*.yaml(N)
  rmdir -- $_KUBE_DIR 2>/dev/null
  unset _KUBE_DIR
}

# A subshell that calls `exit` runs the parent's zshexit hooks too ($$ is
# inherited), which deleted the live kubeconfig mid-session. Only the shell
# that owns the dir may clean it up.
_kube_exit() { [[ $sysparams[pid] == $$ ]] && _kube_forget }

zmodload zsh/system
autoload -Uz add-zsh-hook
add-zsh-hook zshexit _kube_exit

_kuse() {
  local -a names
  _kube_load
  names=(${(k)KUBE_CLUSTERS} ${(k)KUBE_SYNCED} $HOME/.kube/*.tpl(N:t:r))
  compadd -- - ${(u)names}
}
(( $+functions[compdef] )) && compdef _kuse kuse
