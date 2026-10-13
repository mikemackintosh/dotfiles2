# kube.zsh — kubectl against the cluster `kuse` loaded into this shell.
#
#   kuse prod                      load a cluster (below)
#   k -n myapp get pods            k is kubectl; kubectl, helm, cmctl work too
#   make k8s-deploy                so do make's k8s-* targets
#   kx ./script.sh                 rare: a script that calls kubectl itself
#
# kuse keeps the config in a shell variable, not a file, so only this shell's
# functions can see it. A child process (a script, make's own recipes) runs the real kubectl binary and finds no config: localhost:8080.
# `kx <cmd>` runs <cmd> with KUBECONFIG pointing at a 0600 temp copy that lives
# exactly as long as the command does, and every child of it inherits it.
#
# KUBECONFIG, not --kubeconfig, because kubectl rejects any flag before a
# plugin name (`kubectl cert-manager …`) and plugins inherit the env.
# =(…), not <(…): helm reads the kubeconfig twice and a drained pipe reads as
# empty. =(…) is a temp file zsh deletes when the anonymous function returns.
# With no cluster loaded, kx just runs the command.
kx() {
  (( $# )) || { print -u2 "usage: kx <command> [args]   e.g. kx ./script.sh"; return 2 }
  [[ -n $_KUBE_CFG ]] || { command "$@"; return }
  local TMPPREFIX=${${TMPDIR:-/tmp}%/}/zsh
  () { local f=$1; shift; KUBECONFIG=$f command "$@" } =(print -r -- "$_KUBE_CFG") "$@"
}
kubectl() { kx kubectl "$@" }
helm()    { kx helm "$@" }
cmctl()   { kx cmctl "$@" }
# k is kubectl, with kubectl's completion.
k()       { kubectl "$@" }
(( $+functions[compdef] )) && compdef k=kubectl
# make gets the config ONLY when a goal is a k8s-* target. Every other make
# (tests, builds, any repo) gets no kubeconfig at all: handing the admin config
# to all of them would be the opposite of keeping it in memory.
make() {
  if (( ${@[(I)k8s-*]} )); then kx make "$@"; else command make "$@"; fi
}
# krun: the same as kx, by the name used on the other machine (`krun terraform plan`).
krun()    { kx "$@" }

# What kuse has loaded in this shell.
kconfig() {
  print "cluster:    ${KUBE_CLUSTER:-<none>} (kuse)"
  if [[ -n $_KUBE_CFG ]]; then
    print "kubeconfig: <in memory> (k, kubectl, helm, cmctl, make k8s-*; other tools: kx)"
  else
    print "kubeconfig: ${KUBECONFIG:-$HOME/.kube/config} (no kuse cluster loaded)"
  fi
  print "sops key:   ${${SOPS_AGE_KEY_CMD:+$SOPS_AGE_KEY_CMD}:-<none>}"
  [[ -n $KUBE_CLUSTER ]] && { _kube_load; print "registries: ${KUBE_REGISTRIES[$KUBE_CLUSTER]:-<none>} (registry-login)" }
  return 0
}


# kuse — render a cluster's kubeconfig from 1Password into this shell only.
#
#   kuse prod      render it into this shell for k/kubectl, helm, make k8s-*
#   kuse           pick one with fzf (prints the active cluster without a tty)
#   kuse -         forget it
#   kuse -w [prod] write ./.kuse (default: the active cluster, else pick) and load it
#
# The config is held in a non-exported shell variable, not a long-lived
# file: the kubectl/helm/k wrappers above hand it to each call. A rendered
# file in $TMPDIR kept vanishing mid-session (kubectl falling back to
# localhost:8080 between two commands); a variable can't be lost that way.
# Scripts that call kubectl themselves do not see it; run them with kx.
# make's k8s-* targets get it from the make() wrapper above.
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

# exec zsh from a shell running the old file-based kuse keeps its exported
# KUBECONFIG, pointing at a temp file that is gone; kx would hand it on.
[[ $KUBECONFIG == */kube.<->.*/*.yaml && ! -s $KUBECONFIG ]] && unset KUBECONFIG

# Reread on every use so a sync lands in shells that are already open.
_kube_load() { KUBE_SOPS=() KUBE_REGISTRIES=(); [[ -r $KUBE_CLUSTERS_FILE ]] && source $KUBE_CLUSTERS_FILE }

kuse() {
  local name=$1
  # A cluster you pick by hand is yours: leaving a .kuse dir won't forget it.
  unset _KUBE_AUTO_NAME
  if [[ $name == -w ]]; then
    name=${2:-$KUBE_CLUSTER}
    if [[ -z $name ]]; then
      [[ -t 0 && -t 1 ]] && command -v fzf &>/dev/null && name=$(_kube_pick)
      [[ -n $name ]] || { print -u2 "usage: kuse -w <name>   (no cluster active to write)"; return 2 }
    fi
    [[ $name == - ]] && { print -u2 "kuse: -w needs a cluster, not -"; return 2 }
    _kube_known $name || { print -u2 "kuse: unknown cluster '$name' (kclusters sync?)"; return 1 }
    print -r -- $name > .kuse || return
    print -u2 "kuse: wrote $name to ./.kuse"
    # Re-run the hook to load it; mark it this dir's even if it was already active.
    unset _KUBE_AUTO_SEEN
    _kube_auto
    [[ $KUBE_CLUSTER == $name ]] && typeset -g _KUBE_AUTO_NAME=$name
    return 0
  fi
  if [[ -z $name ]]; then
    if [[ ! -t 0 || ! -t 1 ]] || ! command -v fzf &>/dev/null; then
      print "${KUBE_CLUSTER:-<none>}${KUBECONFIG:+  ($KUBECONFIG)}"
      return
    fi
    name=$(_kube_pick) || return 0
    [[ -n $name ]] || return 0
  fi
  if [[ $name == - ]]; then
    _kube_sops ""
    unset _KUBE_CFG KUBECONFIG KUBE_CLUSTER
    return
  fi
  if ! command -v op &>/dev/null; then
    print -u2 "kuse: 1Password CLI (op) not found"
    return 127
  fi
  # Establish a session up front (in this shell, so it persists past the
  # render subshell), retrying signin. Without it op inject reads nothing.
  if typeset -f _op_signin_retry >/dev/null && ! _op_signin_retry; then
    print -u2 "kuse: 1Password CLI is not signed in — unlock 1Password, or run: eval \$(op signin)"
    return 1
  fi

  _kube_load
  local ref=${KUBE_CLUSTERS[$name]:-${KUBE_SYNCED[$name]:-$KUBE_OP_VAULT}}
  local vault=${ref%%/*} item=kube-$name
  [[ $ref == */* ]] && item=${ref#*/}

  local tpl=$HOME/.kube/$name.tpl
  [[ -f $tpl ]] || tpl=$KUBE_TEMPLATE
  [[ -f $tpl ]] || { print -u2 "kuse: no template: $tpl"; return 1 }

  # Files left by the old file-based kuse still hold tokens; clear them.
  _kube_sweep

  local body cfg rc=0
  body=$(<$tpl) || return
  # __NAME__ is filled in before op runs; the secrets only ever land in cfg.
  # op wants -i or a pipe; it reads a here-string as empty stdin.
  cfg=$(print -r -- "${body//__NAME__/$name}" |
    KUBE_OP_VAULT=$vault KUBE_OP_ITEM=$item op inject) || rc=$?
  # op inject has been seen to exit 0 with nothing to show for it (locked
  # 1Password, a flaky s.sock). Keep the previous cluster rather than switch
  # to an empty config that kubectl silently reads as localhost:8080.
  if (( rc )) || [[ -z ${cfg//[[:space:]]/} ]]; then
    print -u2 "kuse: could not render $vault/$item — is 1Password unlocked? ${KUBE_CLUSTER:-nothing} still active."
    return 1
  fi

  typeset -g _KUBE_CFG=$cfg
  export KUBE_CLUSTER=$name
  # A KUBECONFIG left by the old file-based kuse points at a deleted file.
  [[ $KUBECONFIG == */kube.<->.*/*.yaml ]] && unset KUBECONFIG
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

# Removes token files the old file-based kuse left behind in $TMPDIR, skipping
# dirs whose shell (the pid in the name) is still alive.
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

_kuse() {
  local -a names
  _kube_load
  names=(${(k)KUBE_CLUSTERS} ${(k)KUBE_SYNCED} $HOME/.kube/*.tpl(N:t:r))
  compadd -- - -w ${(u)names}
}
(( $+functions[compdef] )) && compdef _kuse kuse

# .kuse — a project names its cluster; cd'ing in loads it.
#
#   kuse -w acme-prod              writes ./.kuse (nearest one up wins)
#
# Entering a tree with a different .kuse switches to its cluster; leaving
# for a dir with none forgets it, unless you've since run kuse by hand.
# Only names already in the map (or ~/.kube/<name>.tpl) load: a cloned
# repo can't point kuse at an arbitrary vault item. Each .kuse is acted on
# once per entry, so a locked 1Password doesn't re-prompt on every cd.
_kube_auto() {
  local d=$PWD f=
  while :; do
    [[ -f $d/.kuse ]] && { f=$d/.kuse; break }
    [[ $d == / ]] && break
    d=${d:h}
  done
  [[ $f == $_KUBE_AUTO_SEEN ]] && return 0
  typeset -g _KUBE_AUTO_SEEN=$f

  if [[ -z $f ]]; then
    [[ -n $_KUBE_AUTO_NAME && $KUBE_CLUSTER == $_KUBE_AUTO_NAME ]] || return 0
    print -u2 "kuse: left ${_KUBE_AUTO_NAME}'s .kuse; forgetting it"
    kuse -
    return 0
  fi

  local name where=${${f:h}/#$HOME/~}
  local -a lines=(${(M)${(f)"$(<$f)"}:#[^#]*})
  name=${lines[1]//[[:space:]]/}
  [[ -n $name ]] || return 0
  if ! _kube_known $name; then
    print -u2 "kuse: $where/.kuse names unknown cluster '$name' (kclusters sync?)"
    return 0
  fi
  [[ $KUBE_CLUSTER == $name && -n $_KUBE_CFG ]] && return 0
  print -u2 "kuse: $name (from $where/.kuse)"
  kuse $name && typeset -g _KUBE_AUTO_NAME=$name
  return 0
}

# _kube_known <name> — in the map or has a ~/.kube/<name>.tpl.
_kube_known() {
  [[ $1 =~ '^[A-Za-z0-9._-]+$' ]] || return 1
  _kube_load
  (( $+KUBE_CLUSTERS[$1] || $+KUBE_SYNCED[$1] )) || [[ -f $HOME/.kube/$1.tpl ]]
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _kube_auto
# chpwd doesn't fire for the dir a shell starts in (new tmux pane, sessionizer).
[[ -o interactive ]] && _kube_auto
