# kube.zsh — run kubectl through a Docker image, no local kubectl needed.
#
# `k` is a drop-in kubectl: it runs the configured container image with your
# kubeconfig mounted read-only and forwards every argument straight through.
#
#   k get pods
#   k -n myapp rollout restart deployment myapp-web
#   echo "$manifest" | k apply -f -
#
# Everything is overridable via env vars, so it works across clusters/projects
# without editing this file. Set them globally in zsh/private.zsh, or per-repo
# with a direnv `.envrc` (direnv is already wired up in .zshrc):
#
#   KUBE_IMAGE         container image to run         (default: bitnami/kubectl:latest)
#   KUBECONFIG_FILE    host kubeconfig, mounted RO    (default: $HOME/.kube/config)
#   KUBE_NAMESPACE     default namespace, adds -n     (default: empty → kubeconfig/context default)
#   KUBE_DOCKER_ARGS   extra `docker run` args        (array, e.g. (--network host))
#   KUBE_KUBECTL_ARGS  extra kubectl args, prepended  (array, e.g. (--context prod))
#
# Example .envrc for the myapp repo:
#   export KUBE_NAMESPACE=myapp
#   export KUBECONFIG_FILE="$HOME/.kube/config"

: ${KUBE_IMAGE:=bitnami/kubectl:latest}
: ${KUBECONFIG_FILE:=$HOME/.kube/config}
: ${KUBE_NAMESPACE:=}

k() {
  if ! command -v docker &>/dev/null; then
    print -u2 "k: docker not found on PATH"
    return 127
  fi

  if [[ -z $_KUBE_CFG && ! -f $KUBECONFIG_FILE ]]; then
    print -u2 "k: kubeconfig not found: $KUBECONFIG_FILE"
    print -u2 "   run kuse, or set KUBECONFIG_FILE to a valid path (env or .envrc)."
    return 1
  fi

  # Build argv incrementally so unset/empty arrays contribute nothing
  # (a quoted expansion of an unset array yields a stray "" in zsh).
  local -a run_args kargs
  [[ -n $KUBE_NAMESPACE ]]    && kargs+=(-n "$KUBE_NAMESPACE")
  (( ${#KUBE_KUBECTL_ARGS} )) && kargs+=("${KUBE_KUBECTL_ARGS[@]}")
  kargs+=("$@")

  run_args=(run --rm -i)
  (( ${#KUBE_DOCKER_ARGS} ))  && run_args+=("${KUBE_DOCKER_ARGS[@]}")
  if [[ -n $_KUBE_CFG ]]; then
    # kuse's config lives only in this shell, so hand it over by env NAME
    # (value never on argv) and let the container write its own copy.
    run_args+=(-e KUBE_CFG_DATA --entrypoint sh "$KUBE_IMAGE" -c
      'f=$(mktemp) && printf %s "$KUBE_CFG_DATA" >"$f" && exec kubectl --kubeconfig "$f" "$@"' k)
    KUBE_CFG_DATA=$_KUBE_CFG docker "${run_args[@]}" "${kargs[@]}"
  else
    run_args+=(-v "${KUBECONFIG_FILE}:/kc.yaml:ro" "$KUBE_IMAGE" --kubeconfig /kc.yaml)
    docker "${run_args[@]}" "${kargs[@]}"
  fi
}

# kuse keeps its kubeconfig in $_KUBE_CFG (not exported); these hand it to
# one command at a time as KUBECONFIG, not --kubeconfig, because kubectl
# rejects any flag before a plugin name (`kubectl cert-manager …`) and
# plugins inherit the env. =(…), not <(…): helm reads the kubeconfig twice
# and a drained pipe reads as empty, i.e. localhost:8080. =(…) is a 0600
# temp file zsh deletes when the anonymous function returns.
_kube_with_cfg() {
  [[ -n $_KUBE_CFG ]] || { command "$@"; return }
  local TMPPREFIX=${${TMPDIR:-/tmp}%/}/zsh
  () { local f=$1; shift; KUBECONFIG=$f command "$@" } =(print -r -- "$_KUBE_CFG") "$@"
}
kubectl() { _kube_with_cfg kubectl "$@" }
helm()    { _kube_with_cfg helm "$@" }
cmctl()   { _kube_with_cfg cmctl "$@" }
# make, with the kuse config as a real KUBECONFIG file, for Makefile targets
# that call kubectl (make runs the binary, never the function above). Not a
# `make` override: that would hand the admin config to every make in every
# repo while kuse is active.
kmake()   { _kube_with_cfg make "$@" }

# Show the effective config `k` will use.
kconfig() {
  print "cluster:    ${KUBE_CLUSTER:-<none>} (kuse)"
  print "image:      $KUBE_IMAGE"
  if [[ -n $_KUBE_CFG ]]; then
    print "kubeconfig: <in memory> (kuse; kubectl/helm/k read it)"
  else
    print "kubeconfig: $KUBECONFIG_FILE$([[ -f $KUBECONFIG_FILE ]] || print ' (MISSING)')"
  fi
  print "namespace:  ${KUBE_NAMESPACE:-<context default>}"
  print "sops key:   ${${SOPS_AGE_KEY_CMD:+$SOPS_AGE_KEY_CMD}:-<none>}"
  [[ -n $KUBE_CLUSTER ]] && { _kube_load; print "registries: ${KUBE_REGISTRIES[$KUBE_CLUSTER]:-<none>} (registry-login)" }
  (( ${#KUBE_DOCKER_ARGS} ))  && print "docker args:  ${KUBE_DOCKER_ARGS[*]}"
  (( ${#KUBE_KUBECTL_ARGS} )) && print "kubectl args: ${KUBE_KUBECTL_ARGS[*]}"
  return 0
}

# kuse — render a cluster's kubeconfig from 1Password into this shell only.
#
#   kuse prod      render it into this shell for kubectl, helm and `k`
#   kuse           pick one with fzf (prints the active cluster without a tty)
#   kuse -         forget it
#
# The config is held in a non-exported shell variable, not a long-lived
# file: the kubectl/helm/k wrappers above hand it to each call. A rendered
# file in $TMPDIR kept vanishing mid-session (kubectl falling back to
# localhost:8080 between two commands); a variable can't be lost that way.
# Tools that need a real path (k9s, Makefiles reading $KUBECONFIG) do not
# see it.
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
    _kube_sops ""
    unset _KUBE_CFG KUBECONFIG KUBE_CLUSTER
    KUBECONFIG_FILE=$HOME/.kube/config
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
  compadd -- - ${(u)names}
}
(( $+functions[compdef] )) && compdef _kuse kuse
