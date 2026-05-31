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
  print "image:      $KUBE_IMAGE"
  print "kubeconfig: $KUBECONFIG_FILE$([[ -f $KUBECONFIG_FILE ]] || print ' (MISSING)')"
  print "namespace:  ${KUBE_NAMESPACE:-<context default>}"
  (( ${#KUBE_DOCKER_ARGS} ))  && print "docker args:  ${KUBE_DOCKER_ARGS[*]}"
  (( ${#KUBE_KUBECTL_ARGS} )) && print "kubectl args: ${KUBE_KUBECTL_ARGS[*]}"
}
